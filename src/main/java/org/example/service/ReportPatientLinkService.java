package org.example.service;

import org.example.model.AnalysisReport;
import org.example.model.Patient;
import org.example.model.ReportPatient;
import org.example.repository.PatientRepository;
import org.example.repository.ReportPatientRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

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
        Set<Integer> sortOrdersUsed = new HashSet<>();
        for (ReportPatient rp : reportPatientRepository.findByReportIdOrderBySortOrderAsc(reportId)) {
            patientIdsUsed.add(rp.getPatientId());
            sortOrdersUsed.add(rp.getSortOrder());
        }

        Map<Integer, String> codeByRow = new LinkedHashMap<>();
        for (int i = 0; i < rows.size(); i++) {
            if (sortOrdersUsed.contains(i)) {
                continue;
            }
            Object codeObj = rows.get(i).get("code");
            String code = codeObj == null ? "" : codeObj.toString().trim();
            if (!code.isEmpty()) {
                codeByRow.put(i, code);
            }
        }
        if (codeByRow.isEmpty()) {
            return;
        }

        Map<String, Patient> patientsByCode = patientRepository.findByCodeIn(new HashSet<>(codeByRow.values())).stream()
                .collect(Collectors.toMap(Patient::getCode, p -> p, (a, b) -> a));

        List<ReportPatient> newLinks = new ArrayList<>();
        for (Map.Entry<Integer, String> e : codeByRow.entrySet()) {
            Patient patient = patientsByCode.get(e.getValue());
            if (patient == null || patientIdsUsed.contains(patient.getId())) {
                continue;
            }
            ReportPatient link = new ReportPatient();
            link.setReportId(reportId);
            link.setPatientId(patient.getId());
            link.setSortOrder(e.getKey());
            newLinks.add(link);
            patientIdsUsed.add(patient.getId());
        }
        if (!newLinks.isEmpty()) {
            reportPatientRepository.saveAll(newLinks);
        }
    }
}
