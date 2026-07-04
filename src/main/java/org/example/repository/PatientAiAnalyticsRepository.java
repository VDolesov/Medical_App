package org.example.repository;

import org.example.model.PatientAiAnalytics;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PatientAiAnalyticsRepository extends JpaRepository<PatientAiAnalytics, Long> {

    Optional<PatientAiAnalytics> findByReportPatientId(Long reportPatientId);

    List<PatientAiAnalytics> findByReportPatientIdIn(List<Long> reportPatientIds);

    @Modifying
    @Query(value = "DELETE FROM patient_ai_analytics WHERE report_patient_id IN (SELECT id FROM report_patients WHERE report_id = :reportId)", nativeQuery = true)
    void deleteAllForReport(@Param("reportId") Long reportId);
}
