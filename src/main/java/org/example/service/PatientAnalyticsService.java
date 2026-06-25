package org.example.service;

import org.example.controller.MeController;
import org.example.model.AnalysisReport;
import org.example.model.Patient;
import org.example.model.PatientAiAnalytics;
import org.example.model.ReportPatient;
import org.example.model.User;
import org.example.model.enums.Role;
import org.example.repository.AnalysisReportRepository;
import org.example.repository.PatientAiAnalyticsRepository;
import org.example.repository.PatientRepository;
import org.example.repository.ReportPatientRepository;
import org.example.repository.UserRepository;
import org.example.service.analytics.AnalyticsScoring;
import org.example.service.expert.ExpertSystemService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class PatientAnalyticsService {

    private final AnalysisReportRepository reportRepository;
    private final ReportPatientRepository reportPatientRepository;
    private final PatientRepository patientRepository;
    private final PatientAiAnalyticsRepository analyticsRepository;
    private final ReportPatientLinkService reportPatientLinkService;
    private final UserRepository userRepository;
    private final ExpertSystemService expertSystemService;

    public PatientAnalyticsService(AnalysisReportRepository reportRepository,
                                   ReportPatientRepository reportPatientRepository,
                                   PatientRepository patientRepository,
                                   PatientAiAnalyticsRepository analyticsRepository,
                                   ReportPatientLinkService reportPatientLinkService,
                                   UserRepository userRepository,
                                   ExpertSystemService expertSystemService) {
        this.reportRepository = reportRepository;
        this.reportPatientRepository = reportPatientRepository;
        this.patientRepository = patientRepository;
        this.analyticsRepository = analyticsRepository;
        this.reportPatientLinkService = reportPatientLinkService;
        this.userRepository = userRepository;
        this.expertSystemService = expertSystemService;
    }

    @Transactional(readOnly = true)
    public ReportSummaryDto summaryForReport(Long reportId, Long userId) {
        AnalysisReport report = loadOwnedReport(reportId, userId);
        reportPatientLinkService.ensureLinks(report);
        if (MeController.hasRole(Role.PATIENT)) {
            return buildPatientSummary(reportId, userId, report);
        }
        return buildFullSummary(reportId);
    }

    private ReportSummaryDto buildFullSummary(Long reportId) {
        List<ReportPatient> links = reportPatientRepository.findByReportIdOrderBySortOrderAsc(reportId);
        List<Long> ids = links.stream().map(ReportPatient::getId).toList();
        Map<Long, PatientAiAnalytics> byRp = ids.isEmpty()
                ? Map.of()
                : analyticsRepository.findByReportPatientIdIn(ids).stream()
                .collect(Collectors.toMap(PatientAiAnalytics::getReportPatientId, a -> a));

        long low = 0, med = 0, high = 0;
        int sum = 0;
        int n = 0;
        List<ScorePointDto> points = new ArrayList<>();
        for (ReportPatient rp : links) {
            PatientAiAnalytics a = byRp.get(rp.getId());
            Patient p = patientRepository.findById(rp.getPatientId()).orElse(null);
            String code = p != null ? p.getCode() : "?";
            if (a != null) {
                sum += a.getRiskScore();
                n++;
                switch (a.getRiskLevel()) {
                    case "LOW" -> low++;
                    case "MEDIUM" -> med++;
                    case "HIGH" -> high++;
                    default -> {
                    }
                }
                points.add(new ScorePointDto(rp.getSortOrder(), code, a.getRiskScore(), a.getRiskLevel()));
            } else {
                points.add(new ScorePointDto(rp.getSortOrder(), code, null, null));
            }
        }
        ReportSummaryDto dto = new ReportSummaryDto();
        dto.restrictedView = false;
        dto.linkedPatientCount = links.size();
        dto.generatedCount = n;
        dto.averageRisk = n > 0 ? Math.round((float) sum / n) : null;
        dto.countLow = low;
        dto.countMedium = med;
        dto.countHigh = high;
        dto.scores = points;
        return dto;
    }

    private ReportSummaryDto buildPatientSummary(Long reportId, Long userId, AnalysisReport report) {
        User user = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("Not found"));
        Long myPatientId = user.getPatientId();
        if (myPatientId == null) {
            throw new IllegalArgumentException("Not found");
        }
        List<ReportPatient> links = reportPatientRepository.findByReportIdOrderBySortOrderAsc(reportId);
        Optional<ReportPatient> mine = links.stream()
                .filter(rp -> myPatientId.equals(rp.getPatientId()))
                .findFirst();
        ReportSummaryDto dto = new ReportSummaryDto();
        dto.restrictedView = true;
        dto.linkedPatientCount = mine.isPresent() ? 1 : 0;
        if (mine.isEmpty()) {
            dto.generatedCount = 0;
            dto.averageRisk = null;
            dto.countLow = 0;
            dto.countMedium = 0;
            dto.countHigh = 0;
            dto.scores = List.of();
            return dto;
        }
        ReportPatient rp = mine.get();
        PatientAiAnalytics a = analyticsRepository.findByReportPatientId(rp.getId()).orElse(null);
        Patient p = patientRepository.findById(rp.getPatientId()).orElse(null);
        String code = p != null ? p.getCode() : "?";
        if (a != null) {
            dto.generatedCount = 1;
            dto.averageRisk = a.getRiskScore();
            dto.countLow = "LOW".equals(a.getRiskLevel()) ? 1 : 0;
            dto.countMedium = "MEDIUM".equals(a.getRiskLevel()) ? 1 : 0;
            dto.countHigh = "HIGH".equals(a.getRiskLevel()) ? 1 : 0;
            dto.scores = List.of(new ScorePointDto(rp.getSortOrder(), code, a.getRiskScore(), a.getRiskLevel()));
        } else {
            dto.generatedCount = 0;
            dto.averageRisk = null;
            dto.countLow = 0;
            dto.countMedium = 0;
            dto.countHigh = 0;
            dto.scores = List.of(new ScorePointDto(rp.getSortOrder(), code, null, null));
        }
        return dto;
    }

    @Transactional(readOnly = true)
    public List<AnalyticsViewDto> listForReport(Long reportId, Long userId) {
        AnalysisReport report = loadOwnedReport(reportId, userId);
        reportPatientLinkService.ensureLinks(report);
        return buildViews(report, patientFilterPatientId(userId));
    }

    @Transactional(readOnly = true)
    public AnalyticsViewDto getForReportPatient(Long reportId, Long reportPatientId, Long userId) {
        AnalysisReport report = loadOwnedReport(reportId, userId);
        ReportPatient rp = reportPatientRepository.findById(reportPatientId)
                .orElseThrow(() -> new IllegalArgumentException("Not found"));
        if (!report.getId().equals(rp.getReportId())) {
            throw new IllegalArgumentException("Not found");
        }
        Long only = patientFilterPatientId(userId);
        if (only != null && !only.equals(rp.getPatientId())) {
            throw new IllegalArgumentException("Not found");
        }
        return buildView(rp);
    }

    @Transactional(readOnly = true)
    public List<PatientHistoryEntryDto> historyForPatient(Long patientId, Long userId) {
        if (MeController.hasRole(Role.PATIENT)) {
            User u = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("Not found"));
            if (u.getPatientId() == null || !u.getPatientId().equals(patientId)) {
                throw new IllegalArgumentException("Not found");
            }
        } else if (!MeController.isAdmin()) {
            Patient p = patientRepository.findById(patientId)
                    .orElseThrow(() -> new IllegalArgumentException("Not found"));
            if (!Objects.equals(p.getAttendingDoctorUserId(), userId)) {
                throw new IllegalArgumentException("Not found");
            }
        }
        List<ReportPatient> rps = reportPatientRepository.findByPatientIdOrderByReportCreatedAtDesc(patientId);
        List<PatientHistoryEntryDto> out = new ArrayList<>();
        for (ReportPatient rp : rps) {
            analyticsRepository.findByReportPatientId(rp.getId()).ifPresent(a -> {
                AnalysisReport ar = reportRepository.findById(rp.getReportId()).orElse(null);
                if (ar != null) {
                    PatientHistoryEntryDto e = new PatientHistoryEntryDto();
                    e.reportId = ar.getId();
                    e.reportCreatedAt = ar.getCreatedAt() != null ? ar.getCreatedAt().toString() : null;
                    e.riskScore = a.getRiskScore();
                    e.riskLevel = a.getRiskLevel();
                    e.topFactors = a.getFeaturesJson() != null && a.getFeaturesJson().get("topFactors") instanceof List<?> l
                            ? l.stream().map(Object::toString).toList()
                            : List.of();
                    e.trend = a.getFeaturesJson() != null ? Objects.toString(a.getFeaturesJson().get("trend"), null) : null;
                    out.add(e);
                }
            });
        }
        return out;
    }

    @Transactional
    public List<AnalyticsViewDto> generateForReport(Long reportId, Long userId) {
        AnalysisReport report = loadOwnedReport(reportId, userId);
        reportPatientLinkService.ensureLinks(report);
        List<Map<String, Object>> rows = report.getReportData();
        if (rows == null) {
            rows = List.of();
        }

        analyticsRepository.deleteAllForReport(reportId);

        List<ReportPatient> links = reportPatientRepository.findByReportIdOrderBySortOrderAsc(reportId);
        for (ReportPatient rp : links) {
            Map<String, Object> slice = rp.getSortOrder() >= 0 && rp.getSortOrder() < rows.size()
                    ? rows.get(rp.getSortOrder())
                    : Map.of();

            AnalyticsScoring.ScoreResult score = AnalyticsScoring.compute(slice);
            Integer prev = previousRiskScore(rp.getPatientId(), report);
            String trend = AnalyticsScoring.compareTrend(score.riskScore(), prev);

            Map<String, Object> features = new LinkedHashMap<>();
            features.put("deviationCount", score.deviationCount());
            features.put("markerStrengths", score.markerStrengths());
            features.put("topFactors", score.topFactors());
            features.put("trend", trend);
            features.put("previousRiskScore", prev);

            String explanation = AnalyticsScoring.buildExplanation(score, trend, prev);

            PatientAiAnalytics entity = new PatientAiAnalytics();
            entity.setReportPatientId(rp.getId());
            entity.setRiskScore(score.riskScore());
            entity.setRiskLevel(score.riskLevel());
            entity.setFeaturesJson(features);
            entity.setExplanationText(explanation);
            analyticsRepository.save(entity);
        }

        runExpertSystemAndMergeFeatures(reportId);

        return buildViews(report, null);
    }

    private void runExpertSystemAndMergeFeatures(Long reportId) {
        try {
            List<ExpertSystemService.PatientInferenceResult> results = expertSystemService.runForReport(reportId);
            for (ExpertSystemService.PatientInferenceResult r : results) {
                analyticsRepository.findByReportPatientId(r.reportPatientId()).ifPresent(ent -> {
                    Map<String, Object> f = ent.getFeaturesJson() == null
                            ? new LinkedHashMap<>()
                            : new LinkedHashMap<>(ent.getFeaturesJson());
                    f.putAll(r.toFeaturesMap());
                    ent.setFeaturesJson(f);
                    analyticsRepository.save(ent);
                });
            }
        } catch (Exception ex) {
            org.slf4j.LoggerFactory.getLogger(PatientAnalyticsService.class)
                    .warn("Expert system failed for report {}: {}", reportId, ex.getMessage(), ex);
        }
    }

    private Integer previousRiskScore(Long patientId, AnalysisReport currentReport) {
        List<AnalysisReport> history = reportRepository.findDistinctByPatientParticipation(patientId);
        AnalysisReport previous = null;
        for (int i = 0; i < history.size(); i++) {
            if (history.get(i).getId().equals(currentReport.getId()) && i + 1 < history.size()) {
                previous = history.get(i + 1);
                break;
            }
        }
        if (previous == null) {
            return null;
        }
        Optional<ReportPatient> prevRp = reportPatientRepository
                .findByReportIdOrderBySortOrderAsc(previous.getId()).stream()
                .filter(x -> x.getPatientId().equals(patientId))
                .findFirst();
        if (prevRp.isEmpty()) {
            return null;
        }
        List<Map<String, Object>> prevRows = previous.getReportData();
        if (prevRows == null) {
            return null;
        }
        int ord = prevRp.get().getSortOrder();
        if (ord < 0 || ord >= prevRows.size()) {
            return null;
        }
        Map<String, Object> prevSlice = prevRows.get(ord);
        return AnalyticsScoring.compute(prevSlice).riskScore();
    }

    private List<AnalyticsViewDto> buildViews(AnalysisReport report, Long onlyPatientId) {
        List<AnalyticsViewDto> out = new ArrayList<>();
        List<ReportPatient> links = reportPatientRepository.findByReportIdOrderBySortOrderAsc(report.getId());
        for (ReportPatient rp : links) {
            if (onlyPatientId != null && !onlyPatientId.equals(rp.getPatientId())) {
                continue;
            }
            out.add(buildView(rp));
        }
        return out;
    }

    private AnalyticsViewDto buildView(ReportPatient rp) {
        Patient patient = patientRepository.findById(rp.getPatientId()).orElse(null);
        String code = patient != null ? patient.getCode() : "?";
        Integer age = patient != null ? patient.getAge() : null;

        AnalyticsViewDto v = new AnalyticsViewDto();
        v.reportPatientId = rp.getId();
        v.patientCode = code;
        v.age = age;
        v.sortOrder = rp.getSortOrder();

        Optional<PatientAiAnalytics> opt = analyticsRepository.findByReportPatientId(rp.getId());
        if (opt.isPresent()) {
            PatientAiAnalytics a = opt.get();
            v.riskScore = a.getRiskScore();
            v.riskLevel = a.getRiskLevel();
            v.features = a.getFeaturesJson();
            v.explanationText = a.getExplanationText();
            v.createdAt = a.getCreatedAt() != null ? a.getCreatedAt().toString() : null;
        } else {
            v.riskScore = null;
            v.riskLevel = null;
            v.features = null;
            v.explanationText = null;
            v.createdAt = null;
        }
        return v;
    }

    private AnalysisReport loadOwnedReport(Long reportId, Long userId) {
        AnalysisReport report = reportRepository.findById(reportId)
                .orElseThrow(() -> new IllegalArgumentException("Not found"));
        if (MeController.hasRole(Role.PATIENT)) {
            User user = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("Not found"));
            if (user.getPatientId() == null) {
                throw new IllegalArgumentException("Not found");
            }
            if (!reportPatientRepository.existsByReportIdAndPatientId(reportId, user.getPatientId())) {
                throw new IllegalArgumentException("Not found");
            }
            return report;
        }
        if (!MeController.isAdmin() && !report.getUserId().equals(userId)) {
            throw new IllegalArgumentException("Not found");
        }
        return report;
    }

    private Long patientFilterPatientId(Long userId) {
        if (!MeController.hasRole(Role.PATIENT)) {
            return null;
        }
        return userRepository.findById(userId).map(User::getPatientId).orElse(null);
    }

    public static class AnalyticsViewDto {
        public long reportPatientId;
        public String patientCode;
        public Integer age;
        public int sortOrder;
        public Integer riskScore;
        public String riskLevel;
        public Map<String, Object> features;
        public String explanationText;
        public String createdAt;
    }

    public static class ReportSummaryDto {
        public boolean restrictedView;
        public int linkedPatientCount;
        public int generatedCount;
        public Integer averageRisk;
        public long countLow;
        public long countMedium;
        public long countHigh;
        public List<ScorePointDto> scores;
    }

    public static class ScorePointDto {
        public int sortOrder;
        public String patientCode;
        public Integer riskScore;
        public String riskLevel;

        public ScorePointDto(int sortOrder, String patientCode, Integer riskScore, String riskLevel) {
            this.sortOrder = sortOrder;
            this.patientCode = patientCode;
            this.riskScore = riskScore;
            this.riskLevel = riskLevel;
        }
    }

    public static class PatientHistoryEntryDto {
        public long reportId;
        public String reportCreatedAt;
        public int riskScore;
        public String riskLevel;
        public List<String> topFactors;
        public String trend;
    }
}
