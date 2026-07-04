package org.example.tools;

import org.springframework.security.crypto.bcrypt.BCrypt;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;

public final class SeedDemoAccounts {

    private static final String DEFAULT_URL = "jdbc:postgresql://localhost:5433/medical";
    private static final String DEFAULT_USER = "postgres";
    private static final String DEFAULT_PASS = "postgres";

    private static final String PASSWORD = env("SEED_PASSWORD", "123");
    private static final int PATIENT_COUNT = Integer.parseInt(env("SEED_PATIENTS", "30"));

    private static final char[] CODE_SYMBOLS = "23456789ABCDEFGHJKMNPQRSTUVWXYZ".toCharArray();

    public static void main(String[] args) throws Exception {
        String url = env("SEED_DB_URL", DEFAULT_URL);
        String user = env("SEED_DB_USER", DEFAULT_USER);
        String pass = env("SEED_DB_PASS", DEFAULT_PASS);

        System.out.println("=== Demo seeder ===");
        System.out.println("DB: " + url);
        System.out.println("Password for everyone: " + PASSWORD);
        System.out.println();

        String hash = BCrypt.hashpw(PASSWORD, BCrypt.gensalt(10));

        try (Connection conn = DriverManager.getConnection(url, user, pass)) {
            conn.setAutoCommit(false);
            try {
                seedAdmin(conn, hash);
                List<Long> doctorIds = seedDoctors(conn, hash);
                seedPatients(conn, hash, doctorIds);
                conn.commit();
            } catch (Exception ex) {
                conn.rollback();
                throw ex;
            }
        }

        System.out.println();
        System.out.println("Done.");
        System.out.println("Admin:    admin");
        System.out.println("Doctors:  val / kos");
        System.out.println("Patients: patient1 ... patient" + PATIENT_COUNT);
        System.out.println("Password: " + PASSWORD);
    }

    private static void seedAdmin(Connection conn, String hash) throws SQLException {
        Long id = upsertUser(conn, "admin", "admin@demo.seed", "Админ", "Главный", "ADMIN", hash, null);
        System.out.println("Admin ready: id=" + id);
    }

    private static List<Long> seedDoctors(Connection conn, String hash) throws SQLException {
        List<Long> ids = new ArrayList<>();
        ids.add(upsertUser(conn, "val", "val@demo.seed", "Валентин", "Долесов", "DOCTOR", hash, null));
        ids.add(upsertUser(conn, "kos", "kos@demo.seed", "Константин", "Михайлов", "DOCTOR", hash, null));
        System.out.println("Doctors ready: " + ids);
        return ids;
    }

    private static void seedPatients(Connection conn, String hash, List<Long> doctorIds) throws SQLException {
        ThreadLocalRandom rnd = ThreadLocalRandom.current();
        int created = 0;
        int updated = 0;
        for (int i = 1; i <= PATIENT_COUNT; i++) {
            String username = "patient" + i;
            String email = "patient" + i + "@demo.seed";
            String firstName = randomFirstName(rnd);
            String lastName = randomLastName(rnd);
            Long attendingDoctorId = doctorIds.get((i - 1) % doctorIds.size());

            Long existingUserId = findUserIdByUsername(conn, username);
            Long patientId;
            if (existingUserId != null) {

                patientId = fetchUserPatientId(conn, existingUserId);
                if (patientId != null) {
                    updatePatientDoctor(conn, patientId, attendingDoctorId);
                }
                updated++;
            } else {
                int age = rnd.nextInt(22, 66);
                String gender = rnd.nextBoolean() ? "FEMALE" : "MALE";
                patientId = upsertPatient(conn, age, gender, attendingDoctorId);
                created++;
            }

            Long userId = upsertUser(conn, username, email, firstName, lastName, "PATIENT", hash, patientId);
            String code = patientId == null ? "?" : fetchPatientCode(conn, patientId);
            System.out.printf("  %-12s  code=%s  doctor=%d  user=%d%n",
                    username, code, attendingDoctorId, userId);
        }
        System.out.printf("Patients: %d created, %d updated (password reset).%n", created, updated);
    }

    private static Long fetchUserPatientId(Connection conn, long userId) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement("SELECT patient_id FROM users WHERE id = ?")) {
            ps.setLong(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    long v = rs.getLong(1);
                    return rs.wasNull() ? null : v;
                }
            }
        }
        return null;
    }

    private static void updatePatientDoctor(Connection conn, long patientId, Long doctorUserId) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement(
                "UPDATE patients SET attending_doctor_user_id = ?, updated_at = ? WHERE id = ?")) {
            if (doctorUserId == null) {
                ps.setNull(1, java.sql.Types.BIGINT);
            } else {
                ps.setLong(1, doctorUserId);
            }
            ps.setTimestamp(2, java.sql.Timestamp.from(Instant.now()));
            ps.setLong(3, patientId);
            ps.executeUpdate();
        }
    }

    private static Long upsertUser(Connection conn, String username, String email, String firstName,
                                   String lastName, String role, String passHash, Long patientId) throws SQLException {
        Long existing = findUserIdByUsername(conn, username);
        if (existing != null) {
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE users SET password_hash = ?, email = ?, first_name = ?, last_name = ?, role = ?, " +
                    "patient_id = COALESCE(?, patient_id) WHERE id = ?")) {
                ps.setString(1, passHash);
                ps.setString(2, email);
                ps.setString(3, firstName);
                ps.setString(4, lastName);
                ps.setString(5, role);
                if (patientId == null) {
                    ps.setNull(6, java.sql.Types.BIGINT);
                } else {
                    ps.setLong(6, patientId);
                }
                ps.setLong(7, existing);
                ps.executeUpdate();
            }
            return existing;
        }

        try (PreparedStatement ps = conn.prepareStatement(
                "INSERT INTO users (username, password_hash, email, first_name, last_name, role, patient_id) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, username);
            ps.setString(2, passHash);
            ps.setString(3, email);
            ps.setString(4, firstName);
            ps.setString(5, lastName);
            ps.setString(6, role);
            if (patientId == null) {
                ps.setNull(7, java.sql.Types.BIGINT);
            } else {
                ps.setLong(7, patientId);
            }
            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                if (rs.next()) {
                    return rs.getLong(1);
                }
            }
        }
        throw new SQLException("Failed to insert user " + username);
    }

    private static Long upsertPatient(Connection conn, int age, String gender, Long attendingDoctorId) throws SQLException {
        String code = allocateUniqueCode(conn);
        Instant now = Instant.now();
        try (PreparedStatement ps = conn.prepareStatement(
                "INSERT INTO patients (code, age, gender, created_at, updated_at, attending_doctor_user_id) " +
                "VALUES (?, ?, ?, ?, ?, ?)",
                Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, code);
            ps.setInt(2, age);
            ps.setString(3, gender);
            ps.setTimestamp(4, java.sql.Timestamp.from(now));
            ps.setTimestamp(5, java.sql.Timestamp.from(now));
            if (attendingDoctorId == null) {
                ps.setNull(6, java.sql.Types.BIGINT);
            } else {
                ps.setLong(6, attendingDoctorId);
            }
            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                if (rs.next()) {
                    return rs.getLong(1);
                }
            }
        }
        throw new SQLException("Failed to insert patient");
    }

    private static String allocateUniqueCode(Connection conn) throws SQLException {
        ThreadLocalRandom rnd = ThreadLocalRandom.current();
        for (int attempt = 0; attempt < 32; attempt++) {
            StringBuilder sb = new StringBuilder("P-");
            for (int i = 0; i < 8; i++) {
                sb.append(CODE_SYMBOLS[rnd.nextInt(CODE_SYMBOLS.length)]);
            }
            String code = sb.toString();
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT 1 FROM patients WHERE code = ?")) {
                ps.setString(1, code);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) {
                        return code;
                    }
                }
            }
        }
        throw new SQLException("Could not allocate unique patient code");
    }

    private static Long findUserIdByUsername(Connection conn, String username) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT id FROM users WHERE lower(username) = lower(?)")) {
            ps.setString(1, username);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getLong(1) : null;
            }
        }
    }

    private static String fetchPatientCode(Connection conn, Long patientId) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement("SELECT code FROM patients WHERE id = ?")) {
            ps.setLong(1, patientId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getString(1) : "?";
            }
        }
    }

    private static String env(String key, String def) {
        String v = System.getenv(key);
        return v == null || v.isBlank() ? def : v;
    }

    private static String randomFirstName(ThreadLocalRandom rnd) {
        String[] names = {"Иван", "Мария", "Алексей", "Елена", "Дмитрий", "Ольга", "Сергей", "Анна",
                "Михаил", "Наталья", "Андрей", "Татьяна", "Павел", "Ирина", "Николай", "Светлана"};
        return names[rnd.nextInt(names.length)];
    }

    private static String randomLastName(ThreadLocalRandom rnd) {
        String[] names = {"Иванов", "Петрова", "Сидоров", "Козлова", "Новиков", "Морозова",
                "Волков", "Соколова", "Кузнецов", "Попова", "Лебедев", "Орлова",
                "Григорьев", "Фёдорова", "Семёнов", "Васильева"};
        return names[rnd.nextInt(names.length)];
    }
}