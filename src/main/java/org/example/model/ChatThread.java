package org.example.model;

import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "chat_threads")
public class ChatThread {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "patient_user_id", nullable = false)
    private Long patientUserId;

    @Column(name = "doctor_user_id", nullable = false)
    private Long doctorUserId;

    @Column(name = "patient_id")
    private Long patientId;

    @Column(length = 256)
    private String subject;

    @Column(nullable = false)
    private Boolean closed;

    @Column(name = "patient_blocked_at")
    private Instant patientBlockedAt;

    @Column(name = "doctor_blocked_at")
    private Instant doctorBlockedAt;

    @Column(name = "last_message_at")
    private Instant lastMessageAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        if (createdAt == null) createdAt = Instant.now();
        if (closed == null) closed = false;
    }

    public Long getId() { return id; }
    public Long getPatientUserId() { return patientUserId; }
    public Long getDoctorUserId() { return doctorUserId; }
    public Long getPatientId() { return patientId; }
    public String getSubject() { return subject; }
    public Boolean getClosed() { return closed; }
    public Instant getPatientBlockedAt() { return patientBlockedAt; }
    public Instant getDoctorBlockedAt() { return doctorBlockedAt; }
    public Instant getLastMessageAt() { return lastMessageAt; }
    public Instant getCreatedAt() { return createdAt; }

    public void setId(Long id) { this.id = id; }
    public void setPatientUserId(Long patientUserId) { this.patientUserId = patientUserId; }
    public void setDoctorUserId(Long doctorUserId) { this.doctorUserId = doctorUserId; }
    public void setPatientId(Long patientId) { this.patientId = patientId; }
    public void setSubject(String subject) { this.subject = subject; }
    public void setClosed(Boolean closed) { this.closed = closed; }
    public void setPatientBlockedAt(Instant patientBlockedAt) { this.patientBlockedAt = patientBlockedAt; }
    public void setDoctorBlockedAt(Instant doctorBlockedAt) { this.doctorBlockedAt = doctorBlockedAt; }
    public void setLastMessageAt(Instant lastMessageAt) { this.lastMessageAt = lastMessageAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
