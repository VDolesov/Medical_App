package org.example.service;

import org.example.model.AnalysisReport;
import org.example.model.Patient;
import org.example.model.User;
import org.example.repository.AnalysisReportRepository;
import org.example.repository.PatientRepository;
import org.example.repository.ReportPatientRepository;
import org.example.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class PatientPortalService {

    private final UserRepository userRepository;
    private final AnalysisReportRepository reportRepository;
    private final ReportPatientRepository reportPatientRepository;
    private final PatientRepository patientRepository;

    public PatientPortalService(UserRepository userRepository,
                                AnalysisReportRepository reportRepository,
                                ReportPatientRepository reportPatientRepository,
                                PatientRepository patientRepository) {
        this.userRepository = userRepository;
        this.reportRepository = reportRepository;
        this.reportPatientRepository = reportPatientRepository;
        this.patientRepository = patientRepository;
    }

    @Transactional(readOnly = true)
    public List<ReportsService.ReportMetaDto> listReportsForUser(Long userId) {
        User user = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("Not found"));
        Long patientId = user.getPatientId();
        if (patientId == null) {
            return List.of();
        }
        return reportRepository.findDistinctByPatientParticipation(patientId).stream()
                .map(ReportsService.ReportMetaDto::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public ReportsService.ReportViewDto getReportForUser(Long reportId, Long userId, int page, int limit) {
        User user = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("Not found"));
        Long patientId = user.getPatientId();
        if (patientId == null) {
            throw new IllegalArgumentException("Not found");
        }
        if (!reportPatientRepository.existsByReportIdAndPatientId(reportId, patientId)) {
            throw new IllegalArgumentException("Not found");
        }
        AnalysisReport r = reportRepository.findById(reportId).orElseThrow(() -> new IllegalArgumentException("Not found"));
        Patient p = patientRepository.findById(patientId).orElseThrow(() -> new IllegalArgumentException("Not found"));
        String code = p.getCode();
        List<Map<String, Object>> all = r.getReportData();
        if (all == null) {
            all = List.of();
        }
        List<Map<String, Object>> filtered = new ArrayList<>();
        for (int i = 0; i < all.size(); i++) {
            Map<String, Object> row = all.get(i);
            if (!code.equals(trimCode(row.get("code")))) {
                continue;
            }
            Map<String, Object> copy = new HashMap<>(row);
            copy.put("row_index", i);
            filtered.add(copy);
        }
        ReportsService.ReportViewDto dto = new ReportsService.ReportViewDto();
        dto.total = filtered.size();
        dto.page = page;
        dto.limit = limit;
        int offset = (page - 1) * limit;
        dto.patients = filtered.stream().skip(offset).limit(limit).toList();
        dto.report = dto.patients;

        String attendingLabel = null;
        if (p.getAttendingDoctorUserId() != null) {
            attendingLabel = userRepository.findById(p.getAttendingDoctorUserId())
                    .map(PatientPortalService::formatDoctorName)
                    .orElse(null);
        }
        String uploadedByLabel = null;
        if (r.getUserId() != null) {
            uploadedByLabel = userRepository.findById(r.getUserId())
                    .map(PatientPortalService::formatDoctorName)
                    .orElse(null);
        }
        for (Map<String, Object> row : dto.patients) {
            if (attendingLabel != null && !attendingLabel.isBlank()) {
                row.put("attending_doctor_label", attendingLabel);
            }
            if (uploadedByLabel != null && !uploadedByLabel.isBlank()) {
                row.put("report_uploaded_by_label", uploadedByLabel);
            }
        }

        return dto;
    }

    private static String formatDoctorName(User u) {
        String ln = u.getLastName() != null ? u.getLastName().trim() : "";
        String fn = u.getFirstName() != null ? u.getFirstName().trim() : "";
        String name = (ln + " " + fn).trim();
        if (!name.isEmpty()) {
            return name;
        }
        return u.getUsername() != null ? u.getUsername() : "";
    }

    private static String trimCode(Object codeObj) {
        if (codeObj == null) {
            return "";
        }
        return String.valueOf(codeObj).trim();
    }
}
