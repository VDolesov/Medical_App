package org.example.repository;

import org.example.model.User;
import org.example.model.enums.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
    Optional<User> findByUsernameIgnoreCase(String username);
    boolean existsByUsername(String username);
    boolean existsByUsernameIgnoreCase(String username);
    boolean existsByEmail(String email);
    boolean existsByPatientId(Long patientId);

    Optional<User> findByPatientId(Long patientId);

    @Query("SELECT u.patientId FROM User u WHERE u.patientId IS NOT NULL")
    List<Long> findAllLinkedPatientIds();

    List<User> findByRoleOrderByLastNameAsc(Role role);

    List<User> findAllByOrderByIdAsc();

    List<User> findByPatientIdIn(Collection<Long> patientIds);

    // Поиск ЛК пациентов по ФИО для привязки строки отчёта.
    // Возвращаем patient_id, чтобы дальше отдать в PatientRepository.findByIdIn(...).
    @Query("""
        SELECT u.patientId FROM User u
        WHERE u.patientId IS NOT NULL
          AND (
               LOWER(u.firstName) LIKE LOWER(CONCAT('%', :q, '%'))
            OR LOWER(u.lastName)  LIKE LOWER(CONCAT('%', :q, '%'))
            OR LOWER(CONCAT(COALESCE(u.lastName,''), ' ', COALESCE(u.firstName,''))) LIKE LOWER(CONCAT('%', :q, '%'))
          )
    """)
    List<Long> findPatientIdsByNameQuery(String q);
}
