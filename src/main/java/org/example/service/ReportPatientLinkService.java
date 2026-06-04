package org.example.service;

import org.example.model.AnalysisReport;
import org.example.model.Patient;
import org.example.model.ReportPatient;
import org.example.repository.PatientRepository;
import org.example.repository.ReportPatientRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

@Service
public class ReportPatientLinkService {

    private final ReportPatientRepository reportPatientRepository;
    private final PatientRepository patientRepository;

    public ReportPatientLinkService(ReportPatientRepository reportPatientRepository,
                                    PatientRepository patientRepository) {
        this.reportPatientRepository = reportPatientRepository;
        this.patientRepository = patientRepository;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void ensureLinks(AnalysisReport report) {
        Long reportId = report.getId();
        List<Map<String, Object>> rows = report.getReportData();
        if (rows == null || reportId == null) {
            return;
        }
        Set<Long> patientIdsUsed = new HashSet<>();
        for (ReportPatient rp : reportPatientRepository.findByReportIdOrderBySortOrderAsc(reportId)) {
            patientIdsUsed.add(rp.getPatientId());
        }
        for (int i = 0; i < rows.size(); i++) {
            if (reportPatientRepository.findByReportIdAndSortOrder(reportId, i).isPresent()) {
                continue;
            }
            Map<String, Object> row = rows.get(i);
            Object codeObj = row.get("code");
            String code = codeObj == null ? "" : codeObj.toString().trim();
            if (code.isEmpty()) {
                continue;
            }
            Optional<Patient> patientOpt = patientRepository.findByCode(code);
            if (patientOpt.isEmpty()) {
                continue;
            }
            Patient patient = patientOpt.get();
            if (patientIdsUsed.contains(patient.getId())) {
                continue;
            }
            ReportPatient link = new ReportPatient();
            link.setReportId(reportId);
            link.setPatientId(patient.getId());
            link.setSortOrder(i);
            reportPatientRepository.save(link);
            patientIdsUsed.add(patient.getId());
        }
    }
}
