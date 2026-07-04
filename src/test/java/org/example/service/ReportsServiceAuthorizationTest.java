package org.example.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.example.exception.NotFoundException;
import org.example.model.AnalysisReport;
import org.example.repository.AnalysisReportRepository;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ReportsServiceAuthorizationTest {

    private final AnalysisReportRepository reportRepository = mock(AnalysisReportRepository.class);
    private final ReportPatientAttachmentService attachmentService = mock(ReportPatientAttachmentService.class);
    private final ReportsService service = new ReportsService(reportRepository, new ObjectMapper(), attachmentService);

    private AnalysisReport ownedBy(long userId) {
        AnalysisReport r = new AnalysisReport();
        r.setUserId(userId);
        return r;
    }

    @Test
    void doctorCannotViewForeignReport() {
        when(reportRepository.findById(5L)).thenReturn(Optional.of(ownedBy(1L)));
        assertThatThrownBy(() -> service.getReportById(5L, 99L, 1, 50))
                .isInstanceOf(NotFoundException.class);
    }

    @Test
    void doctorCannotDeleteForeignReport() {
        when(reportRepository.findById(5L)).thenReturn(Optional.of(ownedBy(1L)));
        assertThatThrownBy(() -> service.deleteReport(5L, 99L))
                .isInstanceOf(NotFoundException.class);
    }

    @Test
    void ownerCanViewOwnReport() {
        when(reportRepository.findById(5L)).thenReturn(Optional.of(ownedBy(1L)));
        assertThat(service.getReportById(5L, 1L, 1, 50)).isNotNull();
    }
}
