package org.example.repository;

import org.example.model.ClinicalSource;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface ClinicalSourceRepository extends JpaRepository<ClinicalSource, Long> {

    Optional<ClinicalSource> findByCode(String code);
}
