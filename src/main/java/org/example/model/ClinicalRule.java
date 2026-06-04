package org.example.model;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.Map;

@Entity
@Table(name = "clinical_rules")
public class ClinicalRule {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 32)
    private String code;

    @Column(nullable = false, length = 512)
    private String title;

    @Column(nullable = false, length = 64)
    private String category;

    @Column(nullable = false, length = 16)
    private String severity;

    @Column(nullable = false)
    private Integer priority;

    @Column(name = "is_active", nullable = false)
    private Boolean active;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "condition_json", nullable = false, columnDefinition = "jsonb")
    private Map<String, Object> conditionJson;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "action_json", nullable = false, columnDefinition = "jsonb")
    private Map<String, Object> actionJson;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String rationale;

    @Column(name = "patient_message", columnDefinition = "TEXT")
    private String patientMessage;

    @Column(name = "source_id")
    private Long sourceId;

    @Column(name = "source_section", length = 128)
    private String sourceSection;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void prePersist() {
        Instant now = Instant.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void preUpdate() {
        updatedAt = Instant.now();
    }

    public Long getId() { return id; }
    public String getCode() { return code; }
    public String getTitle() { return title; }
    public String getCategory() { return category; }
    public String getSeverity() { return severity; }
    public Integer getPriority() { return priority; }
    public Boolean getActive() { return active; }
    public Map<String, Object> getConditionJson() { return conditionJson; }
    public Map<String, Object> getActionJson() { return actionJson; }
    public String getRationale() { return rationale; }
    public String getPatientMessage() { return patientMessage; }
    public Long getSourceId() { return sourceId; }
    public String getSourceSection() { return sourceSection; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }

    public void setId(Long id) { this.id = id; }
    public void setCode(String code) { this.code = code; }
    public void setTitle(String title) { this.title = title; }
    public void setCategory(String category) { this.category = category; }
    public void setSeverity(String severity) { this.severity = severity; }
    public void setPriority(Integer priority) { this.priority = priority; }
    public void setActive(Boolean active) { this.active = active; }
    public void setConditionJson(Map<String, Object> conditionJson) { this.conditionJson = conditionJson; }
    public void setActionJson(Map<String, Object> actionJson) { this.actionJson = actionJson; }
    public void setRationale(String rationale) { this.rationale = rationale; }
    public void setPatientMessage(String patientMessage) { this.patientMessage = patientMessage; }
    public void setSourceId(Long sourceId) { this.sourceId = sourceId; }
    public void setSourceSection(String sourceSection) { this.sourceSection = sourceSection; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
