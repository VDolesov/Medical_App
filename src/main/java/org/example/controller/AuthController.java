package org.example.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.example.config.OpenApiConfig;
import org.example.dto.auth.AuthResponse;
import org.example.dto.auth.LoginRequest;
import org.example.dto.auth.RegisterRequest;
import org.example.service.AuthService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

@RestController
@Tag(name = OpenApiConfig.TAG_AUTH)
@SecurityRequirements
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    @Operation(
            summary = "Зарегистрировать нового пользователя",
            description = """
                    Создаёт учётную запись с одной из ролей: `patient`, `doctor`, `admin`.
                    Для ролей `doctor` и `admin` обязателен `adminSecret` — секретный код,
                    выданный администратором. Для роли `patient` обязателен `patientAge`;
                    в ответе вернётся сгенерированный код вида `P-XXXXXXXX`.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Пользователь создан"),
            @ApiResponse(responseCode = "400", description = "Невалидные поля или пользователь уже существует"),
            @ApiResponse(responseCode = "403", description = "Неверный adminSecret для doctor/admin")
    })
    public ResponseEntity<Map<String, Object>> register(@Valid @RequestBody RegisterRequest req) {
        Optional<String> patientCode = authService.register(req);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("message", "Пользователь зарегистрирован");
        patientCode.ifPresent(code -> body.put("patient_code", code));
        return ResponseEntity.ok(body);
    }

    @PostMapping("/login")
    @Operation(
            summary = "Войти и получить JWT",
            description = "Проверяет логин и пароль, возвращает JWT-токен и публичный профиль пользователя.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Успех — в теле `token` и `user`"),
            @ApiResponse(responseCode = "401", description = "Неверный логин или пароль")
    })
    public AuthResponse login(@Valid @RequestBody LoginRequest req) {
        return authService.login(req);
    }
}
