package org.example.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.example.config.OpenApiConfig;
import org.example.model.ClinicalRule;
import org.example.model.ClinicalSource;
import org.example.service.AdminExpertService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@Tag(name = OpenApiConfig.TAG_ADMIN_KNOWLEDGE)
@PreAuthorize("hasRole('ADMIN')")
public class AdminExpertController {

    private final AdminExpertService adminExpertService;

    public AdminExpertController(AdminExpertService adminExpertService) {
        this.adminExpertService = adminExpertService;
    }

    @PostMapping("/admin/expert/rules")
    @Operation(
            summary = "Создать клиническое правило",
            description = """
                    Создаёт правило в базе знаний. Тело — `{code, title, severity, priority, category,
                    rationale, patientMessage, sourceId, sourceSection, conditionJson, actionJson, active}`.
                    `conditionJson` валидируется по DSL: `all/any/not/leaf` с операторами `eq, neq, gt, gte,
                    lt, lte, in, not_in, range, out_of_range, present, absent`.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Правило создано; в ответе id и code"),
            @ApiResponse(responseCode = "400", description = "Невалидное conditionJson или дубликат code"),
            @ApiResponse(responseCode = "403", description = "Не администратор")
    })
    public ResponseEntity<?> createRule(@RequestBody Map<String, Object> body) {
        try {
            ClinicalRule r = adminExpertService.create(body);
            return ResponseEntity.ok(Map.of("id", r.getId(), "code", r.getCode()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PutMapping("/admin/expert/rules/{id}")
    @Operation(
            summary = "Обновить правило",
            description = "Полностью перезаписывает поля правила по id. Используется визуальным редактором правил в админ-панели.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Правило обновлено"),
            @ApiResponse(responseCode = "400", description = "Невалидные данные"),
            @ApiResponse(responseCode = "403", description = "Не администратор"),
            @ApiResponse(responseCode = "404", description = "Правило не найдено")
    })
    public ResponseEntity<?> updateRule(
            @Parameter(description = "ID правила") @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        try {
            ClinicalRule r = adminExpertService.update(id, body);
            return ResponseEntity.ok(Map.of("id", r.getId(), "code", r.getCode()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/admin/expert/rules/{id}/toggle")
    @Operation(
            summary = "Активировать или деактивировать правило",
            description = "Тело — `{active: true|false}`. Неактивные правила не участвуют в выводе экспертной системы.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Состояние изменено"),
            @ApiResponse(responseCode = "403", description = "Не администратор"),
            @ApiResponse(responseCode = "404", description = "Правило не найдено")
    })
    public ResponseEntity<?> toggleRule(
            @Parameter(description = "ID правила") @PathVariable Long id,
            @RequestBody(required = false) Map<String, Object> body) {
        boolean active = body != null && Boolean.TRUE.equals(body.get("active"));
        try {
            ClinicalRule r = adminExpertService.setActive(id, active);
            return ResponseEntity.ok(Map.of("id", r.getId(), "active", r.getActive()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping("/admin/expert/rules/{id}")
    @Operation(
            summary = "Удалить правило",
            description = "Полностью удаляет правило вместе с историей сработавших выводов (по каскаду).")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Правило удалено"),
            @ApiResponse(responseCode = "403", description = "Не администратор"),
            @ApiResponse(responseCode = "404", description = "Правило не найдено")
    })
    public ResponseEntity<?> deleteRule(@Parameter(description = "ID правила") @PathVariable Long id) {
        try {
            adminExpertService.delete(id);
            return ResponseEntity.ok(Map.of("deleted", id));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/admin/expert/sources")
    @Operation(
            summary = "Список источников знаний (для админа)",
            description = "Возвращает Клинические Рекомендации с возможностью редактирования.")
    public ResponseEntity<?> listSources() {
        return ResponseEntity.ok(adminExpertService.listSources());
    }

    @PostMapping("/admin/expert/sources")
    @Operation(
            summary = "Создать источник",
            description = "Тело — `{code, title, organization, year, url, description}`. `code` должен быть уникальным.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Источник создан"),
            @ApiResponse(responseCode = "400", description = "Дубликат code или невалидные поля")
    })
    public ResponseEntity<?> createSource(@RequestBody Map<String, Object> body) {
        try {
            ClinicalSource s = adminExpertService.createSource(body);
            return ResponseEntity.ok(Map.of("id", s.getId(), "code", s.getCode()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PutMapping("/admin/expert/sources/{id}")
    @Operation(
            summary = "Обновить источник",
            description = "Перезаписывает поля источника. Изменение `code` запрещено.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Источник обновлён"),
            @ApiResponse(responseCode = "404", description = "Источник не найден")
    })
    public ResponseEntity<?> updateSource(
            @Parameter(description = "ID источника") @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        try {
            ClinicalSource s = adminExpertService.updateSource(id, body);
            return ResponseEntity.ok(Map.of("id", s.getId(), "code", s.getCode()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

}
