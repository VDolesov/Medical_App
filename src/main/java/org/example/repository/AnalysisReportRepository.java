package org.example.repository;

import org.example.model.AnalysisReport;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface AnalysisReportRepository extends JpaRepository<AnalysisReport, Long> {
    List<AnalysisReport> findByUserIdOrderByCreatedAtDesc(Long userId);
    List<AnalysisReport> findAllByOrderByCreatedAtDesc();

    @Query("SELECT DISTINCT ar FROM AnalysisReport ar, ReportPatient rp WHERE rp.reportId = ar.id AND rp.patientId = :patientId ORDER BY ar.createdAt DESC")
    List<AnalysisReport> findDistinctByPatientParticipation(@Param("patientId") Long patientId);
}
