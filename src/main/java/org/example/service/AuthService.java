package org.example.service;

import org.example.dto.auth.AuthResponse;
import org.example.dto.auth.LoginRequest;
import org.example.dto.auth.RegisterRequest;
import org.example.dto.auth.UserResponse;
import org.example.model.Patient;
import org.example.model.User;
import org.example.model.enums.Role;
import org.example.repository.PatientRepository;
import org.example.repository.UserRepository;
import org.example.security.JwtUtil;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.example.dto.auth.UserResponseMapper;

import java.util.Locale;
import java.util.Optional;
import java.util.concurrent.ThreadLocalRandom;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PatientRepository patientRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final UserResponseMapper userResponseMapper;
    private final String adminSecret;

    private static final char[] PATIENT_CODE_SYMBOLS = "23456789ABCDEFGHJKMNPQRSTUVWXYZ".toCharArray();

    private static final String DUMMY_PASSWORD_HASH =
            "$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy";

    public AuthService(UserRepository userRepository, PatientRepository patientRepository,
                       PasswordEncoder passwordEncoder, JwtUtil jwtUtil, UserResponseMapper userResponseMapper,
                       @Value("${app.admin-secret:}") String adminSecret) {
        this.userRepository = userRepository;
        this.patientRepository = patientRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
        this.userResponseMapper = userResponseMapper;
        String trimmedSecret = adminSecret != null ? adminSecret.trim() : "";
        if (trimmedSecret.length() < 16) {
            throw new IllegalStateException("ADMIN_SECRET must be at least 16 characters");
        }
        this.adminSecret = trimmedSecret;
    }

    public Optional<String> register(RegisterRequest req) {
        String username = UserValidation.normalizeUsername(req.getUsername());
        String email = UserValidation.normalizeEmail(req.getEmail());
        String firstName = UserValidation.normalizePersonName(req.getFirstName(), "First name");
        String lastName = UserValidation.normalizePersonName(req.getLastName(), "Last name");
        String password = req.getPassword() != null ? req.getPassword() : "";
        UserValidation.requireStrongPassword(password);

        Role role = parseRole(req.getRole());

        if (role == Role.ADMIN || role == Role.DOCTOR) {
            if (!staffSecretMatches(req.getAdminSecret())) {
                throw new IllegalArgumentException("Неверный секретный код для администратора");
            }
        }

        if (role == Role.PATIENT) {
            Integer patientAge = req.getPatientAge();
            if (patientAge == null || patientAge < 1 || patientAge > 150) {
                throw new IllegalArgumentException("Укажите возраст от 1 до 150");
            }
        }

        if (!firstName.matches("^[\\p{L}\\s'-]+$") || !lastName.matches("^[\\p{L}\\s'-]+$")) {
            throw new IllegalArgumentException("Имя и фамилия могут содержать только буквы, пробелы, апострофы и дефисы");
        }
        if (userRepository.existsByUsernameIgnoreCase(username) || userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("Пользователь с таким username или email уже существует");
        }

        User u = new User();
        u.setUsername(username);
        u.setEmail(email);
        u.setFirstName(firstName);
        u.setLastName(lastName);
        u.setRole(role);
        u.setPasswordHash(passwordEncoder.encode(password));

        String assignedPatientCode = null;
        if (role == Role.PATIENT) {
            Integer patientAge = req.getPatientAge();
            assignedPatientCode = allocateUniquePatientCode();
            Patient patient = new Patient();
            patient.setCode(assignedPatientCode);
            patient.setAge(patientAge);
            patientRepository.save(patient);
            u.setPatientId(patient.getId());
        }

        userRepository.save(u);
        return Optional.ofNullable(assignedPatientCode);
    }

    private String allocateUniquePatientCode() {
        ThreadLocalRandom rnd = ThreadLocalRandom.current();
        for (int attempt = 0; attempt < 48; attempt++) {
            StringBuilder sb = new StringBuilder("P-");
            for (int i = 0; i < 8; i++) {
                sb.append(PATIENT_CODE_SYMBOLS[rnd.nextInt(PATIENT_CODE_SYMBOLS.length)]);
            }
            String code = sb.toString();
            if (!patientRepository.existsByCode(code)) {
                return code;
            }
        }
        throw new IllegalStateException("Не удалось сгенерировать уникальный код пациента");
    }

    private static String trim(String s) {
        return s != null ? s.trim() : "";
    }

    private boolean staffSecretMatches(String rawSecret) {
        String provided = rawSecret != null ? rawSecret.trim() : "";
        return java.security.MessageDigest.isEqual(
                provided.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                adminSecret.getBytes(java.nio.charset.StandardCharsets.UTF_8)
        );
    }

    public AuthResponse login(LoginRequest req) {
        String username = trim(req.getUsername());
        String password = req.getPassword() != null ? req.getPassword() : "";
        if (username.isEmpty()) {
            throw new IllegalArgumentException("Неверный логин или пароль");
        }
        Optional<User> userOpt = userRepository.findByUsernameIgnoreCase(username);
        String storedHash = userOpt.map(User::getPasswordHash).orElse(DUMMY_PASSWORD_HASH);
        boolean passwordMatches = passwordEncoder.matches(password, storedHash);
        if (userOpt.isEmpty() || !passwordMatches) {
            throw new IllegalArgumentException("Неверный логин или пароль");
        }
        User user = userOpt.get();

        String token = jwtUtil.generateToken(user.getId(), user.getRole());
        UserResponse userResp = userResponseMapper.toResponse(user);
        return new AuthResponse(token, userResp);
    }

    private Role parseRole(String roleRaw) {
        if (roleRaw == null) {
            throw new IllegalArgumentException("Роль должна быть doctor, admin или patient");
        }
        String v = roleRaw.trim().toUpperCase(Locale.ROOT);
        return switch (v) {
            case "DOCTOR" -> Role.DOCTOR;
            case "ADMIN" -> Role.ADMIN;
            case "PATIENT" -> Role.PATIENT;
            default -> throw new IllegalArgumentException("Роль должна быть doctor, admin или patient");
        };
    }
}
