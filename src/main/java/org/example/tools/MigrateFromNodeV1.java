package org.example.tools;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.example.config.DatabaseUrl;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Перенос данных из базы Node.js-версии (v1, схема db/init.sql в ветке node-v1)
 * в схему Java-версии, которую создаёт Liquibase при первом старте приложения.
 *
 * <pre>
 *   MIGRATE_SRC_URL=postgres://user:pass@host/node_db   (база Node-прода)
 *   MIGRATE_DST_URL=postgres://user:pass@host/java_db   (новая база Java, уже с миграциями)
 *   MIGRATE_DRY_RUN=true                                 (по желанию: прогон без коммита)
 *
 *   java -cp target/medical-app-0.0.1-SNAPSHOT.jar \
 *        -Dloader.main=org.example.tools.MigrateFromNodeV1 \
 *        org.springframework.boot.loader.launch.PropertiesLauncher
 * </pre>
 *
 * Что переносится и как:
 * <ul>
 *   <li>users — с теми же id и bcrypt-хешами (пароли остаются), роль в верхнем регистре;</li>
 *   <li>analysis_norms — только те, которых нет в Java-справочнике (по названию);</li>
 *   <li>patients — с теми же id; недостающие создаются по кодам из отчётов;</li>
 *   <li>analysis_reports — с теми же id; в каждую строку добавляется массив measurements,
 *       восстановленный из analysis_results (Node хранил значения отдельно, а Java считает
 *       индекс отклонений именно по measurements);</li>
 *   <li>report_patients — привязка каждой строки отчёта к пациенту по коду; лечащим врачом
 *       пациента становится врач, загрузивший первый отчёт с ним.</li>
 * </ul>
 * Аналитика (patient_ai_analytics) и выводы экспертной системы не переносятся —
 * их пересчитывает Java по кнопке «Сформировать аналитику» или запросом
 * POST /analytics/report/{id}/generate.
 *
 * Целевая база должна быть пустой (без пользователей, отчётов и пациентов),
 * иначе id не совпадут — инструмент откажется работать.
 */
public final class MigrateFromNodeV1 {

    /** Результаты Node пишутся в одной транзакции с отчётом (одинаковый NOW()), но на всякий случай — окно. */
    private static final long MATCH_WINDOW_MS = 2 * 60 * 1000L;

    private static final ObjectMapper JSON = new ObjectMapper();

    private record Norm(long id, String name, double min, double max, String unit) {}
    private record Result(long normId, double value, long timeMs) {}

    private MigrateFromNodeV1() {}

    public static void main(String[] args) throws Exception {
        Connection src = connect("MIGRATE_SRC");
        Connection dst = connect("MIGRATE_DST");
        boolean dryRun = "true".equalsIgnoreCase(env("MIGRATE_DRY_RUN", "false"));
        System.out.println("=== Миграция Node v1 -> Java ===");
        System.out.println("источник: " + src.getMetaData().getURL());
        System.out.println("цель:     " + dst.getMetaData().getURL() + (dryRun ? "  (DRY RUN — без коммита)" : ""));
        System.out.println();

        dst.setAutoCommit(false);
        try {
            assertEmpty(dst, "users", "analysis_reports", "patients", "report_patients");

            Map<String, Norm> dstNormsByName = loadNorms(dst);
            Map<Long, Norm> srcNormsById = new HashMap<>();
            for (Norm n : loadNorms(src).values()) {
                srcNormsById.put(n.id(), n);
            }
            int normsAdded = migrateNorms(srcNormsById.values(), dstNormsByName, dst);

            Map<Long, String> userRoles = migrateUsers(src, dst);

            Map<String, Long> patientIdByCode = migratePatients(src, dst);
            // пациенты вставлены с явными id — сдвигаем sequence до того, как создавать новых по кодам из отчётов
            bumpSequences(dst, "patients");
            Map<Long, List<Result>> resultsByPatient = loadResults(src);

            int[] reportStats = migrateReports(src, dst, srcNormsById, patientIdByCode, resultsByPatient, userRoles);

            bumpSequences(dst, "users", "patients", "analysis_reports", "report_patients", "analysis_norms");

            System.out.println();
            System.out.println("нормы добавлено:       " + normsAdded);
            System.out.println("пользователей:         " + userRoles.size());
            System.out.println("пациентов:             " + patientIdByCode.size());
            System.out.println("отчётов:               " + reportStats[0]);
            System.out.println("строк отчётов:         " + reportStats[1]);
            System.out.println("строк без измерений:   " + reportStats[2] + (reportStats[2] > 0 ? "  (не нашлось analysis_results рядом по времени)" : ""));
            System.out.println("привязок к пациентам:  " + reportStats[3]);

            if (dryRun) {
                dst.rollback();
                System.out.println("\nDRY RUN: изменения откачены.");
            } else {
                dst.commit();
                System.out.println("\nГотово. Не забудьте пересчитать аналитику по отчётам (POST /analytics/report/{id}/generate).");
            }
        } catch (Exception e) {
            dst.rollback();
            System.err.println("\nОШИБКА, изменения откачены: " + e.getMessage());
            throw e;
        } finally {
            src.close();
            dst.close();
        }
    }

    // ---------- шаги ----------

    private static void assertEmpty(Connection dst, String... tables) throws SQLException {
        for (String t : tables) {
            try (Statement st = dst.createStatement(); ResultSet rs = st.executeQuery("SELECT count(*) FROM " + t)) {
                rs.next();
                if (rs.getLong(1) > 0) {
                    throw new IllegalStateException("Целевая таблица " + t + " не пуста (" + rs.getLong(1)
                            + " строк). Миграция рассчитана на только что созданную базу.");
                }
            }
        }
    }

    private static Map<String, Norm> loadNorms(Connection c) throws SQLException {
        Map<String, Norm> out = new LinkedHashMap<>();
        try (Statement st = c.createStatement();
             ResultSet rs = st.executeQuery("SELECT id, name, min_value, max_value, unit FROM analysis_norms ORDER BY id")) {
            while (rs.next()) {
                Norm n = new Norm(rs.getLong(1), rs.getString(2), rs.getDouble(3), rs.getDouble(4), rs.getString(5));
                out.put(n.name(), n);
            }
        }
        return out;
    }

    private static int migrateNorms(Iterable<Norm> srcNorms, Map<String, Norm> dstByName, Connection dst) throws SQLException {
        int added = 0;
        String sql = "INSERT INTO analysis_norms (name, min_value, max_value, unit) VALUES (?, ?, ?, ?) RETURNING id";
        try (PreparedStatement ps = dst.prepareStatement(sql)) {
            for (Norm n : srcNorms) {
                Norm existing = dstByName.get(n.name());
                if (existing != null) {
                    if (existing.min() != n.min() || existing.max() != n.max() || !existing.unit().equals(n.unit())) {
                        System.out.printf(Locale.ROOT, "  норма «%s»: в Node %.3f–%.3f %s, в Java %.3f–%.3f %s — оставляю значения Java%n",
                                n.name(), n.min(), n.max(), n.unit(), existing.min(), existing.max(), existing.unit());
                    }
                    continue;
                }
                ps.setString(1, n.name());
                ps.setDouble(2, n.min());
                ps.setDouble(3, n.max());
                ps.setString(4, n.unit());
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    dstByName.put(n.name(), new Norm(rs.getLong(1), n.name(), n.min(), n.max(), n.unit()));
                }
                System.out.println("  добавлена норма из Node: " + n.name());
                added++;
            }
        }
        return added;
    }

    /** @return id -> роль (в верхнем регистре), для определения лечащего врача */
    private static Map<Long, String> migrateUsers(Connection src, Connection dst) throws SQLException {
        Map<Long, String> roles = new HashMap<>();
        String sql = "INSERT INTO users (id, username, password_hash, email, first_name, last_name, role, patient_id) VALUES (?, ?, ?, ?, ?, ?, ?, NULL)";
        try (Statement st = src.createStatement();
             ResultSet rs = st.executeQuery("SELECT id, username, password_hash, email, first_name, last_name, role FROM users ORDER BY id");
             PreparedStatement ps = dst.prepareStatement(sql)) {
            while (rs.next()) {
                String role = rs.getString(7) == null ? "" : rs.getString(7).trim().toUpperCase(Locale.ROOT);
                if (!role.equals("DOCTOR") && !role.equals("ADMIN")) {
                    System.out.println("  пропускаю пользователя " + rs.getString(2) + ": роль «" + rs.getString(7) + "» не переносится");
                    continue;
                }
                ps.setLong(1, rs.getLong(1));
                ps.setString(2, rs.getString(2));
                ps.setString(3, rs.getString(3));
                ps.setString(4, rs.getString(4));
                ps.setString(5, rs.getString(5));
                ps.setString(6, rs.getString(6));
                ps.setString(7, role);
                ps.executeUpdate();
                roles.put(rs.getLong(1), role);
            }
        }
        return roles;
    }

    /** @return код пациента -> id в целевой базе (id сохраняются) */
    private static Map<String, Long> migratePatients(Connection src, Connection dst) throws SQLException {
        Map<String, Long> ids = new HashMap<>();
        String sql = "INSERT INTO patients (id, code, age, gender, created_at, updated_at) VALUES (?, ?, ?, ?, now(), now())";
        try (Statement st = src.createStatement();
             ResultSet rs = st.executeQuery("SELECT id, code, age, sex FROM patients ORDER BY id");
             PreparedStatement ps = dst.prepareStatement(sql)) {
            while (rs.next()) {
                int age = rs.getInt(3);
                ps.setLong(1, rs.getLong(1));
                ps.setString(2, rs.getString(2).trim());
                ps.setInt(3, rs.wasNull() ? 0 : age);
                ps.setString(4, rs.getString(4));
                ps.executeUpdate();
                ids.put(rs.getString(2).trim(), rs.getLong(1));
            }
        }
        return ids;
    }

    private static Map<Long, List<Result>> loadResults(Connection src) throws SQLException {
        Map<Long, List<Result>> out = new HashMap<>();
        try (Statement st = src.createStatement();
             ResultSet rs = st.executeQuery("SELECT patient_id, norm_id, value, date FROM analysis_results ORDER BY id")) {
            while (rs.next()) {
                Timestamp ts = rs.getTimestamp(4);
                out.computeIfAbsent(rs.getLong(1), k -> new ArrayList<>())
                        .add(new Result(rs.getLong(2), rs.getDouble(3), ts == null ? Long.MIN_VALUE : ts.getTime()));
            }
        }
        return out;
    }

    /** @return {отчётов, строк, строк без измерений, привязок} */
    private static int[] migrateReports(Connection src, Connection dst, Map<Long, Norm> srcNorms,
                                        Map<String, Long> patientIdByCode, Map<Long, List<Result>> resultsByPatient,
                                        Map<Long, String> userRoles) throws Exception {
        int reports = 0, rows = 0, rowsWithoutMeasurements = 0, linksTotal = 0;
        Map<Long, Long> attendingDoctor = new HashMap<>(); // patient id -> doctor user id (назначено в этом прогоне)

        String insertReport = "INSERT INTO analysis_reports (id, user_id, file_name, report_data, created_at) VALUES (?, ?, ?, ?::jsonb, ?)";
        String insertPatient = "INSERT INTO patients (code, age, created_at, updated_at) VALUES (?, ?, now(), now()) RETURNING id";
        String insertLink = "INSERT INTO report_patients (report_id, patient_id, sort_order) VALUES (?, ?, ?)";
        String setDoctor = "UPDATE patients SET attending_doctor_user_id = ?, updated_at = now() WHERE id = ? AND attending_doctor_user_id IS NULL";

        try (Statement st = src.createStatement();
             ResultSet rs = st.executeQuery("SELECT id, user_id, file_name, report_data::text, created_at FROM analysis_reports ORDER BY id");
             PreparedStatement psReport = dst.prepareStatement(insertReport);
             PreparedStatement psPatient = dst.prepareStatement(insertPatient);
             PreparedStatement psLink = dst.prepareStatement(insertLink);
             PreparedStatement psDoctor = dst.prepareStatement(setDoctor)) {
            while (rs.next()) {
                long reportId = rs.getLong(1);
                long userId = rs.getLong(2);
                if (!userRoles.containsKey(userId)) {
                    System.out.println("  пропускаю отчёт " + reportId + ": владелец " + userId + " не перенесён");
                    continue;
                }
                String fileName = rs.getString(3);
                Timestamp createdAt = rs.getTimestamp(5);
                long createdMs = createdAt == null ? Long.MIN_VALUE : createdAt.getTime();
                String rawJson = rs.getString(4);
                List<Map<String, Object>> data = rawJson == null ? new ArrayList<>()
                        : JSON.readValue(rawJson, new TypeReference<List<Map<String, Object>>>() {});

                Set<Long> linkedInThisReport = new HashSet<>();
                List<long[]> links = new ArrayList<>(); // {patientId, sortOrder} — вставляем после самого отчёта (FK)
                for (int i = 0; i < data.size(); i++) {
                    Map<String, Object> row = data.get(i);
                    Object codeObj = row.get("code");
                    String code = codeObj == null ? "" : String.valueOf(codeObj).trim();
                    rows++;
                    if (code.isEmpty()) {
                        row.putIfAbsent("measurements", new ArrayList<>());
                        rowsWithoutMeasurements++;
                        continue;
                    }
                    Long patientId = patientIdByCode.get(code);
                    if (patientId == null) {
                        psPatient.setString(1, code);
                        psPatient.setInt(2, ageOf(row));
                        try (ResultSet created = psPatient.executeQuery()) {
                            created.next();
                            patientId = created.getLong(1);
                        }
                        patientIdByCode.put(code, patientId);
                    }

                    List<Map<String, Object>> measurements = rebuildMeasurements(
                            resultsByPatient.getOrDefault(srcPatientId(src, code), List.of()), createdMs, srcNorms);
                    if (measurements.isEmpty()) {
                        rowsWithoutMeasurements++;
                    }
                    row.put("measurements", measurements);

                    if (linkedInThisReport.add(patientId)) {
                        links.add(new long[]{patientId, i});
                    }
                }

                psReport.setLong(1, reportId);
                psReport.setLong(2, userId);
                psReport.setString(3, fileName == null || fileName.isBlank() ? "report.xlsx" : fileName);
                psReport.setString(4, JSON.writeValueAsString(data));
                psReport.setTimestamp(5, createdAt == null ? new Timestamp(System.currentTimeMillis()) : createdAt);
                psReport.executeUpdate();
                reports++;

                for (long[] link : links) {
                    long patientId = link[0];
                    psLink.setLong(1, reportId);
                    psLink.setLong(2, patientId);
                    psLink.setInt(3, (int) link[1]);
                    psLink.executeUpdate();
                    linksTotal++;
                    if ("DOCTOR".equals(userRoles.get(userId)) && !attendingDoctor.containsKey(patientId)) {
                        psDoctor.setLong(1, userId);
                        psDoctor.setLong(2, patientId);
                        if (psDoctor.executeUpdate() > 0) {
                            attendingDoctor.put(patientId, userId);
                        }
                    }
                }
            }
        }
        return new int[]{reports, rows, rowsWithoutMeasurements, linksTotal};
    }

    // ---------- вспомогательное ----------

    private static final Map<String, Long> SRC_PATIENT_ID_CACHE = new HashMap<>();

    /** id пациента в базе Node по коду (для поиска его analysis_results). */
    private static Long srcPatientId(Connection src, String code) throws SQLException {
        if (SRC_PATIENT_ID_CACHE.isEmpty()) {
            try (Statement st = src.createStatement(); ResultSet rs = st.executeQuery("SELECT id, code FROM patients")) {
                while (rs.next()) {
                    SRC_PATIENT_ID_CACHE.put(rs.getString(2).trim(), rs.getLong(1));
                }
            }
        }
        return SRC_PATIENT_ID_CACHE.getOrDefault(code, -1L);
    }

    /**
     * Восстанавливает measurements так же, как их строит UploadService: значение, границы нормы,
     * единица и normalizedDeviation. Берутся результаты, записанные вместе с отчётом
     * (точное совпадение времени, иначе — ближайшая пачка в пределах окна).
     */
    private static List<Map<String, Object>> rebuildMeasurements(List<Result> results, long createdMs, Map<Long, Norm> norms) {
        List<Result> exact = new ArrayList<>();
        List<Result> near = new ArrayList<>();
        for (Result r : results) {
            if (r.timeMs() == createdMs) {
                exact.add(r);
            } else if (Math.abs(r.timeMs() - createdMs) <= MATCH_WINDOW_MS) {
                near.add(r);
            }
        }
        List<Result> chosen = exact.isEmpty() ? near : exact;
        List<Map<String, Object>> out = new ArrayList<>();
        for (Result r : chosen) {
            Norm norm = norms.get(r.normId());
            if (norm == null) {
                continue;
            }
            double range = norm.max() - norm.min();
            if (range <= 1e-9) {
                range = 1.0;
            }
            double dev = r.value() < norm.min() ? (norm.min() - r.value()) / range
                    : r.value() > norm.max() ? (r.value() - norm.max()) / range : 0.0;
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("analysis", norm.name());
            m.put("value", r.value());
            m.put("min", norm.min());
            m.put("max", norm.max());
            m.put("unit", norm.unit());
            m.put("normalizedDeviation", dev);
            out.add(m);
        }
        return out;
    }

    private static int ageOf(Map<String, Object> row) {
        Object age = row.get("age");
        if (age instanceof Number n) {
            return n.intValue();
        }
        try {
            return age == null ? 0 : (int) Double.parseDouble(String.valueOf(age).trim().replace(',', '.'));
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private static void bumpSequences(Connection dst, String... tables) throws SQLException {
        try (Statement st = dst.createStatement()) {
            for (String t : tables) {
                st.execute("SELECT setval(pg_get_serial_sequence('" + t + "', 'id'), COALESCE((SELECT MAX(id) FROM " + t + "), 0) + 1, false)");
            }
        }
    }

    private static Connection connect(String prefix) throws SQLException {
        String raw = env(prefix + "_URL", "");
        DatabaseUrl.Jdbc j = DatabaseUrl.parse(raw)
                .orElseThrow(() -> new IllegalArgumentException(prefix + "_URL не задан или не postgres://... / jdbc:postgresql://..."));
        String user = env(prefix + "_USER", j.username() == null ? "" : j.username());
        String pass = env(prefix + "_PASS", j.password() == null ? "" : j.password());
        return DriverManager.getConnection(j.url(), user, pass);
    }

    private static String env(String name, String def) {
        String v = System.getenv(name);
        return v == null || v.isBlank() ? def : v;
    }
}
