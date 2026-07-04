package org.example.service;

import org.example.dto.PatientDirectoryEntryDto;
import org.example.model.Patient;
import org.example.model.User;
import org.example.repository.PatientRepository;
import org.example.repository.UserRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
public class PatientDirectoryService {

    private final PatientRepository patientRepository;
    private final UserRepository userRepository;

    public PatientDirectoryService(PatientRepository patientRepository, UserRepository userRepository) {
        this.patientRepository = patientRepository;
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public Page<PatientDirectoryEntryDto> list(String query, int page, int size, Long viewerUserId, boolean viewerIsAdmin) {
        return list(query, page, size, viewerUserId, viewerIsAdmin, false);
    }

    @Transactional(readOnly = true)
    public Page<PatientDirectoryEntryDto> list(String query, int page, int size, Long viewerUserId,
                                               boolean viewerIsAdmin, boolean registeredOnly) {
        Pageable pg = PageRequest.of(Math.max(0, page), Math.min(100, Math.max(1, size)), Sort.by("code"));
        Set<Long> withAccount = new HashSet<>(userRepository.findAllLinkedPatientIds());

        String q = (query == null || query.isBlank()) ? null : query.trim();
        Page<Patient> patients;
        if (registeredOnly) {
            List<Long> linkedIds = userRepository.findAllLinkedPatientIds();
            if (linkedIds.isEmpty()) {
                patients = Page.empty(pg);
            } else {
                Set<Long> idSet = new HashSet<>(linkedIds);
                if (q == null) {
                    patients = patientRepository.findByIdIn(idSet, pg);
                } else {
                    Set<Long> nameHits = new HashSet<>(userRepository.findPatientIdsByNameQuery(q));
                    nameHits.retainAll(idSet);
                    patients = searchInScope(idSet, q, nameHits, pg);
                }
            }
        } else if (q == null) {
            patients = patientRepository.findAll(pg);
        } else {
            Set<Long> nameHits = new HashSet<>(userRepository.findPatientIdsByNameQuery(q));
            patients = searchInScope(null, q, nameHits, pg);
        }

        List<Long> ids = patients.getContent().stream().map(Patient::getId).toList();
        Map<Long, User> userByPatient = new HashMap<>();
        if (!ids.isEmpty()) {
            for (User u : userRepository.findByPatientIdIn(ids)) {
                if (u.getPatientId() != null) {
                    userByPatient.put(u.getPatientId(), u);
                }
            }
        }

        return patients.map(p -> toDto(p, withAccount, viewerUserId, viewerIsAdmin, userByPatient.get(p.getId())));
    }

    private Page<Patient> searchInScope(Set<Long> scope, String q, Set<Long> nameHits, Pageable pg) {
        if (scope == null) {
            if (nameHits.isEmpty()) {
                return patientRepository.findByCodeContainingIgnoreCase(q, pg);
            }
            return patientRepository.findByIdInOrCodeContainingIgnoreCase(nameHits, q, pg);
        }
        if (nameHits.isEmpty()) {
            return patientRepository.findByIdInAndCodeContainingIgnoreCase(scope, q, pg);
        }
        return patientRepository.findByIdInAndIdInOrCodeContainingIgnoreCase(scope, nameHits, q, pg);
    }

    private PatientDirectoryEntryDto toDto(Patient p, Set<Long> withAccount, Long viewerUserId, boolean viewerIsAdmin,
                                           User lkUser) {
        Long att = p.getAttendingDoctorUserId();
        String attLabel = null;
        if (att != null) {
            attLabel = userRepository.findById(att).map(this::shortLabel).orElse(null);
        }
        String status;
        if (viewerIsAdmin) {
            status = "admin";
        } else if (att == null) {
            status = "free";
        } else if (att.equals(viewerUserId)) {
            status = "mine";
        } else {
            status = "other_doctor";
        }
        String lkName = lkUser != null ? formatLkUserName(lkUser) : null;
        return new PatientDirectoryEntryDto(
                p.getId(),
                p.getCode(),
                p.getAge(),
                p.getGender(),
                withAccount.contains(p.getId()),
                att,
                attLabel,
                status,
                lkName
        );
    }

    private static String formatLkUserName(User u) {
        String ln = u.getLastName() != null ? u.getLastName().trim() : "";
        String fn = u.getFirstName() != null ? u.getFirstName().trim() : "";
        String name = (ln + " " + fn).trim();
        if (!name.isEmpty()) {
            return name;
        }
        return u.getUsername() != null ? u.getUsername() : "";
    }

    private String shortLabel(User u) {
        String ln = u.getLastName() != null ? u.getLastName() : "";
        String fn = u.getFirstName() != null && !u.getFirstName().isEmpty()
                ? u.getFirstName().substring(0, 1) + "." : "";
        return (ln + " " + fn).trim();
    }
}
