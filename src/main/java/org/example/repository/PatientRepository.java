package org.example.repository;

import org.example.model.Patient;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.Optional;

public interface PatientRepository extends JpaRepository<Patient, Long> {
    Optional<Patient> findByCode(String code);

    boolean existsByCode(String code);

    Page<Patient> findByCodeContainingIgnoreCase(String fragment, Pageable pageable);

    Page<Patient> findByIdIn(Collection<Long> ids, Pageable pageable);

    Page<Patient> findByIdInAndCodeContainingIgnoreCase(Collection<Long> ids, String fragment, Pageable pageable);

    /** Свободный поиск: пациент попадает в выборку если LIKE по коду ИЛИ id входит в nameHits. */
    @Query("""
        SELECT p FROM Patient p
        WHERE LOWER(p.code) LIKE LOWER(CONCAT('%', :q, '%'))
           OR p.id IN :nameHits
    """)
    Page<Patient> findByIdInOrCodeContainingIgnoreCase(@Param("nameHits") Collection<Long> nameHits,
                                                       @Param("q") String fragment,
                                                       Pageable pageable);

    /** Внутри scope: пациент попадает если LIKE по коду ИЛИ id входит в nameHits (оба под scope). */
    @Query("""
        SELECT p FROM Patient p
        WHERE p.id IN :scope
          AND (LOWER(p.code) LIKE LOWER(CONCAT('%', :q, '%')) OR p.id IN :nameHits)
    """)
    Page<Patient> findByIdInAndIdInOrCodeContainingIgnoreCase(@Param("scope") Collection<Long> scope,
                                                              @Param("nameHits") Collection<Long> nameHits,
                                                              @Param("q") String fragment,
                                                              Pageable pageable);
}
