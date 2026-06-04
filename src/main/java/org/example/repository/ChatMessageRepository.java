package org.example.repository;

import org.example.model.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {

    List<ChatMessage> findByThreadIdOrderByCreatedAtAsc(Long threadId);

    long countByThreadIdAndReadByRecipientFalseAndSenderUserIdNot(Long threadId, Long senderUserId);

    @Modifying
    @Query("update ChatMessage m set m.readByRecipient = true where m.threadId = :threadId and m.senderUserId <> :viewerUserId and m.readByRecipient = false")
    int markAsReadForViewer(@Param("threadId") Long threadId, @Param("viewerUserId") Long viewerUserId);
}
