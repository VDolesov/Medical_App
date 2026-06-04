package org.example.model;

import jakarta.persistence.*;

@Entity
@Table(name = "report_patients", uniqueConstraints = {
        @UniqueConstraint(name = "uk_report_patients_order", columnNames = {"report_id", "sort_order"})
})
public class ReportPatient {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "report_id", nullable = false)
    private Long reportId;

    @Column(name = "patient_id", nullable = false)
    private Long patientId;

    @Column(name = "sort_order", nullable = false)
    private Integer sortOrder;

    public Long getId() { return id; }
    public Long getReportId() { return reportId; }
    public Long getPatientId() { return patientId; }
    public Integer getSortOrder() { return sortOrder; }

    public void setId(Long id) { this.id = id; }
    public void setReportId(Long reportId) { this.reportId = reportId; }
    public void setPatientId(Long patientId) { this.patientId = patientId; }
    public void setSortOrder(Integer sortOrder) { this.sortOrder = sortOrder; }
}
