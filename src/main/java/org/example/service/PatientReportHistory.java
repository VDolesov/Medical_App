package org.example.service;

import org.example.model.AnalysisReport;
import org.example.model.ReportPatient;
import org.example.repository.AnalysisReportRepository;
import org.example.repository.ReportPatientRepository;
import org.springframework.stereotype.Component;

import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

@Component
public class PatientReportHistory {

    private final AnalysisReportRepository reportRepository;
    private final ReportPatientRepository reportPatientRepository;

    public PatientReportHistory(AnalysisReportRepository reportRepository,
                                ReportPatientRepository reportPatientRepository) {
        this.reportRepository = reportRepository;
        this.reportPatientRepository = reportPatientRepository;
    }

    public Map<String, Object> previousSlice(Long patientId, AnalysisReport currentReport) {
        if (patientId == null) {
            return null;
        }
        return previousSlices(List.of(patientId), currentReport).get(patientId);
    }

    public Map<Long, Map<String, Object>> previousSlices(Collection<Long> patientIds, AnalysisReport currentReport) {
        if (patientIds == null || currentReport == null || currentReport.getCreatedAt() == null) {
            return Map.of();
        }
        List<Long> ids = patientIds.stream().filter(Objects::nonNull).distinct().toList();
        if (ids.isEmpty()) {
            return Map.of();
        }

        Map<Long, ReportPatient> previousByPatient = new LinkedHashMap<>();
        for (ReportPatient rp : reportPatientRepository.findParticipationBefore(ids, currentReport.getCreatedAt())) {
            previousByPatient.putIfAbsent(rp.getPatientId(), rp);
        }
        if (previousByPatient.isEmpty()) {
            return Map.of();
        }

        List<Long> reportIds = previousByPatient.values().stream()
                .map(ReportPatient::getReportId)
                .filter(Objects::nonNull)
                .distinct()
                .toList();

        Map<Long, List<Map<String, Object>>> rowsByReport = new HashMap<>();
        for (AnalysisReport ar : reportRepository.findAllById(reportIds)) {
            if (ar.getReportData() != null) {
                rowsByReport.put(ar.getId(), ar.getReportData());
            }
        }

        Map<Long, Map<String, Object>> out = new HashMap<>();
        previousByPatient.forEach((patientId, rp) -> {
            List<Map<String, Object>> rows = rowsByReport.get(rp.getReportId());
            if (rows == null) {
                return;
            }
            int sortOrder = rp.getSortOrder();
            if (sortOrder < 0 || sortOrder >= rows.size()) {
                return;
            }
            Map<String, Object> slice = rows.get(sortOrder);
            if (slice != null) {
                out.put(patientId, slice);
            }
        });
        return out;
    }
}
