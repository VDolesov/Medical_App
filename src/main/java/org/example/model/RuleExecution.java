package org.example.model;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.Map;

@Entity
@Table(name = "rule_executions")
public class RuleExecution {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "report_patient_id", nullable = false)
    private Long reportPatientId;

    @Column(name = "rule_id", nullable = false)
    private Long ruleId;

    @Column(name = "rule_code", nullable = false, length = 32)
    private String ruleCode;

    @Column(nullable = false)
    private Boolean triggered;

    @Column(nullable = false, length = 16)
    private String severity;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "matched_facts_json", nullable = false, columnDefinition = "jsonb")
    private Map<String, Object> matchedFactsJson;

    @Column(name = "explanation_text", nullable = false, columnDefinition = "TEXT")
    private String explanationText;

    @Column(name = "patient_explanation_text", columnDefinition = "TEXT")
    private String patientExplanationText;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        if (createdAt == null) createdAt = Instant.now();
    }

    public Long getId() { return id; }
    public Long getReportPatientId() { return reportPatientId; }
    public Long getRuleId() { return ruleId; }
    public String getRuleCode() { return ruleCode; }
    public Boolean getTriggered() { return triggered; }
    public String getSeverity() { return severity; }
    public Map<String, Object> getMatchedFactsJson() { return matchedFactsJson; }
    public String getExplanationText() { return explanationText; }
    public String getPatientExplanationText() { return patientExplanationText; }
    public Instant getCreatedAt() { return createdAt; }

    public void setId(Long id) { this.id = id; }
    public void setReportPatientId(Long reportPatientId) { this.reportPatientId = reportPatientId; }
    public void setRuleId(Long ruleId) { this.ruleId = ruleId; }
    public void setRuleCode(String ruleCode) { this.ruleCode = ruleCode; }
    public void setTriggered(Boolean triggered) { this.triggered = triggered; }
    public void setSeverity(String severity) { this.severity = severity; }
    public void setMatchedFactsJson(Map<String, Object> matchedFactsJson) { this.matchedFactsJson = matchedFactsJson; }
    public void setExplanationText(String explanationText) { this.explanationText = explanationText; }
    public void setPatientExplanationText(String patientExplanationText) { this.patientExplanationText = patientExplanationText; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
