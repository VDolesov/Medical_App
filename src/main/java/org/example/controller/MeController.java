package org.example.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.example.config.OpenApiConfig;
import org.example.dto.auth.UserResponse;
import org.example.dto.auth.UserResponseMapper;
import org.example.model.User;
import org.example.repository.UserRepository;
import org.example.security.CurrentUserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@Tag(name = OpenApiConfig.TAG_PROFILE)
public class MeController {

    private final UserRepository userRepository;
    private final UserResponseMapper userResponseMapper;

    public MeController(UserRepository userRepository, UserResponseMapper userResponseMapper) {
        this.userRepository = userRepository;
        this.userResponseMapper = userResponseMapper;
    }

    @GetMapping("/me")
    @Operation(
            summary = "Получить профиль текущего пользователя",
            description = "Возвращает данные пользователя, чей JWT передан в заголовке Authorization.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Профиль пользователя"),
            @ApiResponse(responseCode = "401", description = "Нет валидного JWT"),
            @ApiResponse(responseCode = "404", description = "Пользователь не найден (например, удалён, а токен ещё валиден)")
    })
    public ResponseEntity<?> me() {
        User user = userRepository.findById(CurrentUserContext.currentUserId()).orElse(null);
        if (user == null) {
            return ResponseEntity.status(404).body(Map.of("error", "Пользователь не найден"));
        }
        UserResponse body = userResponseMapper.toResponse(user);
        return ResponseEntity.ok(body);
    }
}
