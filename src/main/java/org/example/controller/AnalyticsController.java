package org.example.controller;

import org.example.exception.NotFoundException;
import org.example.security.CurrentUserContext;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.example.config.OpenApiConfig;
import org.example.model.ReportPatient;
import org.example.repository.ReportPatientRepository;
import org.example.service.PatientAnalyticsService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@Tag(name = OpenApiConfig.TAG_ANALYTICS)
public class AnalyticsController {

    private final PatientAnalyticsService analyticsService;
    private final ReportPatientRepository reportPatientRepository;

    public AnalyticsController(PatientAnalyticsService analyticsService,
                               ReportPatientRepository reportPatientRepository) {
        this.analyticsService = analyticsService;
        this.reportPatientRepository = reportPatientRepository;
    }

    @GetMapping("/analytics/report/{id}/summary")
    @Operation(
            summary = "Сводка по отчёту",
            description = "Возвращает агрегированные показатели по отчёту: число пациентов, распределение по уровню риска, средний балл.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Сводка"),
            @ApiResponse(responseCode = "404", description = "Отчёт не найден или нет доступа")
    })
    public ResponseEntity<?> summary(@Parameter(description = "ID отчёта") @PathVariable Long id) {
        try {
            return ResponseEntity.ok(analyticsService.summaryForReport(id, CurrentUserContext.currentUserId()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
    }

    @GetMapping("/analytics/report/{id}/patients")
    @Operation(
            summary = "Список пациентов отчёта с риском",
            description = "Возвращает список строк отчёта с риск-оценкой каждой; используется в админ-панели и кабинете врача.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Массив пациентов отчёта"),
            @ApiResponse(responseCode = "404", description = "Отчёт не найден")
    })
    public ResponseEntity<?> listPatients(@Parameter(description = "ID отчёта") @PathVariable Long id) {
        try {
            return ResponseEntity.ok(analyticsService.listForReport(id, CurrentUserContext.currentUserId()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
    }

    @GetMapping("/analytics/report/{reportId}/patient/{reportPatientId}")
    @Operation(
            summary = "Аналитика по одному пациенту в отчёте",
            description = "Возвращает риск-оценку, объяснение и набор признаков для конкретной строки отчёта.")
    public ResponseEntity<?> one(
            @Parameter(description = "ID отчёта") @PathVariable Long reportId,
            @Parameter(description = "ID строки отчёта (report_patient.id)") @PathVariable Long reportPatientId) {
        try {
            return ResponseEntity.ok(analyticsService.getForReportPatient(reportId, reportPatientId, CurrentUserContext.currentUserId()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
    }

    @GetMapping("/analytics/report-patient/{reportPatientId}")
    @Operation(
            summary = "Аналитика по report_patient.id (короткая форма)",
            description = "То же, что `/analytics/patient/{reportPatientId}` — оставлено для обратной совместимости клиента.")
    public ResponseEntity<?> oneByReportPatientLink(@PathVariable Long reportPatientId) {
        return oneByLink(reportPatientId);
    }

    @GetMapping("/analytics/patient/{reportPatientId}")
    @Operation(
            summary = "Аналитика по report_patient.id",
            description = "Возвращает аналитику для конкретной строки отчёта, не требуя знать reportId.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Аналитика"),
            @ApiResponse(responseCode = "404", description = "Строка не найдена")
    })
    public ResponseEntity<?> oneByLink(@Parameter(description = "ID строки отчёта") @PathVariable Long reportPatientId) {
        try {
            ReportPatient rp = reportPatientRepository.findById(reportPatientId)
                    .orElseThrow(() -> new NotFoundException());
            return ResponseEntity.ok(analyticsService.getForReportPatient(rp.getReportId(), reportPatientId, CurrentUserContext.currentUserId()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
    }

    @GetMapping("/analytics/patient/{patientId}/history")
    @Operation(
            summary = "История риска пациента",
            description = "Возвращает все срезы аналитики по конкретному пациенту в хронологическом порядке — для построения трендов.")
    public ResponseEntity<?> patientHistory(@Parameter(description = "ID пациента") @PathVariable Long patientId) {
        try {
            return ResponseEntity.ok(analyticsService.historyForPatient(patientId, CurrentUserContext.currentUserId()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
    }

    @PostMapping("/analytics/report/{id}/generate")
    @Operation(
            summary = "Перегенерировать аналитику отчёта",
            description = """
                    Пересчитывает риск-оценку и набор признаков по всем строкам отчёта.
                    Нужно вызывать после изменения справочника норм или правил.
                    Доступно врачу и администратору.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Перегенерация выполнена"),
            @ApiResponse(responseCode = "403", description = "Роль PATIENT"),
            @ApiResponse(responseCode = "404", description = "Отчёт не найден")
    })
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ResponseEntity<?> generate(@Parameter(description = "ID отчёта") @PathVariable Long id) {
        try {
            return ResponseEntity.ok(analyticsService.generateForReport(id, CurrentUserContext.currentUserId()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
    }
}
