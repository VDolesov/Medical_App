package org.example.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.example.config.OpenApiConfig;
import org.example.service.ReportPatientAttachmentService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

@RestController
@Tag(name = OpenApiConfig.TAG_REPORT_BIND)
public class ReportRowPatientController {

    private final ReportPatientAttachmentService attachmentService;

    public ReportRowPatientController(ReportPatientAttachmentService attachmentService) {
        this.attachmentService = attachmentService;
    }

    @PutMapping("/doctor/reports/{reportId}/rows/{rowIndex}/patient")
    @Operation(
            summary = "Привязать строку отчёта к пациенту (врач)",
            description = """
                    Связывает строку отчёта с карточкой пациента по его коду ЛК.
                    Если пациент свободен (не закреплён ни за одним врачом), он автоматически
                    становится «моим» — `attending_doctor_user_id` ставится в id текущего врача.
                    Если пациент уже закреплён за другим врачом — будет 403.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Привязано"),
            @ApiResponse(responseCode = "400", description = "Не передан patient_code или код не существует"),
            @ApiResponse(responseCode = "403", description = "Пациент закреплён за другим врачом / роль не DOCTOR"),
            @ApiResponse(responseCode = "404", description = "Отчёт или строка не найдены")
    })
    @PreAuthorize("hasRole('DOCTOR')")
    public ResponseEntity<?> attachDoctor(
            @Parameter(description = "ID отчёта") @PathVariable Long reportId,
            @Parameter(description = "Индекс строки в отчёте (с 0)") @PathVariable int rowIndex,
            @RequestBody Map<String, String> body) {
        try {
            attachmentService.attachPatientToRow(reportId, rowIndex, codeOf(body), MeController.currentUserId(), false);
            return ResponseEntity.ok(Map.of("success", true));
        } catch (ResponseStatusException e) {
            return ResponseEntity.status(e.getStatusCode()).body(Map.of("error", e.getReason()));
        }
    }

    @DeleteMapping("/doctor/reports/{reportId}/rows/{rowIndex}/patient")
    @Operation(
            summary = "Отвязать строку от пациента (врач)",
            description = """
                    Снимает связь строки отчёта с пациентом. Если после этого у пациента
                    не остаётся привязок ни в одном отчёте этого врача — пациент освобождается
                    (`attending_doctor_user_id` обнуляется, он снова виден всем врачам).""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Отвязано"),
            @ApiResponse(responseCode = "403", description = "Роль не DOCTOR / нет доступа к отчёту"),
            @ApiResponse(responseCode = "404", description = "Отчёт или строка не найдены")
    })
    @PreAuthorize("hasRole('DOCTOR')")
    public ResponseEntity<?> detachDoctor(
            @Parameter(description = "ID отчёта") @PathVariable Long reportId,
            @Parameter(description = "Индекс строки") @PathVariable int rowIndex) {
        try {
            attachmentService.detachPatientFromRow(reportId, rowIndex, MeController.currentUserId(), false);
            return ResponseEntity.ok(Map.of("success", true));
        } catch (ResponseStatusException e) {
            return ResponseEntity.status(e.getStatusCode()).body(Map.of("error", e.getReason()));
        }
    }

    @PutMapping("/admin/reports/{reportId}/rows/{rowIndex}/patient")
    @Operation(
            summary = "Привязать строку (админ)",
            description = "Аналогично `/doctor/...`, но без проверки закрепления пациента за врачом. Только для ADMIN.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Привязано"),
            @ApiResponse(responseCode = "400", description = "Невалидный код пациента"),
            @ApiResponse(responseCode = "403", description = "Роль не ADMIN"),
            @ApiResponse(responseCode = "404", description = "Отчёт или строка не найдены")
    })
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> attachAdmin(
            @Parameter(description = "ID отчёта") @PathVariable Long reportId,
            @Parameter(description = "Индекс строки") @PathVariable int rowIndex,
            @RequestBody Map<String, String> body) {
        try {
            attachmentService.attachPatientToRow(reportId, rowIndex, codeOf(body), MeController.currentUserId(), true);
            return ResponseEntity.ok(Map.of("success", true));
        } catch (ResponseStatusException e) {
            return ResponseEntity.status(e.getStatusCode()).body(Map.of("error", e.getReason()));
        }
    }

    @DeleteMapping("/admin/reports/{reportId}/rows/{rowIndex}/patient")
    @Operation(
            summary = "Отвязать строку (админ)",
            description = "Снимает привязку без проверки закрепления. Только для ADMIN.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Отвязано"),
            @ApiResponse(responseCode = "403", description = "Роль не ADMIN"),
            @ApiResponse(responseCode = "404", description = "Отчёт или строка не найдены")
    })
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> detachAdmin(
            @Parameter(description = "ID отчёта") @PathVariable Long reportId,
            @Parameter(description = "Индекс строки") @PathVariable int rowIndex) {
        try {
            attachmentService.detachPatientFromRow(reportId, rowIndex, MeController.currentUserId(), true);
            return ResponseEntity.ok(Map.of("success", true));
        } catch (ResponseStatusException e) {
            return ResponseEntity.status(e.getStatusCode()).body(Map.of("error", e.getReason()));
        }
    }

    private static String codeOf(Map<String, String> body) {
        String code = body.get("patient_code");
        return code != null ? code : body.get("patientCode");
    }
}
