package org.example.repository;

import org.example.model.AnalysisNorm;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AnalysisNormRepository extends JpaRepository<AnalysisNorm, Long> {
}
