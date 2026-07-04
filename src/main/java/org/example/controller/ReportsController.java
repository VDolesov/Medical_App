package org.example.controller;

import org.example.security.CurrentUserContext;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.example.config.OpenApiConfig;
import org.example.service.ReportsService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@Tag(name = OpenApiConfig.TAG_REPORTS_DOCTOR)
public class ReportsController {

    private final ReportsService reportsService;

    public ReportsController(ReportsService reportsService) {
        this.reportsService = reportsService;
    }

    @GetMapping("/reports")
    @Operation(
            summary = "Список своих отчётов (врач)",
            description = """
                    Возвращает метаданные отчётов, загруженных текущим врачом:
                    id, имя файла, дату создания, число строк.
                    Администратор использует `/admin/reports`, пациент — `/patient/reports`.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Список отчётов врача"),
            @ApiResponse(responseCode = "403", description = "Роль не DOCTOR")
    })
    @PreAuthorize("hasRole('DOCTOR')")
    public ResponseEntity<?> getReports() {
        List<ReportsService.ReportMetaDto> list = reportsService.getReportsByUser(CurrentUserContext.currentUserId());
        return ResponseEntity.ok(list);
    }

    @GetMapping("/report/{id}")
    @Operation(
            summary = "Содержимое отчёта по id",
            description = """
                    Возвращает разобранные строки отчёта с пагинацией.
                    Пациенту использовать `/patient/report/{id}` (получит только свою строку).""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Страница строк отчёта"),
            @ApiResponse(responseCode = "403", description = "Роль PATIENT"),
            @ApiResponse(responseCode = "404", description = "Отчёт не найден или не принадлежит врачу")
    })
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ResponseEntity<?> getReport(
            @Parameter(description = "ID отчёта") @PathVariable Long id,
            @Parameter(description = "Номер страницы, начиная с 1") @RequestParam(defaultValue = "1") int page,
            @Parameter(description = "Размер страницы") @RequestParam(defaultValue = "50") int limit) {
        try {
            return ResponseEntity.ok(reportsService.getReportById(id, CurrentUserContext.currentUserId(), page, limit));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
    }

    @DeleteMapping("/report/{id}")
    @Operation(
            summary = "Удалить свой отчёт",
            description = """
                    Удаляет отчёт врача со всеми привязками строк к пациентам.
                    Пациенты, оставшиеся без других отчётов этого врача, освобождаются
                    (становятся видимы всем врачам как «свободные»).""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Отчёт удалён"),
            @ApiResponse(responseCode = "403", description = "Роль PATIENT"),
            @ApiResponse(responseCode = "404", description = "Отчёт не найден или не принадлежит врачу")
    })
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ResponseEntity<?> deleteReport(@Parameter(description = "ID отчёта") @PathVariable Long id) {
        try {
            reportsService.deleteReport(id, CurrentUserContext.currentUserId());
            return ResponseEntity.ok(Map.of("success", true));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
    }
}
