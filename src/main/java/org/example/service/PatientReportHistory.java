package org.example.service;

import org.example.model.AnalysisReport;
import org.example.model.ReportPatient;
import org.example.repository.AnalysisReportRepository;
import org.example.repository.ReportPatientRepository;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

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
        if (patientId == null || currentReport == null) {
            return null;
        }
        List<AnalysisReport> history = reportRepository.findDistinctByPatientParticipation(patientId);
        AnalysisReport previous = null;
        for (int i = 0; i < history.size(); i++) {
            if (Objects.equals(history.get(i).getId(), currentReport.getId()) && i + 1 < history.size()) {
                previous = history.get(i + 1);
                break;
            }
        }
        if (previous == null || previous.getReportData() == null) {
            return null;
        }
        Optional<ReportPatient> prevRp = reportPatientRepository
                .findByReportIdOrderBySortOrderAsc(previous.getId()).stream()
                .filter(x -> patientId.equals(x.getPatientId()))
                .findFirst();
        if (prevRp.isEmpty()) {
            return null;
        }
        int ord = prevRp.get().getSortOrder();
        List<Map<String, Object>> prevRows = previous.getReportData();
        if (ord < 0 || ord >= prevRows.size()) {
            return null;
        }
        return prevRows.get(ord);
    }
}
