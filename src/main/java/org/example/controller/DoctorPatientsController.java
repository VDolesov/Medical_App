package org.example.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.example.config.OpenApiConfig;
import org.example.dto.PatientDirectoryEntryDto;
import org.example.service.PatientDirectoryService;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@Tag(name = OpenApiConfig.TAG_PATIENT_DIRECTORY)
public class DoctorPatientsController {

    private final PatientDirectoryService patientDirectoryService;

    public DoctorPatientsController(PatientDirectoryService patientDirectoryService) {
        this.patientDirectoryService = patientDirectoryService;
    }

    @GetMapping("/doctor/patients")
    @Operation(
            summary = "Поиск пациентов для привязки или переписки",
            description = """
                    Постраничный список пациентов с фильтром по коду и ФИО ЛК-аккаунта.
                    Каждая запись отмечается флагом `viewer_status`:
                    - `free` — свободен, можно закрепить за собой;
                    - `mine` — закреплён за текущим врачом;
                    - `other_doctor` — закреплён за другим врачом (нельзя трогать);
                    - `admin` — для администратора показываются все, без проверки прав.

                    Параметр `registered_only=true` оставляет только пациентов с ЛК-аккаунтом.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Страница пациентов"),
            @ApiResponse(responseCode = "403", description = "Роль не DOCTOR и не ADMIN")
    })
    @PreAuthorize("hasAnyRole('DOCTOR','ADMIN')")
    public ResponseEntity<?> list(
            @Parameter(description = "Поисковая строка: код пациента или фамилия/имя") @RequestParam(required = false) String q,
            @Parameter(description = "Номер страницы, начиная с 0") @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "Размер страницы, максимум 100") @RequestParam(defaultValue = "20") int size,
            @Parameter(description = "Только пациенты с зарегистрированным ЛК") @RequestParam(defaultValue = "false") boolean registered_only) {
        Page<PatientDirectoryEntryDto> result = patientDirectoryService.list(
                q, page, size, MeController.currentUserId(), MeController.isAdmin(), registered_only);
        Map<String, Object> body = new HashMap<>();
        body.put("content", result.getContent().stream().map(this::toMap).collect(Collectors.toList()));
        body.put("totalElements", result.getTotalElements());
        body.put("totalPages", result.getTotalPages());
        body.put("page", result.getNumber());
        body.put("size", result.getSize());
        return ResponseEntity.ok(body);
    }

    private Map<String, Object> toMap(PatientDirectoryEntryDto d) {
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
