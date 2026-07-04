package org.example.service;

import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.example.model.AnalysisNorm;
import org.example.model.AnalysisReport;
import org.example.repository.AnalysisNormRepository;
import org.example.repository.AnalysisReportRepository;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import java.io.ByteArrayOutputStream;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class UploadServiceTest {

    private final AnalysisNormRepository normRepository = mock(AnalysisNormRepository.class);
    private final AnalysisReportRepository reportRepository = mock(AnalysisReportRepository.class);
    private final UploadService service = new UploadService(normRepository, reportRepository);

    @Test
    void normalizeNormNameStripsUnitsAndTrailingParts() {
        assertThat(UploadService.normalizeNormName("ТТГ (мМЕ/л)")).isEqualTo("ТТГ");
        assertThat(UploadService.normalizeNormName("Т4 свободный, пмоль/л")).isEqualTo("Т4 свободный");
        assertThat(UploadService.normalizeNormName("Кальцитонин (пг/мл)")).isEqualTo("Кальцитонин");
        assertThat(UploadService.normalizeNormName(null)).isEmpty();
    }

    @Test
    @SuppressWarnings("unchecked")
    void parsesRowAndFlagsOutOfNorm() throws Exception {
        AnalysisNorm ttg = new AnalysisNorm();
        ttg.setName("ТТГ");
        ttg.setMinValue(0.4);
        ttg.setMaxValue(4.0);
        ttg.setUnit("мМЕ/л");
        when(normRepository.findAll()).thenReturn(List.of(ttg));

        AnalysisReport saved = mock(AnalysisReport.class);
        when(saved.getId()).thenReturn(1L);
        when(reportRepository.save(any())).thenReturn(saved);

        MockMultipartFile file = buildXlsx();
        Map<String, Object> result = service.processUpload(7L, "test.xlsx", file);

        List<Map<String, Object>> report = (List<Map<String, Object>>) result.get("report");
        assertThat(report).hasSize(1);

        Map<String, Object> patient = report.get(0);
        assertThat(patient.get("code")).isEqualTo("P-001");
        assertThat(patient.get("age")).isEqualTo(56);
        assertThat(patient.get("known_recurrence")).isEqualTo(1);

        List<Map<String, Object>> outOfNorms = (List<Map<String, Object>>) patient.get("outOfNorms");
        assertThat(outOfNorms).hasSize(1);
        assertThat(outOfNorms.get(0).get("status")).isEqualTo("выше нормы");
    }

    private MockMultipartFile buildXlsx() throws Exception {
        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Sheet sheet = wb.createSheet();
            Row header = sheet.createRow(0);
            header.createCell(0).setCellValue("Код пациента");
            header.createCell(1).setCellValue("Возраст");
            header.createCell(2).setCellValue("ТТГ (мМЕ/л)");
            header.createCell(3).setCellValue("Послеоперационный рецидив");

            Row row = sheet.createRow(1);
            row.createCell(0).setCellValue("P-001");
            row.createCell(1).setCellValue(56);
            row.createCell(2).setCellValue(5.0);
            row.createCell(3).setCellValue(1);

            wb.write(out);
            return new MockMultipartFile(
                    "file",
                    "test.xlsx",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    out.toByteArray());
        }
    }
}
