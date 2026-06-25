package org.example.service;

import org.example.model.Patient;
import org.example.repository.AnalysisReportRepository;
import org.example.repository.PatientAiAnalyticsRepository;
import org.example.repository.PatientRepository;
import org.example.repository.ReportPatientRepository;
import org.example.repository.UserRepository;
import org.example.service.expert.ExpertSystemService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PatientAnalyticsServiceAuthorizationTest {

    private final AnalysisReportRepository reportRepository = mock(AnalysisReportRepository.class);
    private final ReportPatientRepository reportPatientRepository = mock(ReportPatientRepository.class);
    private final PatientRepository patientRepository = mock(PatientRepository.class);
    private final PatientAiAnalyticsRepository analyticsRepository = mock(PatientAiAnalyticsRepository.class);
    private final ReportPatientLinkService reportPatientLinkService = mock(ReportPatientLinkService.class);
    private final UserRepository userRepository = mock(UserRepository.class);
    private final ExpertSystemService expertSystemService = mock(ExpertSystemService.class);

    private final PatientAnalyticsService service = new PatientAnalyticsService(
            reportRepository, reportPatientRepository, patientRepository,
            analyticsRepository, reportPatientLinkService, userRepository, expertSystemService);

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    private void authenticateAs(long userId, String role) {
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                userId, null, List.of(new SimpleGrantedAuthority("ROLE_" + role)));
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    @Nested
    @DisplayName("historyForPatient")
    class HistoryForPatient {

        @Test
        @DisplayName("врач НЕ видит историю чужого пациента и не доходит до выборки данных")
        void doctorCannotReadForeignPatient() {
            authenticateAs(5L, "DOCTOR");
            Patient foreign = new Patient();
            foreign.setAttendingDoctorUserId(7L);
            when(patientRepository.findById(99L)).thenReturn(Optional.of(foreign));

            assertThatThrownBy(() -> service.historyForPatient(99L, 5L))
                    .isInstanceOf(IllegalArgumentException.class);
            verify(reportPatientRepository, never()).findByPatientIdOrderByReportCreatedAtDesc(anyLong());
        }

        @Test
        @DisplayName("врач видит историю своего (закреплённого) пациента")
        void doctorCanReadOwnPatient() {
            authenticateAs(5L, "DOCTOR");
            Patient mine = new Patient();
            mine.setAttendingDoctorUserId(5L);
            when(patientRepository.findById(99L)).thenReturn(Optional.of(mine));
            when(reportPatientRepository.findByPatientIdOrderByReportCreatedAtDesc(99L)).thenReturn(List.of());

            assertThat(service.historyForPatient(99L, 5L)).isEmpty();
        }

        @Test
        @DisplayName("админ видит историю любого пациента без проверки закрепления")
        void adminCanReadAnyPatient() {
            authenticateAs(1L, "ADMIN");
            when(reportPatientRepository.findByPatientIdOrderByReportCreatedAtDesc(99L)).thenReturn(List.of());

            assertThat(service.historyForPatient(99L, 1L)).isEmpty();
            verify(patientRepository, never()).findById(anyLong());
        }
    }
}
