package org.example.service;

import org.apache.poi.ss.usermodel.*;
import org.example.model.AnalysisNorm;
import org.example.model.AnalysisReport;
import org.example.repository.AnalysisNormRepository;
import org.example.repository.AnalysisReportRepository;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class UploadService {

    private static final String COL_CODE = "Код пациента";
    private static final String COL_AGE = "Возраст";

    private static final int MAX_ROWS = 5000;

    private static final Map<String, ExtraField> EXTRA_FIELDS = new LinkedHashMap<>();

    static {
        EXTRA_FIELDS.put("Диагноз по TNM. T", new ExtraField("tnm_t_pre", FieldType.STRING));
        EXTRA_FIELDS.put("Диагноз по TNM. N", new ExtraField("tnm_n_pre", FieldType.STRING));
        EXTRA_FIELDS.put("Диагноз по TNM. M", new ExtraField("tnm_m_pre", FieldType.STRING));
        EXTRA_FIELDS.put("Диагноз по TNM после гистологии. T", new ExtraField("tnm_t_post", FieldType.STRING));
        EXTRA_FIELDS.put("Диагноз по TNM после гистологии. N", new ExtraField("tnm_n_post", FieldType.STRING));
        EXTRA_FIELDS.put("Диагноз по TNM после гистологии. M", new ExtraField("tnm_m_post", FieldType.STRING));
        EXTRA_FIELDS.put("Вид операции", new ExtraField("operation_type", FieldType.STRING));
        EXTRA_FIELDS.put("Длительность заболевания (месяц)", new ExtraField("disease_duration_months", FieldType.INT));
        EXTRA_FIELDS.put("Время нахождения в стационаре после операции (дни)", new ExtraField("hospital_stay_days", FieldType.INT));
        EXTRA_FIELDS.put("Сопутствующие заболевания ССС", new ExtraField("comorbidity_cv", FieldType.INT));
        EXTRA_FIELDS.put("Сопутствующие заболевания ЖКТ", new ExtraField("comorbidity_gi", FieldType.INT));
        EXTRA_FIELDS.put("Сопутствующие заболевания ДС", new ExtraField("comorbidity_resp", FieldType.INT));
        EXTRA_FIELDS.put("Интероперационные осложнения", new ExtraField("intraop_complications", FieldType.INT));
        EXTRA_FIELDS.put("Послеоперационный рецидив", new ExtraField("known_recurrence", FieldType.INT));
        EXTRA_FIELDS.put("Цитологическая классификация после ТАБ по  системе Bethesda (диагностическая категория от 1 до 5)",
                new ExtraField("bethesda", FieldType.INT));
        EXTRA_FIELDS.put("Цитологическая классификация после ТАБ по системе Bethesda (диагностическая категория от 1 до 5)",
                new ExtraField("bethesda", FieldType.INT));
    }

    private enum FieldType { STRING, INT }
    private record ExtraField(String sliceKey, FieldType type) {}

    private final AnalysisNormRepository normRepository;
    private final AnalysisReportRepository reportRepository;

    public UploadService(AnalysisNormRepository normRepository,
                         AnalysisReportRepository reportRepository) {
        this.normRepository = normRepository;
        this.reportRepository = reportRepository;
    }

    public Map<String, Object> processUpload(Long userId, String fileName, MultipartFile file) throws IOException {
        Map<String, AnalysisNorm> normsByName = normRepository.findAll().stream()
                .collect(Collectors.toMap(AnalysisNorm::getName, n -> n));

        List<Map<String, Object>> report = new ArrayList<>();
        Workbook wb = WorkbookFactory.create(file.getInputStream());
        try {
            Sheet sheet = wb.getSheetAt(0);
            Row headerRow = sheet.getRow(0);
            if (headerRow == null) {
                throw new IllegalArgumentException("Пустой файл");
            }
            if (sheet.getLastRowNum() > MAX_ROWS) {
                throw new IllegalArgumentException("Слишком много строк в файле: максимум " + MAX_ROWS);
            }
            List<String> headers = new ArrayList<>();
            for (Cell c : headerRow) {
                headers.add(getCellString(c));
            }

            for (int i = 1; i <= sheet.getLastRowNum(); i++) {
                Row row = sheet.getRow(i);
                if (row == null) continue;

                String code = getCellString(row.getCell(indexOf(headers, COL_CODE)));
                String ageStr = getCellString(row.getCell(indexOf(headers, COL_AGE)));
                if (code == null || code.trim().isEmpty() || ageStr == null || ageStr.trim().isEmpty()) continue;

                int age;
                try {
                    age = (int) Double.parseDouble(ageStr.trim().replace(",", "."));
                } catch (NumberFormatException e) {
                    continue;
                }

                Map<String, Object> patientReport = new LinkedHashMap<>();
                patientReport.put("code", code.trim());
                patientReport.put("age", age);

                for (int j = 0; j < headers.size(); j++) {
                    String colName = headers.get(j);
                    if (colName == null) continue;
                    ExtraField ef = EXTRA_FIELDS.get(colName);
                    if (ef == null) continue;
                    Cell cell = row.getCell(j);
                    if (ef.type() == FieldType.STRING) {
                        String s = getCellString(cell);
                        if (s != null && !s.trim().isEmpty()) {
                            patientReport.put(ef.sliceKey(), s.trim());
                        }
                    } else {
                        Double v = getCellNumeric(cell);
                        if (v != null) {
                            patientReport.put(ef.sliceKey(), (int) Math.round(v));
                        }
                    }
                }

                List<Object> outOfNorms = new ArrayList<>();
                List<Map<String, Object>> measurements = new ArrayList<>();

                for (int j = 0; j < headers.size(); j++) {
                    String colName = headers.get(j);
                    if (colName == null) continue;
                    if (COL_CODE.equals(colName) || COL_AGE.equals(colName)) continue;
                    if (EXTRA_FIELDS.containsKey(colName)) continue;
                    AnalysisNorm norm = normsByName.get(normalizeNormName(colName));
                    if (norm == null) continue;

                    Cell cell = row.getCell(j);
                    Double value = getCellNumeric(cell);
                    if (value == null) continue;

                    double minV = norm.getMinValue();
                    double maxV = norm.getMaxValue();
                    double range = maxV - minV;
                    if (range <= 1e-9) {
                        range = 1.0;
                    }
                    double normalizedDeviation;
                    if (value < minV) {
                        normalizedDeviation = (minV - value) / range;
                    } else if (value > maxV) {
                        normalizedDeviation = (value - maxV) / range;
                    } else {
                        normalizedDeviation = 0.0;
                    }

                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("analysis", colName);
                    m.put("value", value);
                    m.put("min", minV);
                    m.put("max", maxV);
                    m.put("unit", norm.getUnit());
                    m.put("normalizedDeviation", normalizedDeviation);
                    measurements.add(m);

                    if (value < minV || value > maxV) {
                        Map<String, Object> item = new LinkedHashMap<>();
                        item.put("analysis", colName);
                        item.put("value", value);
                        item.put("min", minV);
                        item.put("max", maxV);
                        item.put("unit", norm.getUnit());
                        item.put("status", value < minV ? "ниже нормы" : "выше нормы");
                        outOfNorms.add(item);
                    }
                }
                patientReport.put("measurements", measurements);
                patientReport.put("outOfNorms", outOfNorms.isEmpty() ? List.of("Все значения в норме") : outOfNorms);
                report.add(patientReport);
            }

            AnalysisReport analysisReport = new AnalysisReport();
            analysisReport.setUserId(userId);
            analysisReport.setFileName(fileName);
            analysisReport.setReportData(report);
            analysisReport.setCreatedAt(Instant.now());
            AnalysisReport saved = reportRepository.save(analysisReport);
            return Map.of("reportId", saved.getId(), "report", report);
        } finally {
            wb.close();
        }
    }

    private static int indexOf(List<String> list, String s) {
        for (int i = 0; i < list.size(); i++) {
            if (s.equals(list.get(i))) return i;
        }
        return -1;
    }

    static String normalizeNormName(String columnName) {
        if (columnName == null) return "";
        return columnName
                .replaceAll("\\s*\\(.*?\\)\\s*", "")
                .replaceAll("\\s*,.*", "")
                .trim();
    }

    private static String getCellString(Cell cell) {
        if (cell == null) return null;
        return switch (cell.getCellType()) {
            case STRING -> cell.getStringCellValue();
            case NUMERIC -> String.valueOf((long) cell.getNumericCellValue());
            case BOOLEAN -> String.valueOf(cell.getBooleanCellValue());
            default -> null;
        };
    }

    private static Double getCellNumeric(Cell cell) {
        if (cell == null) return null;
        try {
            if (cell.getCellType() == CellType.NUMERIC) {
                return cell.getNumericCellValue();
            }
            if (cell.getCellType() == CellType.STRING) {
                String s = cell.getStringCellValue().trim().replace(",", ".");
                if (s.isEmpty()) return null;
                return Double.parseDouble(s);
            }
        } catch (NumberFormatException ignored) {}
        return null;
    }
}
