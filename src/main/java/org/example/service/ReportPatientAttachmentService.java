package org.example.service;

import org.example.model.AnalysisReport;
import org.example.model.Patient;
import org.example.model.ReportPatient;
import org.example.model.User;
import org.example.repository.AnalysisReportRepository;
import org.example.repository.PatientRepository;
import org.example.repository.ReportPatientRepository;
import org.example.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

@Service
public class ReportPatientAttachmentService {

    private final AnalysisReportRepository reportRepository;
    private final PatientRepository patientRepository;
    private final ReportPatientRepository reportPatientRepository;
    private final UserRepository userRepository;

    public ReportPatientAttachmentService(AnalysisReportRepository reportRepository,
                                          PatientRepository patientRepository,
                                          ReportPatientRepository reportPatientRepository,
                                          UserRepository userRepository) {
        this.reportRepository = reportRepository;
        this.patientRepository = patientRepository;
        this.reportPatientRepository = reportPatientRepository;
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public void enrichReportView(ReportsService.ReportViewDto dto, Long reportId, Long viewerUserId, boolean viewerIsAdmin) {
        if (dto.patients == null || dto.patients.isEmpty()) {
            return;
        }
        int offset = (dto.page - 1) * dto.limit;
        for (int i = 0; i < dto.patients.size(); i++) {
            enrichRow(dto.patients.get(i), reportId, offset + i, viewerUserId, viewerIsAdmin);
        }
    }

    private void enrichRow(Map<String, Object> row, Long reportId, int rowIndex, Long viewerUserId, boolean viewerIsAdmin) {
        Optional<ReportPatient> opt = reportPatientRepository.findByReportIdAndSortOrder(reportId, rowIndex);
        if (opt.isEmpty()) {
            row.put("link_status", "unlinked");
            row.put("link_locked_for_me", false);
            row.put("can_attach", true);
            row.put("can_detach", false);
            row.put("row_index", rowIndex);
            return;
        }
        ReportPatient rp = opt.get();
        Patient p = patientRepository.findById(rp.getPatientId()).orElse(null);
        if (p == null) {
            row.put("link_status", "broken");
            row.put("row_index", rowIndex);
            row.put("link_locked_for_me", false);
            row.put("can_attach", true);
            row.put("can_detach", false);
            return;
        }
        row.put("link_status", "linked");
        row.put("link_patient_id", p.getId());
        row.put("link_code", p.getCode());
        row.put("row_index", rowIndex);
        Long att = p.getAttendingDoctorUserId();
        row.put("attending_doctor_user_id", att);
        if (att != null) {
            userRepository.findById(att).ifPresent(u ->
                    row.put("attending_doctor_label", label(u)));
        } else {
            row.put("attending_doctor_label", null);
        }
        boolean lockedForViewer = !viewerIsAdmin && att != null && !att.equals(viewerUserId);
        row.put("link_locked_for_me", lockedForViewer);
        row.put("can_attach", viewerIsAdmin || !lockedForViewer);
        row.put("can_detach", true);
    }

    private static String label(User u) {
        String ln = u.getLastName() != null ? u.getLastName() : "";
        String fn = u.getFirstName() != null && !u.getFirstName().isEmpty()
                ? u.getFirstName().substring(0, 1) + "." : "";
        return (ln + " " + fn).trim();
    }

    @Transactional
    public void attachPatientToRow(Long reportId, int rowIndex, String patientCode,
                                   Long actorUserId, boolean actorIsAdmin) {
        AnalysisReport report = reportRepository.findById(reportId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Отчёт не найден"));
        assertReportAccess(report, actorUserId, actorIsAdmin);

        List<Map<String, Object>> data = report.getReportData();
        if (data == null || rowIndex < 0 || rowIndex >= data.size()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Некорректный индекс строки");
        }

        String code = patientCode == null ? "" : patientCode.trim();
        if (code.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Укажите код пациента");
        }

        Patient patient = patientRepository.findByCode(code)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Пациент с таким кодом не найден"));

        if (!actorIsAdmin) {
            Long att = patient.getAttendingDoctorUserId();
            if (att != null && !att.equals(actorUserId)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Пациент закреплён за другим врачом");
            }
            if (att == null) {
                patient.setAttendingDoctorUserId(actorUserId);
                patientRepository.save(patient);
            }
        }

        for (ReportPatient existing : reportPatientRepository.findByReportIdAndPatientId(reportId, patient.getId())) {
            if (!Objects.equals(existing.getSortOrder(), rowIndex)) {
                int humanRow = existing.getSortOrder() + 1;
                throw new ResponseStatusException(HttpStatus.CONFLICT,
                        "Этот пациент уже привязан к строке " + humanRow + " этого отчёта. Сначала отвяжите его там или выберите другого пациента.");
            }
        }

        reportPatientRepository.deleteByReportIdAndSortOrder(reportId, rowIndex);

        ReportPatient link = new ReportPatient();
        link.setReportId(reportId);
        link.setPatientId(patient.getId());
        link.setSortOrder(rowIndex);
        reportPatientRepository.save(link);

        Map<String, Object> row = data.get(rowIndex);
        row.put("code", patient.getCode());
        row.put("age", patient.getAge());
        reportRepository.save(report);
    }

    @Transactional
    public void detachPatientFromRow(Long reportId, int rowIndex, Long actorUserId, boolean actorIsAdmin) {
        AnalysisReport report = reportRepository.findById(reportId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Отчёт не найден"));
        assertReportAccess(report, actorUserId, actorIsAdmin);

        List<Map<String, Object>> data = report.getReportData();
        if (data == null || rowIndex < 0 || rowIndex >= data.size()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Некорректный индекс строки");
        }

        Optional<ReportPatient> link = reportPatientRepository.findByReportIdAndSortOrder(reportId, rowIndex);
        Long patientIdForAttending = link.map(ReportPatient::getPatientId).orElse(null);

        reportPatientRepository.deleteByReportIdAndSortOrder(reportId, rowIndex);

        if (patientIdForAttending != null
                && !reportPatientRepository.existsByPatientId(patientIdForAttending)) {
            patientRepository.findById(patientIdForAttending).ifPresent(p -> {
                p.setAttendingDoctorUserId(null);
                patientRepository.save(p);
            });
        }

        Map<String, Object> row = data.get(rowIndex);
        row.put("code", "");
        reportRepository.save(report);
    }

    private void assertReportAccess(AnalysisReport report, Long actorUserId, boolean admin) {
        if (admin) {
            return;
        }
        if (!report.getUserId().equals(actorUserId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Нет доступа к отчёту");
        }
    }

    @Transactional
    public void releaseOrphanPatients(List<Long> patientIds) {
        if (patientIds == null || patientIds.isEmpty()) {
            return;
        }
        for (Long pid : patientIds) {
            if (pid == null) continue;
            if (!reportPatientRepository.existsByPatientId(pid)) {
                patientRepository.findById(pid).ifPresent(p -> {
                    if (p.getAttendingDoctorUserId() != null) {
                        p.setAttendingDoctorUserId(null);
                        patientRepository.save(p);
                    }
                });
            }
        }
    }

    @Transactional(readOnly = true)
    public List<Long> patientIdsOfReport(Long reportId) {
        return reportPatientRepository.findByReportIdOrderBySortOrderAsc(reportId).stream()
                .map(ReportPatient::getPatientId)
                .distinct()
                .toList();
    }
}
