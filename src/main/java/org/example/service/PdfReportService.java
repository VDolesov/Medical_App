package org.example.service;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.PDFont;
import org.apache.pdfbox.pdmodel.font.PDType0Font;
import org.example.model.AnalysisReport;
import org.example.model.ClinicalRule;
import org.example.model.ClinicalSource;
import org.example.model.Patient;
import org.example.model.ReportPatient;
import org.example.model.RuleExecution;
import org.example.repository.AnalysisReportRepository;
import org.example.repository.ClinicalRuleRepository;
import org.example.repository.ClinicalSourceRepository;
import org.example.repository.PatientRepository;
import org.example.repository.ReportPatientRepository;
import org.example.repository.RuleExecutionRepository;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;

@Service
public class PdfReportService {

    private static final String FONT_REGULAR = "/fonts/NotoSans-Regular.ttf";
    private static final String FONT_BOLD = "/fonts/NotoSans-Bold.ttf";

    private static final List<String> SYSTEM_FONT_DIRS = List.of(
            "/usr/share/fonts/dejavu",
            "/usr/share/fonts/TTF",
            "/usr/share/fonts/truetype/dejavu");

    private static final float MARGIN = 40f;
    private static final float LINE = 14f;
    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter
            .ofPattern("dd.MM.yyyy HH:mm").withZone(ZoneId.systemDefault());

    private final AnalysisReportRepository reportRepository;
    private final ReportPatientRepository reportPatientRepository;
    private final PatientRepository patientRepository;
    private final RuleExecutionRepository ruleExecutionRepository;
    private final ClinicalRuleRepository clinicalRuleRepository;
    private final ClinicalSourceRepository clinicalSourceRepository;

    public PdfReportService(AnalysisReportRepository reportRepository,
                            ReportPatientRepository reportPatientRepository,
                            PatientRepository patientRepository,
                            RuleExecutionRepository ruleExecutionRepository,
                            ClinicalRuleRepository clinicalRuleRepository,
                            ClinicalSourceRepository clinicalSourceRepository) {
        this.reportRepository = reportRepository;
        this.reportPatientRepository = reportPatientRepository;
        this.patientRepository = patientRepository;
        this.ruleExecutionRepository = ruleExecutionRepository;
        this.clinicalRuleRepository = clinicalRuleRepository;
        this.clinicalSourceRepository = clinicalSourceRepository;
    }

    public byte[] buildPatientReport(Long reportPatientId, boolean asPatient) throws IOException {
        ReportPatient rp = reportPatientRepository.findById(reportPatientId)
                .orElseThrow(() -> new IllegalArgumentException("ReportPatient not found"));
        AnalysisReport report = reportRepository.findById(rp.getReportId())
                .orElseThrow(() -> new IllegalArgumentException("Report not found"));
        Patient patient = patientRepository.findById(rp.getPatientId()).orElse(null);

        Map<String, Object> slice = sliceFor(report.getReportData(), rp.getSortOrder());

        List<RuleExecution> executions = ruleExecutionRepository
                .findByReportPatientIdAndTriggeredTrueOrderByCreatedAtDesc(reportPatientId);

        Map<Long, ClinicalRule> rulesById = new HashMap<>();
        for (ClinicalRule r : clinicalRuleRepository.findAll()) {
            rulesById.put(r.getId(), r);
        }
        Map<Long, ClinicalSource> sourcesById = new HashMap<>();
        for (ClinicalSource s : clinicalSourceRepository.findAll()) {
            sourcesById.put(s.getId(), s);
        }

        try (PDDocument doc = new PDDocument(); ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
            PDFont fontRegular = loadFont(doc, FONT_REGULAR);
            PDFont fontBold = loadFont(doc, FONT_BOLD);

            PDPage page = new PDPage(PDRectangle.A4);
            doc.addPage(page);
            try (PDPageContentStream cs = new PDPageContentStream(doc, page)) {
                Cursor cur = new Cursor(page.getMediaBox().getHeight() - MARGIN);

                writeTitle(cs, fontBold, asPatient
                        ? "Отчёт по лабораторным исследованиям (для пациента)"
                        : "Отчёт по лабораторным исследованиям (для врача)", cur);
                writeLine(cs, fontRegular, "Сгенерировано: " + DATE_FMT.format(java.time.Instant.now()), cur, 10);
                cur.y -= 6;

                writeSectionHeader(cs, fontBold, "Пациент", cur);
                writeLine(cs, fontRegular,
                        "Код: " + (patient == null ? "—" : safe(patient.getCode())), cur, 11);
                writeLine(cs, fontRegular,
                        "Возраст: " + (patient == null || patient.getAge() == null ? "—" : patient.getAge().toString()), cur, 11);
                if (patient != null && patient.getGender() != null) {
                    writeLine(cs, fontRegular, "Пол: " + patient.getGender(), cur, 11);
                }
                writeLine(cs, fontRegular,
                        "Отчёт: №" + report.getId() + " (" + DATE_FMT.format(report.getCreatedAt()) + ")", cur, 11);
                cur.y -= 6;

                writeSectionHeader(cs, fontBold, "Клинический контекст", cur);
                writeKV(cs, fontRegular, "TNM (по гистологии)",
                        joinTnm(slice, "tnm_t_post", "tnm_n_post", "tnm_m_post"), cur);
                writeKV(cs, fontRegular, "TNM (до операции)",
                        joinTnm(slice, "tnm_t_pre", "tnm_n_pre", "tnm_m_pre"), cur);
                writeKV(cs, fontRegular, "Bethesda (ТАБ)", asString(slice.get("bethesda")), cur);
                writeKV(cs, fontRegular, "Вид операции", asString(slice.get("operation_type")), cur);
                writeKV(cs, fontRegular, "Длительность заболевания (мес)", asString(slice.get("disease_duration_months")), cur);
                writeKV(cs, fontRegular, "Дни в стационаре", asString(slice.get("hospital_stay_days")), cur);
                cur.y -= 6;

                writeSectionHeader(cs, fontBold, "Лабораторные показатели", cur);
                Object meas = slice.get("measurements");
                if (meas instanceof List<?> list) {
                    writeMeasurementsTable(cs, fontRegular, fontBold, list, cur);
                }
                cur.y -= 10;

                writeSectionHeader(cs, fontBold, "Экспертная система — выводы", cur);
                if (executions.isEmpty()) {
                    writeLine(cs, fontRegular,
                            "Ни одно правило не сработало: показатели в пределах нормы относительно загруженных данных.",
                            cur, 11);
                } else {
                    String overall = executions.stream()
                            .map(RuleExecution::getSeverity)
                            .reduce("INFO", PdfReportService::maxSeverity);
                    writeLine(cs, fontBold, "Сводный статус: " + severityRu(overall), cur, 11);
                    cur.y -= 4;
                    for (RuleExecution e : executions) {
                        ClinicalRule rule = rulesById.get(e.getRuleId());
                        ClinicalSource src = (rule != null && rule.getSourceId() != null)
                                ? sourcesById.get(rule.getSourceId()) : null;
                        cur = writeRuleBlock(cs, fontRegular, fontBold, e, rule, src, asPatient, cur, page, doc);
                    }
                }
                cur.y -= 8;

                writeDisclaimer(cs, fontRegular, cur);
            }

            doc.save(baos);
            return baos.toByteArray();
        }
    }

    private PDFont loadFont(PDDocument doc, String classpath) throws IOException {
        ClassPathResource res = new ClassPathResource(classpath);
        if (res.exists()) {
            try (InputStream is = res.getInputStream()) {
                return PDType0Font.load(doc, is, true);
            }
        }
        boolean bold = classpath.toLowerCase(Locale.ROOT).contains("bold");
        String filename = bold ? "DejaVuSans-Bold.ttf" : "DejaVuSans.ttf";
        for (String dir : SYSTEM_FONT_DIRS) {
            File f = new File(dir, filename);
            if (f.isFile()) {
                try (InputStream is = new FileInputStream(f)) {
                    return PDType0Font.load(doc, is, true);
                }
            }
        }
        throw new IOException("TTF-шрифт с поддержкой кириллицы не найден ни в classpath (" + classpath +
                "), ни в системных каталогах. В Docker-образе ставится через `apk add ttf-dejavu`, " +
                "либо положите NotoSans в src/main/resources/fonts/.");
    }

    private void writeTitle(PDPageContentStream cs, PDFont font, String text, Cursor cur) throws IOException {
        cs.beginText();
        cs.setFont(font, 16);
        cs.newLineAtOffset(MARGIN, cur.y);
        cs.showText(text);
        cs.endText();
        cur.y -= 22;
    }

    private void writeSectionHeader(PDPageContentStream cs, PDFont font, String text, Cursor cur) throws IOException {
        cs.beginText();
        cs.setFont(font, 12);
        cs.newLineAtOffset(MARGIN, cur.y);
        cs.showText(text);
        cs.endText();
        cur.y -= LINE;
    }

    private void writeLine(PDPageContentStream cs, PDFont font, String text, Cursor cur, int size) throws IOException {
        cs.beginText();
        cs.setFont(font, size);
        cs.newLineAtOffset(MARGIN, cur.y);
        cs.showText(text == null ? "" : text);
        cs.endText();
        cur.y -= (size + 4);
    }

    private void writeKV(PDPageContentStream cs, PDFont font, String key, String value, Cursor cur) throws IOException {
        writeLine(cs, font, key + ": " + (value == null || value.isEmpty() ? "—" : value), cur, 11);
    }

    private void writeMeasurementsTable(PDPageContentStream cs, PDFont fr, PDFont fb,
                                        List<?> measurements, Cursor cur) throws IOException {
        cs.beginText();
        cs.setFont(fb, 10);
        cs.newLineAtOffset(MARGIN, cur.y);
        cs.showText(String.format(Locale.ROOT, "%-40s %-12s %-12s %s",
                "Показатель", "Значение", "Норма", "Статус"));
        cs.endText();
        cur.y -= LINE;
        for (Object m : measurements) {
            if (!(m instanceof Map<?, ?> map)) continue;
            String name = String.valueOf(map.get("analysis"));
            String value = String.valueOf(map.get("value"));
            String min = String.valueOf(map.get("min"));
            String max = String.valueOf(map.get("max"));
            Object unitObj = map.get("unit");
            String unit = unitObj == null ? "" : String.valueOf(unitObj);
            double v = parseDouble(map.get("value"));
            double lo = parseDouble(map.get("min"));
            double hi = parseDouble(map.get("max"));
            String status = "норма";
            if (!Double.isNaN(v) && !Double.isNaN(lo) && !Double.isNaN(hi)) {
                if (v < lo) status = "↓ ниже";
                else if (v > hi) status = "↑ выше";
            }
            String nameTrim = name.length() > 38 ? name.substring(0, 37) + "…" : name;
            String row = String.format(Locale.ROOT, "%-40s %-12s %-12s %s",
                    nameTrim,
                    value + " " + unit,
                    min + "–" + max,
                    status);
            cs.beginText();
            cs.setFont(fr, 10);
            cs.newLineAtOffset(MARGIN, cur.y);
            cs.showText(row);
            cs.endText();
            cur.y -= LINE;
        }
    }

    private Cursor writeRuleBlock(PDPageContentStream cs, PDFont fr, PDFont fb,
                                  RuleExecution exec, ClinicalRule rule, ClinicalSource src,
                                  boolean asPatient, Cursor cur, PDPage page, PDDocument doc) throws IOException {
        if (cur.y < MARGIN + 80) {
            cs.close();
            PDPage np = new PDPage(PDRectangle.A4);
            doc.addPage(np);
            PDPageContentStream ns = new PDPageContentStream(doc, np);
            Cursor newCur = new Cursor(np.getMediaBox().getHeight() - MARGIN);

            return writeRuleBlock(ns, fr, fb, exec, rule, src, asPatient, newCur, np, doc);
        }
        String title = (rule != null ? rule.getTitle() : exec.getRuleCode());
        writeLine(cs, fb, "• " + exec.getRuleCode() + ". " + title +
                " [" + severityRu(exec.getSeverity()) + "]", cur, 11);
        String explanation = asPatient ? exec.getPatientExplanationText() : exec.getExplanationText();
        if (explanation != null && !explanation.isBlank()) {
            for (String line : wrap(explanation, 95)) {
                writeLine(cs, fr, "  " + line, cur, 10);
            }
        }
        if (!asPatient && src != null) {
            String sourceLine = "Источник: " + src.getCode();
            if (rule != null && rule.getSourceSection() != null) {
                sourceLine += " — " + rule.getSourceSection();
            }
            writeLine(cs, fr, "  " + sourceLine, cur, 9);
        }
        cur.y -= 4;
        return cur;
    }

    private void writeDisclaimer(PDPageContentStream cs, PDFont font, Cursor cur) throws IOException {
        for (String line : wrap(
                "Важно: отчёт сформирован автоматически и носит справочный, рекомендательный характер. " +
                        "Он не является диагнозом, назначением лечения или заменой очной консультации врача. " +
                        "Пациенту не следует самостоятельно менять терапию по этому отчёту; при вопросах нужно обратиться к лечащему врачу.",
                105)) {
            writeLine(cs, font, line, cur, 9);
        }
    }

    private static Map<String, Object> sliceFor(List<Map<String, Object>> rows, int sortOrder) {
        if (rows == null || sortOrder < 0 || sortOrder >= rows.size() || rows.get(sortOrder) == null) {
            return Map.of();
        }
        return rows.get(sortOrder);
    }

    private static String joinTnm(Map<String, Object> slice, String t, String n, String m) {
        String tv = asString(slice.get(t));
        String nv = asString(slice.get(n));
        String mv = asString(slice.get(m));
        if (tv.isEmpty() && nv.isEmpty() && mv.isEmpty()) return "";
        return (tv.isEmpty() ? "?" : tv) + " " + (nv.isEmpty() ? "?" : nv) + " " + (mv.isEmpty() ? "?" : mv);
    }

    private static String asString(Object o) {
        return o == null ? "" : Objects.toString(o, "");
    }

    private static double parseDouble(Object o) {
        if (o == null) return Double.NaN;
        if (o instanceof Number n) return n.doubleValue();
        try {
            return Double.parseDouble(String.valueOf(o));
        } catch (NumberFormatException e) {
            return Double.NaN;
        }
    }

    private static String safe(String s) {
        return s == null ? "" : s;
    }

    private static String severityRu(String s) {
        if (s == null) return "";
        return switch (s) {
            case "CRITICAL" -> "Требует внимания";
            case "WARNING" -> "Проверить";
            case "INFO" -> "Справочно";
            default -> s;
        };
    }

    private static String maxSeverity(String a, String b) {
        int wa = weight(a);
        int wb = weight(b);
        return wa >= wb ? a : b;
    }

    private static int weight(String s) {
        return switch (s == null ? "" : s) {
            case "CRITICAL" -> 3;
            case "WARNING" -> 2;
            case "INFO" -> 1;
            default -> 0;
        };
    }

    private static List<String> wrap(String text, int width) {
        java.util.ArrayList<String> out = new java.util.ArrayList<>();
        if (text == null) return out;
        String[] words = text.split("\\s+");
        StringBuilder cur = new StringBuilder();
        for (String w : words) {
            if (cur.length() + w.length() + 1 > width) {
                out.add(cur.toString());
                cur.setLength(0);
            }
            if (cur.length() > 0) cur.append(' ');
            cur.append(w);
        }
        if (cur.length() > 0) out.add(cur.toString());
        return out;
    }

    private static final class Cursor {
        float y;
        Cursor(float y) { this.y = y; }
    }
}
