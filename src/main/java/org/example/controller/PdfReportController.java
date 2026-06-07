package org.example.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.example.config.OpenApiConfig;
import org.example.model.AnalysisReport;
import org.example.model.ReportPatient;
import org.example.model.User;
import org.example.model.enums.Role;
import org.example.repository.AnalysisReportRepository;
import org.example.repository.ReportPatientRepository;
import org.example.repository.UserRepository;
import org.example.service.PdfReportService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.util.Map;

@RestController
@Tag(name = OpenApiConfig.TAG_REPORTS_PDF)
public class PdfReportController {

    private final PdfReportService pdfReportService;
    private final ReportPatientRepository reportPatientRepository;
    private final AnalysisReportRepository reportRepository;
    private final UserRepository userRepository;

    public PdfReportController(PdfReportService pdfReportService,
                               ReportPatientRepository reportPatientRepository,
                               AnalysisReportRepository reportRepository,
                               UserRepository userRepository) {
        this.pdfReportService = pdfReportService;
        this.reportPatientRepository = reportPatientRepository;
        this.reportRepository = reportRepository;
        this.userRepository = userRepository;
    }

    @GetMapping(value = "/reports/{reportId}/patient/{rpId}/pdf", produces = MediaType.APPLICATION_PDF_VALUE)
    @Operation(
            summary = "PDF-отчёт по одному пациенту",
            description = """
                    Формирует PDF-файл с разбором конкретной строки отчёта: измерения, отклонения,
                    выводы экспертной системы, аналитика. Для пациента (`Role.PATIENT`) формулировки
                    подбираются мягче, без сырых медицинских терминов.

                    Заголовок `Content-Disposition: inline; filename="report-{reportId}-patient-{rpId}.pdf"` —
                    клиент может скачать или открыть встроенным просмотрщиком.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "PDF-документ"),
            @ApiResponse(responseCode = "403", description = "Нет доступа к этой строке отчёта"),
            @ApiResponse(responseCode = "404", description = "Отчёт или строка не найдены"),
            @ApiResponse(responseCode = "500", description = "Шрифт не найден или сбой при генерации PDF")
    })
    public ResponseEntity<?> patientPdf(
            @Parameter(description = "ID отчёта") @PathVariable Long reportId,
            @Parameter(description = "ID строки отчёта (report_patient.id)") @PathVariable Long rpId) throws IOException {
        ReportPatient rp = reportPatientRepository.findById(rpId).orElse(null);
        if (rp == null || !reportId.equals(rp.getReportId())) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
        if (!canAccess(rp, MeController.currentUserId())) {
            return ResponseEntity.status(403).body(Map.of("error", "Forbidden"));
        }
        byte[] pdf = pdfReportService.buildPatientReport(rpId, MeController.hasRole(Role.PATIENT));
        String fileName = "report-" + reportId + "-patient-" + rpId + ".pdf";
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + fileName + "\"")
                .contentType(MediaType.APPLICATION_PDF)
                .body(pdf);
    }

    private boolean canAccess(ReportPatient rp, Long userId) {
        if (MeController.isAdmin()) return true;
        AnalysisReport report = reportRepository.findById(rp.getReportId()).orElse(null);
        if (report == null) return false;
        if (MeController.hasRole(Role.PATIENT)) {
            User u = userRepository.findById(userId).orElse(null);
            return u != null && rp.getPatientId() != null && rp.getPatientId().equals(u.getPatientId());
        }
        return report.getUserId() != null && report.getUserId().equals(userId);
    }
}
