package org.example.controller;

import org.example.security.CurrentUserContext;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import org.example.config.OpenApiConfig;
import org.example.dto.PatientDirectoryEntryDto;
import org.example.service.AdminService;
import org.example.service.PatientDirectoryService;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    private final AdminService adminService;
    private final PatientDirectoryService patientDirectoryService;

    public AdminController(AdminService adminService, PatientDirectoryService patientDirectoryService) {
        this.adminService = adminService;
        this.patientDirectoryService = patientDirectoryService;
    }

    @GetMapping("/admin/reports")
    @Operation(
            tags = OpenApiConfig.TAG_ADMIN_REPORTS,
            summary = "Все отчёты в системе",
            description = "Возвращает метаданные всех отчётов всех пользователей без фильтрации.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Массив отчётов"),
            @ApiResponse(responseCode = "403", description = "Не администратор")
    })
    public ResponseEntity<?> getAllReports() {
        return ResponseEntity.ok(adminService.getAllReports());
    }

    @GetMapping("/admin/report/{id}")
    @Operation(
            tags = OpenApiConfig.TAG_ADMIN_REPORTS,
            summary = "Просмотр любого отчёта",
            description = "Содержимое отчёта с пагинацией; в отличие от `/report/{id}` админу не нужно владеть отчётом.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Страница строк отчёта"),
            @ApiResponse(responseCode = "403", description = "Не администратор"),
            @ApiResponse(responseCode = "404", description = "Отчёт не найден")
    })
    public ResponseEntity<?> getReport(
            @Parameter(description = "ID отчёта") @PathVariable Long id,
            @Parameter(description = "Номер страницы, с 1") @RequestParam(defaultValue = "1") int page,
            @Parameter(description = "Размер страницы") @RequestParam(defaultValue = "50") int limit) {
        try {
            return ResponseEntity.ok(adminService.getReportAdmin(id, page, limit, CurrentUserContext.currentUserId()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", "Not found"));
        }
    }

    @DeleteMapping("/admin/report/{id}")
    @Operation(
            tags = OpenApiConfig.TAG_ADMIN_REPORTS,
            summary = "Удалить любой отчёт",
            description = "Удаляет отчёт со всеми привязками и освобождает пациентов без других отчётов.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Отчёт удалён"),
            @ApiResponse(responseCode = "403", description = "Не администратор")
    })
    public ResponseEntity<?> deleteReport(@Parameter(description = "ID отчёта") @PathVariable Long id) {
        adminService.deleteReportAdmin(id);
        return ResponseEntity.ok(Map.of("message", "Отчёт удалён"));
    }

    @GetMapping("/admin/users")
    @Operation(
            tags = OpenApiConfig.TAG_ADMIN_USERS,
            summary = "Список всех пользователей",
            description = "Все аккаунты — врачи, администраторы, пациенты — с полной публичной информацией.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Массив пользователей"),
            @ApiResponse(responseCode = "403", description = "Не администратор")
    })
    public ResponseEntity<?> getAllUsers() {
        return ResponseEntity.ok(adminService.getAllUsers());
    }

    @PostMapping("/admin/users")
    @Operation(
            tags = OpenApiConfig.TAG_ADMIN_USERS,
            summary = "Создать врача или администратора",
            description = """
                    Создаёт пользователя с ролью `doctor` или `admin`. Пациенты регистрируются
                    самостоятельно через `/register` — этой ручкой их создать нельзя.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Пользователь создан"),
            @ApiResponse(responseCode = "400", description = "Не заполнены поля, неверная роль или дубликат"),
            @ApiResponse(responseCode = "403", description = "Не администратор")
    })
    public ResponseEntity<?> createUser(@RequestBody Map<String, String> body) {
        String username = body.get("username");
        String password = body.get("password");
        String email = body.get("email");
        String firstName = body.get("firstName");
        String lastName = body.get("lastName");
        String role = body.get("role");
        if (username == null || password == null || email == null || firstName == null || lastName == null || role == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Все поля обязательны"));
        }
        if (!List.of("doctor", "admin").contains(role)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Роль должна быть doctor или admin"));
        }
        try {
            adminService.createUser(username, password, email, firstName, lastName, role);
            return ResponseEntity.ok(Map.of("message", "Пользователь создан"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping("/admin/users/{id}")
    @Operation(
            tags = OpenApiConfig.TAG_ADMIN_USERS,
            summary = "Удалить пользователя",
            description = "Удаляет аккаунт. Запрещено удалять самого себя.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Пользователь удалён"),
            @ApiResponse(responseCode = "400", description = "Попытка удалить себя или другой запрет"),
            @ApiResponse(responseCode = "403", description = "Не администратор")
    })
    public ResponseEntity<?> deleteUser(@Parameter(description = "ID пользователя") @PathVariable Long id) {
        try {
            adminService.deleteUser(id, CurrentUserContext.currentUserId());
            return ResponseEntity.ok(Map.of("message", "Пользователь удалён"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/admin/users/{id}")
    @Operation(
            tags = OpenApiConfig.TAG_ADMIN_USERS,
            summary = "Изменить данные пользователя",
            description = "Частичное обновление: можно передать любую комбинацию `email`, `firstName`, `lastName`, `role`, `password`.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Пользователь обновлён"),
            @ApiResponse(responseCode = "403", description = "Не администратор"),
            @ApiResponse(responseCode = "404", description = "Пользователь не найден")
    })
    public ResponseEntity<?> updateUser(
            @Parameter(description = "ID пользователя") @PathVariable Long id,
            @RequestBody Map<String, String> body) {
        try {
            adminService.updateUser(
                    id,
                    body.get("email"),
                    body.get("firstName"),
                    body.get("lastName"),
                    body.get("role"),
                    body.get("password")
            );
            return ResponseEntity.ok(Map.of("message", "Пользователь обновлён"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/admin/patients")
    @Operation(
            tags = OpenApiConfig.TAG_ADMIN_PATIENTS,
            summary = "Все пациенты со статусом закрепления",
            description = "Постраничный список всех пациентов с информацией о текущем лечащем враче и наличии ЛК-аккаунта.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Страница пациентов"),
            @ApiResponse(responseCode = "403", description = "Не администратор")
    })
    public ResponseEntity<?> listPatients(
            @Parameter(description = "Поисковая строка") @RequestParam(required = false) String q,
            @Parameter(description = "Номер страницы, с 0") @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "Размер страницы") @RequestParam(defaultValue = "50") int size,
            @Parameter(description = "Только пациенты с ЛК") @RequestParam(defaultValue = "false") boolean registered_only) {
        Long uid = CurrentUserContext.currentUserId();
        Page<PatientDirectoryEntryDto> result = patientDirectoryService.list(q, page, size, uid != null ? uid : 0L, true,
                registered_only);
        Map<String, Object> out = new HashMap<>();
        out.put("content", result.getContent().stream().map(this::patientEntryToMap).collect(Collectors.toList()));
        out.put("totalElements", result.getTotalElements());
        out.put("totalPages", result.getTotalPages());
        out.put("page", result.getNumber());
        out.put("size", result.getSize());
        return ResponseEntity.ok(out);
    }

    @PatchMapping("/admin/patients/{id}/attending-doctor")
    @Operation(
            tags = OpenApiConfig.TAG_ADMIN_PATIENTS,
            summary = "Назначить или снять лечащего врача",
            description = "Передайте `user_id` в теле — id врача; передайте `null` или пустую строку, чтобы освободить пациента.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Сохранено"),
            @ApiResponse(responseCode = "400", description = "Некорректный user_id или указанный пользователь не врач"),
            @ApiResponse(responseCode = "403", description = "Не администратор")
    })
    public ResponseEntity<?> patchPatientAttending(
            @Parameter(description = "ID пациента") @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        try {
            Long doctorId = parseNullableLong(body.get("user_id"));
            adminService.setPatientAttendingDoctor(id, doctorId);
            return ResponseEntity.ok(Map.of("message", "Сохранено"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/admin/doctors")
    @Operation(
            tags = OpenApiConfig.TAG_ADMIN_PATIENTS,
            summary = "Список врачей для выпадающего списка",
            description = "Краткие данные врачей (id, ФИО) — используется для выбора лечащего врача при назначении пациенту.")
    public ResponseEntity<?> listDoctors() {
        return ResponseEntity.ok(adminService.listDoctorsForSelect());
    }

    private static Long parseNullableLong(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number number) {
            return number.longValue();
        }
        String text = String.valueOf(value).trim();
        if (text.isEmpty()) {
            return null;
        }
        return Long.parseLong(text);
    }

    private Map<String, Object> patientEntryToMap(PatientDirectoryEntryDto d) {
        Map<String, Object> m = new HashMap<>();
        m.put("id", d.id);
        m.put("code", d.code);
        m.put("age", d.age);
        m.put("gender", d.gender);
        m.put("has_app_account", d.hasAppAccount);
        m.put("attending_doctor_user_id", d.attendingDoctorUserId);
        m.put("attending_doctor_label", d.attendingDoctorLabel);
        m.put("viewer_status", d.viewerStatus);
        m.put("lk_user_name", d.lkUserName);
        return m;
    }
}
