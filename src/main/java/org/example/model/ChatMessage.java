package org.example.model;

import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "chat_messages")
public class ChatMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "thread_id", nullable = false)
    private Long threadId;

    @Column(name = "sender_user_id", nullable = false)
    private Long senderUserId;

    @Column(name = "sender_role", nullable = false, length = 16)
    private String senderRole;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String body;

    @Column(name = "linked_report_id")
    private Long linkedReportId;

    @Column(name = "linked_rule_execution_id")
    private Long linkedRuleExecutionId;

    @Column(name = "read_by_recipient", nullable = false)
    private Boolean readByRecipient;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        if (createdAt == null) createdAt = Instant.now();
        if (readByRecipient == null) readByRecipient = false;
    }

    public Long getId() { return id; }
    public Long getThreadId() { return threadId; }
    public Long getSenderUserId() { return senderUserId; }
    public String getSenderRole() { return senderRole; }
    public String getBody() { return body; }
    public Long getLinkedReportId() { return linkedReportId; }
    public Long getLinkedRuleExecutionId() { return linkedRuleExecutionId; }
    public Boolean getReadByRecipient() { return readByRecipient; }
    public Instant getCreatedAt() { return createdAt; }

    public void setId(Long id) { this.id = id; }
    public void setThreadId(Long threadId) { this.threadId = threadId; }
    public void setSenderUserId(Long senderUserId) { this.senderUserId = senderUserId; }
    public void setSenderRole(String senderRole) { this.senderRole = senderRole; }
    public void setBody(String body) { this.body = body; }
    public void setLinkedReportId(Long linkedReportId) { this.linkedReportId = linkedReportId; }
    public void setLinkedRuleExecutionId(Long linkedRuleExecutionId) { this.linkedRuleExecutionId = linkedRuleExecutionId; }
    public void setReadByRecipient(Boolean readByRecipient) { this.readByRecipient = readByRecipient; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
