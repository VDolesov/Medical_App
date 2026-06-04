package org.example.repository;

import org.example.model.ReportPatient;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ReportPatientRepository extends JpaRepository<ReportPatient, Long> {

    List<ReportPatient> findByReportIdOrderBySortOrderAsc(Long reportId);

    List<ReportPatient> findByReportIdAndPatientId(Long reportId, Long patientId);

    @Query("SELECT rp FROM ReportPatient rp JOIN AnalysisReport ar ON rp.reportId = ar.id WHERE rp.patientId = :patientId ORDER BY ar.createdAt DESC")
    List<ReportPatient> findByPatientIdOrderByReportCreatedAtDesc(@Param("patientId") Long patientId);

    boolean existsByReportIdAndPatientId(Long reportId, Long patientId);

    Optional<ReportPatient> findByReportIdAndSortOrder(Long reportId, Integer sortOrder);

    void deleteByReportIdAndSortOrder(Long reportId, Integer sortOrder);

    boolean existsByPatientId(Long patientId);
}
