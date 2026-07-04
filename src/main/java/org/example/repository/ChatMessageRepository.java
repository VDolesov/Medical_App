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

    interface UnreadCountView {
        Long getThreadId();
        long getUnread();
    }

    @Query("""
            select m.threadId as threadId, count(m) as unread
            from ChatMessage m
            where m.threadId in :threadIds and m.readByRecipient = false and m.senderUserId <> :viewerUserId
            group by m.threadId""")
    List<UnreadCountView> countUnreadByThreads(@Param("threadIds") List<Long> threadIds,
                                               @Param("viewerUserId") Long viewerUserId);

    @Query("""
            select count(m)
            from ChatMessage m, ChatThread t
            where m.threadId = t.id
              and m.readByRecipient = false
              and m.senderUserId <> :userId
              and (t.doctorUserId = :userId or t.patientUserId = :userId)""")
    long countUnreadForUser(@Param("userId") Long userId);

    @Modifying
    @Query("update ChatMessage m set m.readByRecipient = true where m.threadId = :threadId and m.senderUserId <> :viewerUserId and m.readByRecipient = false")
    int markAsReadForViewer(@Param("threadId") Long threadId, @Param("viewerUserId") Long viewerUserId);
}
