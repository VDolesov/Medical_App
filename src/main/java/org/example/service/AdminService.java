package org.example.service;

import org.example.exception.NotFoundException;
import org.example.model.AnalysisReport;
import org.example.model.Patient;
import org.example.model.User;
import org.example.dto.auth.UserResponseMapper;
import org.example.model.enums.Role;
import org.example.repository.AnalysisReportRepository;
import org.example.repository.PatientRepository;
import org.example.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class AdminService {

    private final AnalysisReportRepository reportRepository;
    private final PatientRepository patientRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final NormsService normsService;
    private final ObjectMapper objectMapper;
    private final UserResponseMapper userResponseMapper;
    private final ReportPatientAttachmentService reportPatientAttachmentService;

    public AdminService(AnalysisReportRepository reportRepository,
                        PatientRepository patientRepository,
                        UserRepository userRepository,
                        PasswordEncoder passwordEncoder,
                        NormsService normsService,
                        ObjectMapper objectMapper,
                        UserResponseMapper userResponseMapper,
                        ReportPatientAttachmentService reportPatientAttachmentService) {
        this.reportRepository = reportRepository;
        this.patientRepository = patientRepository;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.normsService = normsService;
        this.objectMapper = objectMapper;
        this.userResponseMapper = userResponseMapper;
        this.reportPatientAttachmentService = reportPatientAttachmentService;
    }

    public List<AdminReportRowDto> getAllReports() {
        List<AnalysisReport> reports = reportRepository.findAllByOrderByCreatedAtDesc();
        if (reports.isEmpty()) return List.of();
        List<Long> userIds = reports.stream().map(AnalysisReport::getUserId).distinct().toList();
        Map<Long, User> users = userRepository.findAllById(userIds).stream().collect(Collectors.toMap(User::getId, u -> u));
        return reports.stream()
                .map(r -> AdminReportRowDto.from(r, users.get(r.getUserId())))
                .toList();
    }

    public List<org.example.dto.auth.UserResponse> getAllUsers() {
        return userRepository.findAllByOrderByIdAsc().stream()
                .map(userResponseMapper::toResponse)
                .toList();
    }

    public void createUser(String username, String password, String email, String firstName, String lastName, String role) {
        Role r = Role.valueOf(role.toUpperCase());
        String normalizedUsername = UserValidation.normalizeUsername(username);
        String normalizedEmail = UserValidation.normalizeEmail(email);
        String normalizedFirstName = UserValidation.normalizePersonName(firstName, "First name");
        String normalizedLastName = UserValidation.normalizePersonName(lastName, "Last name");
        UserValidation.requireStrongPassword(password);
        if (userRepository.existsByUsernameIgnoreCase(normalizedUsername) || userRepository.existsByEmail(normalizedEmail)) {
            throw new IllegalArgumentException("Пользователь с таким username или email уже существует");
        }
        User u = new User();
        u.setUsername(normalizedUsername);
        u.setPasswordHash(passwordEncoder.encode(password));
        u.setEmail(normalizedEmail);
        u.setFirstName(normalizedFirstName);
        u.setLastName(normalizedLastName);
        u.setRole(r);
        userRepository.save(u);
    }

    public void deleteUser(Long id, Long currentUserId) {
        if (id.equals(currentUserId)) {
            throw new IllegalArgumentException("Нельзя удалить самого себя!");
        }
        userRepository.deleteById(id);
    }

    public void updateUser(Long id, String email, String firstName, String lastName, String role, String password) {
        User u = userRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Пользователь не найден"));
        if (email != null && !email.isBlank()) u.setEmail(UserValidation.normalizeEmail(email));
        if (firstName != null && !firstName.isBlank()) u.setFirstName(UserValidation.normalizePersonName(firstName, "First name"));
        if (lastName != null && !lastName.isBlank()) u.setLastName(UserValidation.normalizePersonName(lastName, "Last name"));
        if (role != null && !role.isBlank()) u.setRole(Role.valueOf(role.toUpperCase()));
        if (password != null && !password.isBlank()) {
            UserValidation.requireStrongPassword(password);
            u.setPasswordHash(passwordEncoder.encode(password));
        }
        userRepository.save(u);
    }

    public void deleteReportAdmin(Long reportId) {
        List<Long> patientIds = reportPatientAttachmentService.patientIdsOfReport(reportId);
        reportRepository.deleteById(reportId);
        reportPatientAttachmentService.releaseOrphanPatients(patientIds);
    }

    public void setPatientAttendingDoctor(Long patientId, Long doctorUserIdOrNull) {
        Patient p = patientRepository.findById(patientId)
                .orElseThrow(() -> new IllegalArgumentException("Пациент не найден"));
        if (doctorUserIdOrNull == null) {
            p.setAttendingDoctorUserId(null);
        } else {
            User u = userRepository.findById(doctorUserIdOrNull)
                    .orElseThrow(() -> new IllegalArgumentException("Пользователь не найден"));
            if (u.getRole() != Role.DOCTOR) {
                throw new IllegalArgumentException("Можно назначить только пользователя с ролью врач");
            }
            p.setAttendingDoctorUserId(doctorUserIdOrNull);
        }
        patientRepository.save(p);
    }

    public List<Map<String, Object>> listDoctorsForSelect() {
        return userRepository.findByRoleOrderByLastNameAsc(Role.DOCTOR).stream().map(u -> {
            Map<String, Object> m = new HashMap<>();
            m.put("id", u.getId());
            m.put("label", (u.getLastName() != null ? u.getLastName() : "") + " " + (u.getFirstName() != null ? u.getFirstName() : ""));
            m.put("username", u.getUsername());
            return m;
        }).toList();
    }

    public ReportsService.ReportViewDto getReportAdmin(Long reportId, int page, int limit, Long adminUserId) {
        AnalysisReport r = reportRepository.findById(reportId).orElseThrow(() -> new NotFoundException());
        ReportsService.ReportViewDto dto = ReportsService.ReportViewDto.from(r, page, limit, objectMapper);
        reportPatientAttachmentService.enrichReportView(dto, reportId, adminUserId != null ? adminUserId : 0L, true);
        return dto;
    }

    public static class AdminReportRowDto {
        public Long id;
        public Long user_id;
        public String file_name;
        public String created_at;
        public String first_name;
        public String last_name;
        public String username;
        public String email;

        public static AdminReportRowDto from(AnalysisReport r, User u) {
            AdminReportRowDto dto = new AdminReportRowDto();
            dto.id = r.getId();
            dto.user_id = r.getUserId();
            dto.file_name = r.getFileName();
            dto.created_at = r.getCreatedAt().toString();
            if (u != null) {
                dto.first_name = u.getFirstName();
                dto.last_name = u.getLastName();
                dto.username = u.getUsername();
                dto.email = u.getEmail();
            }
            return dto;
        }
    }
}
