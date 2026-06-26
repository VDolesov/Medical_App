package org.example.service;

import org.example.model.ChatThread;
import org.example.model.User;
import org.example.model.enums.Role;
import org.example.repository.ChatMessageRepository;
import org.example.repository.ChatThreadRepository;
import org.example.repository.PatientRepository;
import org.example.repository.UserRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ChatServiceAuthorizationTest {

    private final ChatThreadRepository threadRepository = mock(ChatThreadRepository.class);
    private final ChatMessageRepository messageRepository = mock(ChatMessageRepository.class);
    private final UserRepository userRepository = mock(UserRepository.class);
    private final PatientRepository patientRepository = mock(PatientRepository.class);

    private final ChatService service =
            new ChatService(threadRepository, messageRepository, userRepository, patientRepository);

    private ChatThread thread() {
        ChatThread t = new ChatThread();
        t.setPatientUserId(1L);
        t.setDoctorUserId(2L);
        return t;
    }

    private User user(long id, Role role) {
        User u = new User();
        u.setId(id);
        u.setRole(role);
        return u;
    }

    @Test
    @DisplayName("посторонний не может читать сообщения чужого треда")
    void nonParticipantCannotReadMessages() {
        when(threadRepository.findById(10L)).thenReturn(Optional.of(thread()));
        when(userRepository.findById(99L)).thenReturn(Optional.of(user(99L, Role.DOCTOR)));

        assertThatThrownBy(() -> service.listMessages(10L, 99L))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    @DisplayName("посторонний не может писать в чужой тред")
    void nonParticipantCannotSendMessage() {
        when(threadRepository.findById(10L)).thenReturn(Optional.of(thread()));
        when(userRepository.findById(99L)).thenReturn(Optional.of(user(99L, Role.DOCTOR)));

        assertThatThrownBy(() -> service.sendMessage(10L, 99L, "привет", null, null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    @DisplayName("участник треда читает свои сообщения")
    void participantCanReadMessages() {
        when(threadRepository.findById(10L)).thenReturn(Optional.of(thread()));
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L, Role.PATIENT)));
        when(userRepository.findById(2L)).thenReturn(Optional.of(user(2L, Role.DOCTOR)));
        when(messageRepository.findByThreadIdOrderByCreatedAtAsc(10L)).thenReturn(List.of());

        assertThat(service.listMessages(10L, 1L)).isEmpty();
    }
}
