package org.example.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import org.example.config.OpenApiConfig;
import org.example.dto.NormDto;
import org.example.service.NormsService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
public class NormsController {

    private final NormsService normsService;

    public NormsController(NormsService normsService) {
        this.normsService = normsService;
    }

    @GetMapping("/norms")
    @Operation(
            tags = OpenApiConfig.TAG_NORMS,
            summary = "Получить справочник норм",
            description = "Возвращает список всех лабораторных норм с минимальными и максимальными значениями и единицами измерения.")
    @ApiResponses(@ApiResponse(responseCode = "200", description = "Массив норм"))
    public ResponseEntity<List<NormDto>> getNorms() {
        return ResponseEntity.ok(normsService.getAll());
    }

    @PostMapping("/admin/norms")
    @Operation(
            tags = OpenApiConfig.TAG_ADMIN_NORMS,
            summary = "Добавить новую норму",
            description = "Создаёт запись в справочнике лабораторных норм. Имя должно быть уникальным.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Норма добавлена"),
            @ApiResponse(responseCode = "400", description = "Не заполнены обязательные поля"),
            @ApiResponse(responseCode = "403", description = "Не администратор")
    })
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> addNorm(@RequestBody Map<String, Object> body) {
        String name = (String) body.get("name");
        Number minVal = (Number) body.get("min_value");
        Number maxVal = (Number) body.get("max_value");
        String unit = (String) body.get("unit");
        if (name == null || minVal == null || maxVal == null || unit == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Все поля обязательны"));
        }
        normsService.create(name, minVal.doubleValue(), maxVal.doubleValue(), unit);
        return ResponseEntity.ok(Map.of("message", "Норма добавлена"));
    }

    @PatchMapping("/admin/norms/{id}")
    @Operation(
            tags = OpenApiConfig.TAG_ADMIN_NORMS,
            summary = "Изменить норму",
            description = "Полностью перезаписывает имя, границы и единицы измерения нормы по её id.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Норма обновлена"),
            @ApiResponse(responseCode = "400", description = "Не заполнены обязательные поля"),
            @ApiResponse(responseCode = "403", description = "Не администратор"),
            @ApiResponse(responseCode = "404", description = "Норма не найдена")
    })
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> updateNorm(
            @Parameter(description = "ID нормы") @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        String name = (String) body.get("name");
        Number minVal = (Number) body.get("min_value");
        Number maxVal = (Number) body.get("max_value");
        String unit = (String) body.get("unit");
        if (name == null || minVal == null || maxVal == null || unit == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Все поля обязательны"));
        }
        try {
            normsService.update(id, name, minVal.doubleValue(), maxVal.doubleValue(), unit);
            return ResponseEntity.ok(Map.of("message", "Норма обновлена"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping("/admin/norms/{id}")
    @Operation(
            tags = OpenApiConfig.TAG_ADMIN_NORMS,
            summary = "Удалить норму",
            description = "Удаляет норму из справочника по id.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Норма удалена"),
            @ApiResponse(responseCode = "403", description = "Не администратор"),
            @ApiResponse(responseCode = "404", description = "Норма не найдена")
    })
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> deleteNorm(@Parameter(description = "ID нормы") @PathVariable Long id) {
        try {
            normsService.delete(id);
            return ResponseEntity.ok(Map.of("message", "Норма удалена"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
        }
    }
}
