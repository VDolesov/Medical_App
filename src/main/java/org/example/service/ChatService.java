package org.example.service;

import org.example.model.ChatMessage;
import org.example.model.ChatThread;
import org.example.model.Patient;
import org.example.model.User;
import org.example.model.enums.Role;
import org.example.repository.ChatMessageRepository;
import org.example.repository.ChatThreadRepository;
import org.example.repository.PatientRepository;
import org.example.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

@Service
public class ChatService {

    private final ChatThreadRepository threadRepository;
    private final ChatMessageRepository messageRepository;
    private final UserRepository userRepository;
    private final PatientRepository patientRepository;

    public ChatService(ChatThreadRepository threadRepository,
                       ChatMessageRepository messageRepository,
                       UserRepository userRepository,
                       PatientRepository patientRepository) {
        this.threadRepository = threadRepository;
        this.messageRepository = messageRepository;
        this.userRepository = userRepository;
        this.patientRepository = patientRepository;
    }

    @Transactional(readOnly = true)
    public List<ThreadView> listForUser(Long userId) {
        User user = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("Not found"));
        List<ChatThread> threads;
        if (user.getRole() == Role.DOCTOR) {
            threads = threadRepository.findByDoctorUserIdOrderByLastMessageAtDescCreatedAtDesc(userId);
        } else if (user.getRole() == Role.PATIENT || user.getRole() == Role.ADMIN) {
            threads = threadRepository.findByPatientUserIdOrderByLastMessageAtDescCreatedAtDesc(userId);
        } else {
            threads = List.of();
        }

        Map<Long, User> usersById = loadUsers(threads);
        List<ThreadView> out = new ArrayList<>(threads.size());
        for (ChatThread t : threads) {
            long otherId = userId.equals(t.getPatientUserId()) ? t.getDoctorUserId() : t.getPatientUserId();
            User other = usersById.get(otherId);
            long unread = messageRepository.countByThreadIdAndReadByRecipientFalseAndSenderUserIdNot(t.getId(), userId);
            out.add(new ThreadView(
                    t.getId(),
                    t.getPatientUserId(),
                    t.getDoctorUserId(),
                    t.getPatientId(),
                    t.getSubject(),
                    t.getClosed() != null && t.getClosed(),
                    t.getLastMessageAt() == null ? null : t.getLastMessageAt().toString(),
                    other == null ? null : displayName(other),
                    other == null ? null : other.getRole().name(),
                    unread,
                    isBlocked(t),
                    isBlockedByCurrentUser(t, userId),
                    isBlockedByOtherUser(t, userId),
                    blockedByRole(t),
                    blockedAt(t)));
        }
        return out;
    }

    @Transactional
    public ThreadView openByPatientIdAsDoctor(Long doctorUserId, Long patientId, String subject) {
        User doctor = userRepository.findById(doctorUserId)
                .orElseThrow(() -> new IllegalArgumentException("Not found"));
        if (doctor.getRole() != Role.DOCTOR) {
            throw new IllegalArgumentException("Открыть чат с пациентом может только врач");
        }
        Patient patient = patientRepository.findById(patientId)
                .orElseThrow(() -> new IllegalArgumentException("Пациент не найден"));
        if (patient.getAttendingDoctorUserId() != null
                && !Objects.equals(patient.getAttendingDoctorUserId(), doctorUserId)) {
            throw new IllegalArgumentException("Этот пациент закреплён за другим врачом");
        }
        User patientUser = userRepository.findByPatientId(patientId)
                .orElseThrow(() -> new IllegalArgumentException("У пациента нет личного кабинета — чат невозможен"));
        return openOrGetThread(doctorUserId, patientUser.getId(), subject);
    }

    @Transactional
    public ThreadView openWithMyDoctor(Long patientUserId, String subject) {
        User patientUser = userRepository.findById(patientUserId)
                .orElseThrow(() -> new IllegalArgumentException("Not found"));
        if (patientUser.getRole() != Role.PATIENT || patientUser.getPatientId() == null) {
            throw new IllegalArgumentException("Доступно только пациенту с привязанной карточкой");
        }
        Patient patient = patientRepository.findById(patientUser.getPatientId())
                .orElseThrow(() -> new IllegalArgumentException("Карточка пациента не найдена"));
        if (patient.getAttendingDoctorUserId() == null) {
            throw new IllegalArgumentException("Лечащий врач не назначен");
        }
        return openOrGetThread(patientUserId, patient.getAttendingDoctorUserId(), subject);
    }

    @Transactional
    public ThreadView openOrGetThread(Long currentUserId, Long otherUserId, String subject) {
        if (currentUserId == null || otherUserId == null || currentUserId.equals(otherUserId)) {
            throw new IllegalArgumentException("Bad parties");
        }
        User a = userRepository.findById(currentUserId).orElseThrow(() -> new IllegalArgumentException("Not found"));
        User b = userRepository.findById(otherUserId).orElseThrow(() -> new IllegalArgumentException("Not found"));

        Role ra = a.getRole();
        Role rb = b.getRole();

        boolean patientDoctor =
                (ra == Role.PATIENT && rb == Role.DOCTOR) || (ra == Role.DOCTOR && rb == Role.PATIENT);
        boolean adminDoctor =
                (ra == Role.ADMIN && rb == Role.DOCTOR) || (ra == Role.DOCTOR && rb == Role.ADMIN);
        if (!patientDoctor && !adminDoctor) {
            if (ra == Role.ADMIN || rb == Role.ADMIN) {
                throw new IllegalArgumentException("Администратор может переписываться только с врачами");
            }
            throw new IllegalArgumentException("Чат возможен только между пациентом и врачом или между администратором и врачом");
        }

        User doctorUser = (ra == Role.DOCTOR) ? a : b;
        User nonDoctorUser = (doctorUser == a) ? b : a;

        Patient patient = null;
        if (patientDoctor) {
            patient = nonDoctorUser.getPatientId() == null
                    ? null
                    : patientRepository.findById(nonDoctorUser.getPatientId()).orElse(null);
            if (patient != null && patient.getAttendingDoctorUserId() != null
                    && !Objects.equals(patient.getAttendingDoctorUserId(), doctorUser.getId())) {
                throw new IllegalArgumentException("Этот врач не закреплён за пациентом");
            }
        }

        final User patientUser = nonDoctorUser;
        final Long patientIdForThread = patient == null ? null : patient.getId();

        ChatThread thread = threadRepository
                .findByPatientUserIdAndDoctorUserId(patientUser.getId(), doctorUser.getId())
                .orElseGet(() -> {
                    ChatThread t = new ChatThread();
                    t.setPatientUserId(patientUser.getId());
                    t.setDoctorUserId(doctorUser.getId());
                    t.setPatientId(patientIdForThread);
                    t.setSubject(subject == null || subject.isBlank() ? null : subject.trim());
                    return threadRepository.save(t);
                });

        User other = currentUserId.equals(thread.getPatientUserId()) ? doctorUser : patientUser;
        return new ThreadView(
                thread.getId(),
                thread.getPatientUserId(),
                thread.getDoctorUserId(),
                thread.getPatientId(),
                thread.getSubject(),
                thread.getClosed() != null && thread.getClosed(),
                thread.getLastMessageAt() == null ? null : thread.getLastMessageAt().toString(),
                displayName(other),
                other.getRole().name(),
                0L,
                isBlocked(thread),
                isBlockedByCurrentUser(thread, currentUserId),
                isBlockedByOtherUser(thread, currentUserId),
                blockedByRole(thread),
                blockedAt(thread));
    }

    @Transactional(readOnly = true)
    public List<MessageView> listMessages(Long threadId, Long currentUserId) {
        ChatThread t = requireAccess(threadId, currentUserId);
        Map<Long, User> usersById = loadUsers(List.of(t));
        List<ChatMessage> msgs = messageRepository.findByThreadIdOrderByCreatedAtAsc(threadId);
        List<MessageView> out = new ArrayList<>(msgs.size());
        for (ChatMessage m : msgs) {
            User sender = usersById.get(m.getSenderUserId());
            out.add(new MessageView(
                    m.getId(),
                    m.getThreadId(),
                    m.getSenderUserId(),
                    m.getSenderRole(),
                    sender == null ? null : displayName(sender),
                    m.getBody(),
                    m.getLinkedReportId(),
                    m.getLinkedRuleExecutionId(),
                    m.getReadByRecipient() != null && m.getReadByRecipient(),
                    m.getCreatedAt() == null ? null : m.getCreatedAt().toString()));
        }
        return out;
    }

    @Transactional
    public MessageView sendMessage(Long threadId, Long currentUserId, String body,
                                   Long linkedReportId, Long linkedRuleExecutionId) {
        ChatThread thread = requireAccess(threadId, currentUserId);
        if (thread.getClosed() != null && thread.getClosed()) {
            throw new IllegalArgumentException("Тред закрыт");
        }
        if (isBlocked(thread)) {
            throw new IllegalArgumentException(blockedSendMessage(thread, currentUserId));
        }
        if (body == null || body.isBlank()) {
            throw new IllegalArgumentException("Пустое сообщение");
        }
        if (body.trim().length() > 4000) {
            throw new IllegalArgumentException("Сообщение слишком длинное: максимум 4000 символов");
        }
        User sender = userRepository.findById(currentUserId).orElseThrow();
        ChatMessage m = new ChatMessage();
        m.setThreadId(threadId);
        m.setSenderUserId(currentUserId);
        m.setSenderRole(sender.getRole().name());
        m.setBody(body.trim());
        m.setLinkedReportId(linkedReportId);
        m.setLinkedRuleExecutionId(linkedRuleExecutionId);
        m.setReadByRecipient(false);
        ChatMessage saved = messageRepository.save(m);

        thread.setLastMessageAt(saved.getCreatedAt() == null ? Instant.now() : saved.getCreatedAt());
        threadRepository.save(thread);

        return new MessageView(
                saved.getId(),
                saved.getThreadId(),
                saved.getSenderUserId(),
                saved.getSenderRole(),
                displayName(sender),
                saved.getBody(),
                saved.getLinkedReportId(),
                saved.getLinkedRuleExecutionId(),
                false,
                saved.getCreatedAt() == null ? Instant.now().toString() : saved.getCreatedAt().toString());
    }

    @Transactional
    public ThreadView setBlocked(Long threadId, Long currentUserId, boolean blocked) {
        ChatThread thread = requireAccess(threadId, currentUserId);
        User current = userRepository.findById(currentUserId)
                .orElseThrow(() -> new IllegalArgumentException("Not found"));
        if (!currentUserId.equals(thread.getPatientUserId()) && !currentUserId.equals(thread.getDoctorUserId())) {
            throw new IllegalArgumentException("Блокировка доступна только участникам чата");
        }

        Instant value = blocked ? Instant.now() : null;
        if (currentUserId.equals(thread.getPatientUserId())) {
            thread.setPatientBlockedAt(value);
        } else {
            thread.setDoctorBlockedAt(value);
        }

        ChatThread saved = threadRepository.save(thread);
        long otherId = currentUserId.equals(saved.getPatientUserId())
                ? saved.getDoctorUserId()
                : saved.getPatientUserId();
        User other = userRepository.findById(otherId).orElse(null);
        long unread = messageRepository.countByThreadIdAndReadByRecipientFalseAndSenderUserIdNot(saved.getId(), currentUserId);
        return new ThreadView(
                saved.getId(),
                saved.getPatientUserId(),
                saved.getDoctorUserId(),
                saved.getPatientId(),
                saved.getSubject(),
                saved.getClosed() != null && saved.getClosed(),
                saved.getLastMessageAt() == null ? null : saved.getLastMessageAt().toString(),
                other == null ? null : displayName(other),
                other == null ? null : other.getRole().name(),
                unread,
                isBlocked(saved),
                isBlockedByCurrentUser(saved, current.getId()),
                isBlockedByOtherUser(saved, current.getId()),
                blockedByRole(saved),
                blockedAt(saved));
    }

    @Transactional
    public int markRead(Long threadId, Long currentUserId) {
        requireAccess(threadId, currentUserId);
        return messageRepository.markAsReadForViewer(threadId, currentUserId);
    }

    @Transactional(readOnly = true)
    public long unreadCount(Long currentUserId) {
        User user = userRepository.findById(currentUserId).orElseThrow();
        List<ChatThread> threads = switch (user.getRole()) {
            case DOCTOR -> threadRepository.findByDoctorUserIdOrderByLastMessageAtDescCreatedAtDesc(currentUserId);
            case PATIENT, ADMIN -> threadRepository.findByPatientUserIdOrderByLastMessageAtDescCreatedAtDesc(currentUserId);
            default -> List.of();
        };
        long total = 0;
        for (ChatThread t : threads) {
            total += messageRepository.countByThreadIdAndReadByRecipientFalseAndSenderUserIdNot(t.getId(), currentUserId);
        }
        return total;
    }

    private ChatThread requireAccess(Long threadId, Long currentUserId) {
        ChatThread t = threadRepository.findById(threadId)
                .orElseThrow(() -> new IllegalArgumentException("Not found"));
        User u = userRepository.findById(currentUserId)
                .orElseThrow(() -> new IllegalArgumentException("Not found"));
        boolean isAdmin = u.getRole() == Role.ADMIN;
        boolean isParticipant = currentUserId.equals(t.getPatientUserId()) || currentUserId.equals(t.getDoctorUserId());
        if (!isAdmin && !isParticipant) {
            throw new IllegalArgumentException("Forbidden");
        }
        return t;
    }

    private Map<Long, User> loadUsers(List<ChatThread> threads) {
        Map<Long, User> map = new HashMap<>();
        for (ChatThread t : threads) {
            for (long uid : new long[]{t.getPatientUserId(), t.getDoctorUserId()}) {
                if (!map.containsKey(uid)) {
                    userRepository.findById(uid).ifPresent(u -> map.put(u.getId(), u));
                }
            }
        }
        return map;
    }

    private static String displayName(User u) {
        String first = u.getFirstName() == null ? "" : u.getFirstName().trim();
        String last = u.getLastName() == null ? "" : u.getLastName().trim();
        String full = (last + " " + first).trim();
        return full.isEmpty() ? u.getUsername() : full;
    }

    private static boolean isBlocked(ChatThread t) {
        return t.getPatientBlockedAt() != null || t.getDoctorBlockedAt() != null;
    }

    private static boolean isBlockedByCurrentUser(ChatThread t, Long userId) {
        return (Objects.equals(t.getPatientUserId(), userId) && t.getPatientBlockedAt() != null)
                || (Objects.equals(t.getDoctorUserId(), userId) && t.getDoctorBlockedAt() != null);
    }

    private static boolean isBlockedByOtherUser(ChatThread t, Long userId) {
        return (Objects.equals(t.getPatientUserId(), userId) && t.getDoctorBlockedAt() != null)
                || (Objects.equals(t.getDoctorUserId(), userId) && t.getPatientBlockedAt() != null);
    }

    private static String blockedByRole(ChatThread t) {
        boolean patient = t.getPatientBlockedAt() != null;
        boolean doctor = t.getDoctorBlockedAt() != null;
        if (patient && doctor) return "BOTH";
        if (patient) return "PATIENT";
        if (doctor) return "DOCTOR";
        return null;
    }

    private static String blockedAt(ChatThread t) {
        Instant at = null;
        if (t.getPatientBlockedAt() != null) {
            at = t.getPatientBlockedAt();
        }
        if (t.getDoctorBlockedAt() != null && (at == null || t.getDoctorBlockedAt().isAfter(at))) {
            at = t.getDoctorBlockedAt();
        }
        return at == null ? null : at.toString();
    }

    private static String blockedSendMessage(ChatThread t, Long userId) {
        if (isBlockedByCurrentUser(t, userId)) {
            return "Вы заблокировали этот чат. Чтобы отправить сообщение, сначала разблокируйте переписку.";
        }
        return "Собеседник временно заблокировал этот чат. Отправка сообщений сейчас недоступна.";
    }

    public record ThreadView(
            Long id,
            Long patientUserId,
            Long doctorUserId,
            Long patientId,
            String subject,
            boolean closed,
            String lastMessageAt,
            String otherDisplayName,
            String otherRole,
            long unreadCount,
            boolean blocked,
            boolean blockedByCurrentUser,
            boolean blockedByOtherUser,
            String blockedByRole,
            String blockedAt
    ) {}

    public record MessageView(
            Long id,
            Long threadId,
            Long senderUserId,
            String senderRole,
            String senderDisplayName,
            String body,
            Long linkedReportId,
            Long linkedRuleExecutionId,
            boolean readByRecipient,
            String createdAt
    ) {}
}
