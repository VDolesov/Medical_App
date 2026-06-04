package org.example.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.example.config.OpenApiConfig;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = OpenApiConfig.TAG_SYSTEM)
@SecurityRequirements
public class PingController {

    @GetMapping("/ping")
    @Operation(
            summary = "Проверка живости сервера",
            description = "Возвращает строку `pong`. Используется для health-check без обращения к БД.")
    public String ping() {
        return "pong";
    }
}
