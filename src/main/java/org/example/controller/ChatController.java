package org.example.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.example.config.OpenApiConfig;
import org.example.model.User;
import org.example.model.enums.Role;
import org.example.repository.UserRepository;
import org.example.service.ChatService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@Tag(name = OpenApiConfig.TAG_CHAT)
public class ChatController {

    private final ChatService chatService;
    private final UserRepository userRepository;

    public ChatController(ChatService chatService, UserRepository userRepository) {
        this.chatService = chatService;
        this.userRepository = userRepository;
    }

    @GetMapping("/chat/threads")
    @Operation(
            summary = "Список моих чатов",
            description = """
                    Возвращает треды, в которых участвует текущий пользователь, отсортированные по дате
                    последнего сообщения. У каждого треда есть `unreadCount`, флаги блокировки
                    (`blocked`, `blockedByCurrentUser`, `blockedByOtherUser`) и `otherDisplayName`.""")
    @ApiResponses(@ApiResponse(responseCode = "200", description = "Массив тредов"))
    public ResponseEntity<?> listThreads() {
        try {
            return ResponseEntity.ok(chatService.listForUser(MeController.currentUserId()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/chat/threads")
    @Operation(
            summary = "Открыть или получить тред с пользователем",
            description = """
                    Создаёт новый тред между текущим пользователем и `otherUserId`, либо возвращает
                    уже существующий. Допустимы только пары PATIENT↔DOCTOR и ADMIN↔DOCTOR.
                    Для PATIENT↔DOCTOR проверяется, что врач закреплён за этим пациентом.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Тред (новый или существующий)"),
            @ApiResponse(responseCode = "400", description = "Неверный otherUserId или недопустимая пара ролей")
    })
    public ResponseEntity<?> openThread(@RequestBody Map<String, Object> req) {
        Object raw = req.get("otherUserId");
        if (!(raw instanceof Number n)) {
            return ResponseEntity.badRequest().body(Map.of("error", "otherUserId обязателен"));
        }
        String subject = req.get("subject") == null ? null : String.valueOf(req.get("subject"));
        try {
            return ResponseEntity.ok(chatService.openOrGetThread(MeController.currentUserId(), n.longValue(), subject));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/chat/threads/by-patient/{patientId}")
    @Operation(
            summary = "Открыть тред врача с пациентом по Patient.id",
            description = """
                    Удобная форма для врача: вместо `userId` пациента берётся id карточки пациента,
                    которой врач владеет. Если у пациента нет ЛК-аккаунта — будет 400.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Тред"),
            @ApiResponse(responseCode = "400", description = "Пациент без ЛК или закреплён за другим врачом")
    })
    public ResponseEntity<?> openByPatient(
            @Parameter(description = "ID пациента") @PathVariable Long patientId,
            @RequestBody(required = false) Map<String, Object> req) {
        String subject = (req == null || req.get("subject") == null) ? null : String.valueOf(req.get("subject"));
        try {
            return ResponseEntity.ok(chatService.openByPatientIdAsDoctor(MeController.currentUserId(), patientId, subject));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/chat/threads/with-my-doctor")
    @Operation(
            summary = "Пациент → лечащий врач",
            description = "Открывает (или возвращает) тред пациента с его лечащим врачом. Только для роли PATIENT.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Тред"),
            @ApiResponse(responseCode = "400", description = "Лечащий врач не назначен")
    })
    public ResponseEntity<?> openWithMyDoctor(@RequestBody(required = false) Map<String, Object> req) {
        String subject = (req == null || req.get("subject") == null) ? null : String.valueOf(req.get("subject"));
        try {
            return ResponseEntity.ok(chatService.openWithMyDoctor(MeController.currentUserId(), subject));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/chat/threads/{id}/messages")
    @Operation(
            summary = "Сообщения треда",
            description = "Возвращает все сообщения треда в хронологическом порядке. Доступно только участникам или администратору.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Массив сообщений"),
            @ApiResponse(responseCode = "404", description = "Тред не найден или нет доступа")
    })
    public ResponseEntity<?> messages(@Parameter(description = "ID треда") @PathVariable Long id) {
        try {
            return ResponseEntity.ok(chatService.listMessages(id, MeController.currentUserId()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/chat/threads/{id}/messages")
    @Operation(
            summary = "Отправить сообщение",
            description = """
                    Отправляет сообщение в тред. Опционально можно прикрепить ссылку на отчёт
                    (`linkedReportId`) или конкретный сработавший вывод правил (`linkedRuleExecutionId`).
                    Если тред заблокирован любой из сторон — будет 400.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Сообщение сохранено"),
            @ApiResponse(responseCode = "400", description = "Пустое сообщение, закрытый или заблокированный тред")
    })
    public ResponseEntity<?> send(
            @Parameter(description = "ID треда") @PathVariable Long id,
            @RequestBody Map<String, Object> req) {
        String body = req.get("body") == null ? null : String.valueOf(req.get("body"));
        Long linkedReportId = req.get("linkedReportId") instanceof Number n1 ? n1.longValue() : null;
        Long linkedRuleExecutionId = req.get("linkedRuleExecutionId") instanceof Number n2 ? n2.longValue() : null;
        try {
            return ResponseEntity.ok(chatService.sendMessage(id, MeController.currentUserId(), body, linkedReportId, linkedRuleExecutionId));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/chat/threads/{id}/read")
    @Operation(
            summary = "Отметить тред как прочитанный",
            description = "Помечает все непрочитанные сообщения треда (от другого участника) как прочитанные текущим пользователем.")
    public ResponseEntity<?> markRead(@Parameter(description = "ID треда") @PathVariable Long id) {
        try {
            return ResponseEntity.ok(Map.of("marked", chatService.markRead(id, MeController.currentUserId())));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/chat/threads/{id}/block")
    @Operation(
            summary = "Заблокировать чат со своей стороны",
            description = """
                    Выставляет `patient_blocked_at` или `doctor_blocked_at` (в зависимости от роли вызывающего).
                    Пока хотя бы одна сторона заблокировала — отправка сообщений в треде невозможна.""")
    public ResponseEntity<?> block(@Parameter(description = "ID треда") @PathVariable Long id) {
        try {
            return ResponseEntity.ok(chatService.setBlocked(id, MeController.currentUserId(), true));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/chat/threads/{id}/unblock")
    @Operation(
            summary = "Снять свою блокировку чата",
            description = "Снимает блокировку с моей стороны. Если другая сторона тоже заблокировала — переписка всё равно недоступна, пока она не разблокирует.")
    public ResponseEntity<?> unblock(@Parameter(description = "ID треда") @PathVariable Long id) {
        try {
            return ResponseEntity.ok(chatService.setBlocked(id, MeController.currentUserId(), false));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/chat/contacts")
    @Operation(
            summary = "С кем можно начать новый чат",
            description = """
                    Возвращает список доступных собеседников по роли вызывающего:
                    ADMIN видит список врачей, DOCTOR — список администраторов.
                    Пациенту это не нужно — у него фиксированный собеседник через `/chat/threads/with-my-doctor`.""")
    public ResponseEntity<?> contacts() {
        User me = userRepository.findById(MeController.currentUserId()).orElse(null);
        if (me == null) {
            return ResponseEntity.status(404).body(Map.of("error", "Не найден"));
        }
        List<User> targets = switch (me.getRole()) {
            case ADMIN -> userRepository.findByRoleOrderByLastNameAsc(Role.DOCTOR);
            case DOCTOR -> userRepository.findByRoleOrderByLastNameAsc(Role.ADMIN);
            default -> List.of();
        };
        List<Map<String, Object>> out = new ArrayList<>(targets.size());
        for (User u : targets) {
            Map<String, Object> m = new HashMap<>();
            m.put("userId", u.getId());
            m.put("username", u.getUsername());
            m.put("firstName", u.getFirstName());
            m.put("lastName", u.getLastName());
            m.put("role", u.getRole().name());
            m.put("displayName", displayName(u));
            out.add(m);
        }
        return ResponseEntity.ok(out);
    }

    @GetMapping("/chat/unread-count")
    @Operation(
            summary = "Число непрочитанных сообщений",
            description = "Возвращает суммарное число непрочитанных сообщений во всех тредах текущего пользователя. Используется для бейджа в нижней навигации мобайла.")
    public ResponseEntity<?> unread() {
        return ResponseEntity.ok(Map.of("unread", chatService.unreadCount(MeController.currentUserId())));
    }

    private static String displayName(User u) {
        String ln = u.getLastName() == null ? "" : u.getLastName().trim();
        String fn = u.getFirstName() == null ? "" : u.getFirstName().trim();
        String full = (ln + " " + fn).trim();
        return full.isEmpty() ? u.getUsername() : full;
    }
}
