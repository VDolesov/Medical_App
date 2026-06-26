package org.example.service.expert;

import org.example.model.AnalysisReport;
import org.example.model.ClinicalRule;
import org.example.model.Patient;
import org.example.model.ReportPatient;
import org.example.model.RuleExecution;
import org.example.repository.AnalysisReportRepository;
import org.example.repository.ClinicalRuleRepository;
import org.example.repository.PatientRepository;
import org.example.repository.ReportPatientRepository;
import org.example.repository.RuleExecutionRepository;
import org.example.service.PatientReportHistory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

@Service
public class ExpertSystemService {

    private static final Logger log = LoggerFactory.getLogger(ExpertSystemService.class);

    private static final List<String> SEVERITY_ORDER = List.of("INFO", "WARNING", "CRITICAL");

    private final ClinicalRuleRepository ruleRepository;
    private final RuleExecutionRepository executionRepository;
    private final ReportPatientRepository reportPatientRepository;
    private final AnalysisReportRepository reportRepository;
    private final PatientRepository patientRepository;
    private final FactsBuilder factsBuilder;
    private final PatientReportHistory patientReportHistory;
    private final ConditionEvaluator conditionEvaluator = new ConditionEvaluator();

    public ExpertSystemService(ClinicalRuleRepository ruleRepository,
                               RuleExecutionRepository executionRepository,
                               ReportPatientRepository reportPatientRepository,
                               AnalysisReportRepository reportRepository,
                               PatientRepository patientRepository,
                               FactsBuilder factsBuilder,
                               PatientReportHistory patientReportHistory) {
        this.ruleRepository = ruleRepository;
        this.executionRepository = executionRepository;
        this.reportPatientRepository = reportPatientRepository;
        this.reportRepository = reportRepository;
        this.patientRepository = patientRepository;
        this.factsBuilder = factsBuilder;
        this.patientReportHistory = patientReportHistory;
    }

    @Transactional
    public List<PatientInferenceResult> runForReport(Long reportId) {
        AnalysisReport report = reportRepository.findById(reportId)
                .orElseThrow(() -> new IllegalArgumentException("Report not found: " + reportId));

        List<Map<String, Object>> rows = report.getReportData() == null ? List.of() : report.getReportData();
        List<ReportPatient> links = reportPatientRepository.findByReportIdOrderBySortOrderAsc(reportId);
        List<ClinicalRule> rules = ruleRepository.findByActiveTrueOrderByPriorityAsc();

        executionRepository.deleteAllForReport(reportId);

        Map<Long, Patient> patientsById = new HashMap<>();
        List<Long> patientIds = links.stream().map(ReportPatient::getPatientId).filter(Objects::nonNull).distinct().toList();
        if (!patientIds.isEmpty()) {
            for (Patient p : patientRepository.findAllById(patientIds)) {
                patientsById.put(p.getId(), p);
            }
        }

        List<PatientInferenceResult> out = new ArrayList<>(links.size());
        for (ReportPatient rp : links) {
            Map<String, Object> slice = sliceFor(rows, rp.getSortOrder());
            Map<String, Object> prevSlice = patientReportHistory.previousSlice(rp.getPatientId(), report);
            Patient patient = patientsById.get(rp.getPatientId());

            PatientFacts facts = factsBuilder.build(patient, slice, prevSlice);
            List<RuleExecution> triggered = applyRules(rp.getId(), rules, facts);
            out.add(buildResult(rp, facts, triggered));
        }
        return out;
    }

    @Transactional
    public PatientInferenceResult runForReportPatient(Long reportPatientId) {
        ReportPatient rp = reportPatientRepository.findById(reportPatientId)
                .orElseThrow(() -> new IllegalArgumentException("ReportPatient not found: " + reportPatientId));
        AnalysisReport report = reportRepository.findById(rp.getReportId())
                .orElseThrow(() -> new IllegalArgumentException("Report not found: " + rp.getReportId()));

        List<Map<String, Object>> rows = report.getReportData() == null ? List.of() : report.getReportData();
        Map<String, Object> slice = sliceFor(rows, rp.getSortOrder());
        Map<String, Object> prevSlice = patientReportHistory.previousSlice(rp.getPatientId(), report);
        Patient patient = patientRepository.findById(rp.getPatientId()).orElse(null);

        List<ClinicalRule> rules = ruleRepository.findByActiveTrueOrderByPriorityAsc();
        executionRepository.deleteByReportPatientId(rp.getId());

        PatientFacts facts = factsBuilder.build(patient, slice, prevSlice);
        List<RuleExecution> triggered = applyRules(rp.getId(), rules, facts);
        return buildResult(rp, facts, triggered);
    }

    private List<RuleExecution> applyRules(Long reportPatientId, List<ClinicalRule> rules, PatientFacts facts) {
        List<RuleExecution> toSave = new ArrayList<>();
        for (ClinicalRule rule : rules) {
            ConditionEvaluator.EvalResult eval = conditionEvaluator.evaluate(rule.getConditionJson(), facts);
            if (!eval.matched()) {
                continue;
            }
            RuleExecution exec = new RuleExecution();
            exec.setReportPatientId(reportPatientId);
            exec.setRuleId(rule.getId());
            exec.setRuleCode(rule.getCode());
            exec.setTriggered(true);
            exec.setSeverity(rule.getSeverity());
            exec.setMatchedFactsJson(eval.matchedFacts());
            exec.setExplanationText(rule.getRationale());
            exec.setPatientExplanationText(rule.getPatientMessage());
            toSave.add(exec);
        }
        if (toSave.isEmpty()) {
            return List.of();
        }
        List<RuleExecution> saved = new ArrayList<>();
        executionRepository.saveAll(toSave).forEach(saved::add);
        return saved;
    }

    private PatientInferenceResult buildResult(ReportPatient rp, PatientFacts facts, List<RuleExecution> triggered) {
        String overall = triggered.stream()
                .map(RuleExecution::getSeverity)
                .max(Comparator.comparingInt(SEVERITY_ORDER::indexOf))
                .orElse("INFO");

        List<TriggeredRuleView> views = new ArrayList<>(triggered.size());
        for (RuleExecution e : triggered) {
            views.add(new TriggeredRuleView(
                    e.getRuleCode(),
                    e.getSeverity(),
                    e.getExplanationText(),
                    e.getPatientExplanationText(),
                    e.getMatchedFactsJson()));
        }
        return new PatientInferenceResult(
                rp.getId(),
                rp.getPatientId(),
                rp.getSortOrder(),
                overall,
                views,
                facts.asMap());
    }

    private static Map<String, Object> sliceFor(List<Map<String, Object>> rows, int sortOrder) {
        if (sortOrder < 0 || sortOrder >= rows.size()) {
            return Map.of();
        }
        Map<String, Object> row = rows.get(sortOrder);
        return row == null ? Map.of() : row;
    }

    public record TriggeredRuleView(
            String ruleCode,
            String severity,
            String explanationText,
            String patientExplanationText,
            Map<String, Object> matchedFacts
    ) {
    }

    public record PatientInferenceResult(
            Long reportPatientId,
            Long patientId,
            int sortOrder,
            String overallSeverity,
            List<TriggeredRuleView> triggeredRules,
            Map<String, Object> factsSnapshot
    ) {
        public Map<String, Object> toFeaturesMap() {
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("expertSystemSeverity", overallSeverity);
            out.put("expertSystemTriggeredCount", triggeredRules.size());
            List<Map<String, Object>> rules = new ArrayList<>();
            for (TriggeredRuleView v : triggeredRules) {
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("code", v.ruleCode());
                r.put("severity", v.severity());
                r.put("matchedFacts", v.matchedFacts());
                rules.add(r);
            }
            out.put("expertSystemRules", rules);
            return out;
        }
    }
}
