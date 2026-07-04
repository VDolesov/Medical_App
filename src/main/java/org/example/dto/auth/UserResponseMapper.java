package org.example.dto.auth;

import org.example.model.Patient;
import org.example.model.User;
import org.example.repository.PatientRepository;
import org.springframework.stereotype.Component;

import java.util.Locale;

@Component
public class UserResponseMapper {

    private final PatientRepository patientRepository;

    public UserResponseMapper(PatientRepository patientRepository) {
        this.patientRepository = patientRepository;
    }

    public UserResponse toResponse(User user) {
        Long pid = user.getPatientId();
        String patientCode = null;
        if (pid != null) {
            patientCode = patientRepository.findById(pid).map(Patient::getCode).orElse(null);
        }
        return new UserResponse(
                user.getId(),
                user.getUsername(),
                user.getFirstName(),
                user.getLastName(),
                user.getRole().name().toLowerCase(Locale.ROOT),
                user.getEmail(),
                pid,
                patientCode
        );
    }
}
