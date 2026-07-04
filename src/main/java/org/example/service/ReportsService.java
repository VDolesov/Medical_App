package org.example.service;

import org.example.exception.NotFoundException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.example.model.AnalysisReport;
import org.example.repository.AnalysisReportRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class ReportsService {

    private final AnalysisReportRepository reportRepository;
    private final ObjectMapper objectMapper;
    private final ReportPatientAttachmentService reportPatientAttachmentService;

    public ReportsService(AnalysisReportRepository reportRepository,
                          ObjectMapper objectMapper,
                          ReportPatientAttachmentService reportPatientAttachmentService) {
        this.reportRepository = reportRepository;
        this.objectMapper = objectMapper;
        this.reportPatientAttachmentService = reportPatientAttachmentService;
    }

    public List<ReportMetaDto> getReportsByUser(Long userId) {
        return reportRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(ReportMetaDto::from)
                .toList();
    }

    public ReportViewDto getReportById(Long reportId, Long userId, int page, int limit) {
        AnalysisReport r = reportRepository.findById(reportId).orElseThrow(() -> new NotFoundException());
        if (!r.getUserId().equals(userId)) {
            throw new NotFoundException();
        }
        ReportViewDto dto = ReportViewDto.from(r, page, limit, objectMapper);
        reportPatientAttachmentService.enrichReportView(dto, reportId, userId, false);
        return dto;
    }

    public void deleteReport(Long reportId, Long userId) {
        AnalysisReport r = reportRepository.findById(reportId).orElseThrow(() -> new NotFoundException());
        if (!r.getUserId().equals(userId)) {
            throw new NotFoundException();
        }
        List<Long> patientIds = reportPatientAttachmentService.patientIdsOfReport(reportId);
        reportRepository.delete(r);

reportPatientAttachmentService.releaseOrphanPatients(patientIds);
    }

    public static class ReportMetaDto {
        public Long id;
        public String file_name;
        public String created_at;

        public static ReportMetaDto from(AnalysisReport r) {
            ReportMetaDto dto = new ReportMetaDto();
            dto.id = r.getId();
            dto.file_name = r.getFileName();
            dto.created_at = r.getCreatedAt().toString();
            return dto;
        }
    }

    public static class ReportViewDto {
        public long total;
        public int page;
        public int limit;
        public List<Map<String, Object>> patients;
        public List<Map<String, Object>> report;

        public static ReportViewDto from(AnalysisReport r, int page, int limit, ObjectMapper om) {
            ReportViewDto dto = new ReportViewDto();
            int safePage = Math.max(1, page);
            int safeLimit = Math.min(500, Math.max(1, limit));
            List<Map<String, Object>> all = r.getReportData();
            if (all == null) all = List.of();
            dto.total = all.size();
            dto.page = safePage;
            dto.limit = safeLimit;
            int offset = (safePage - 1) * safeLimit;
            dto.patients = all.stream().skip(offset).limit(safeLimit).toList();
            dto.report = dto.patients;
            return dto;
        }
    }
}
