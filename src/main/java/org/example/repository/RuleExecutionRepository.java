package org.example.repository;

import org.example.model.RuleExecution;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface RuleExecutionRepository extends JpaRepository<RuleExecution, Long> {

    List<RuleExecution> findByReportPatientIdOrderByCreatedAtDesc(Long reportPatientId);

    List<RuleExecution> findByReportPatientIdAndTriggeredTrueOrderByCreatedAtDesc(Long reportPatientId);

    @Modifying
    @Query("delete from RuleExecution re where re.reportPatientId = :reportPatientId")
    void deleteByReportPatientId(@Param("reportPatientId") Long reportPatientId);

    @Modifying
    @Query(value = "DELETE FROM rule_executions WHERE report_patient_id IN (SELECT id FROM report_patients WHERE report_id = :reportId)", nativeQuery = true)
    void deleteAllForReport(@Param("reportId") Long reportId);
}
