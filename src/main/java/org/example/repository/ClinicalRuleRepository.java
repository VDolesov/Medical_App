package org.example.repository;

import org.example.model.ClinicalRule;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ClinicalRuleRepository extends JpaRepository<ClinicalRule, Long> {

    List<ClinicalRule> findByActiveTrueOrderByPriorityAsc();

    Optional<ClinicalRule> findByCode(String code);

    List<ClinicalRule> findByCategoryAndActiveTrueOrderByPriorityAsc(String category);
}
