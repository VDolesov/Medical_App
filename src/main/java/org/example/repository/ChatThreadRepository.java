package org.example.repository;

import org.example.model.ChatThread;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ChatThreadRepository extends JpaRepository<ChatThread, Long> {

    Optional<ChatThread> findByPatientUserIdAndDoctorUserId(Long patientUserId, Long doctorUserId);

    List<ChatThread> findByDoctorUserIdOrderByLastMessageAtDescCreatedAtDesc(Long doctorUserId);

    List<ChatThread> findByPatientUserIdOrderByLastMessageAtDescCreatedAtDesc(Long patientUserId);
}
