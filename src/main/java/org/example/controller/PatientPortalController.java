package org.example.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.example.config.OpenApiConfig;
import org.example.model.enums.Role;
import org.example.service.PatientPortalService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@Tag(name = OpenApiConfig.TAG_PATIENT_PORTAL)
public class PatientPortalController {

    private final PatientPortalService patientPortalService;

    public PatientPortalController(PatientPortalService patientPortalService) {
        this.patientPortalService = patientPortalService;
    }

    @GetMapping("/patient/reports")
    @Operation(
            summary = "Мои отчёты (пациент)",
            description = """
                    Возвращает список отчётов, в которых есть строки, привязанные к моей карточке пациента.
                    Доступно только роли PATIENT.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Список отчётов пациента"),
            @ApiResponse(responseCode = "403", description = "Роль не PATIENT")
    })
    public ResponseEntity<?> listReports() {
        if (!MeController.hasRole(Role.PATIENT)) {
            return ResponseEntity.status(403).body(Map.of("error", "Доступ только для пациента"));
        }
        try {
            return ResponseEntity.ok(patientPortalService.listReportsForUser(MeController.currentUserId()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
    }

    @GetMapping("/patient/report/{id}")
    @Operation(
            summary = "Мой срез отчёта",
            description = """
                    Возвращает только ту строку отчёта, которая принадлежит карточке пациента,
                    с расшифровкой отклонений. Доступ только роли PATIENT.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Срез отчёта"),
            @ApiResponse(responseCode = "403", description = "Роль не PATIENT"),
            @ApiResponse(responseCode = "404", description = "Отчёт не содержит данных по этому пациенту")
    })
    public ResponseEntity<?> getReport(
            @Parameter(description = "ID отчёта") @PathVariable Long id,
            @Parameter(description = "Номер страницы, с 1") @RequestParam(defaultValue = "1") int page,
            @Parameter(description = "Размер страницы") @RequestParam(defaultValue = "50") int limit) {
        if (!MeController.hasRole(Role.PATIENT)) {
            return ResponseEntity.status(403).body(Map.of("error", "Доступ только для пациента"));
        }
        try {
            return ResponseEntity.ok(patientPortalService.getReportForUser(id, MeController.currentUserId(), page, limit));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
    }
}
