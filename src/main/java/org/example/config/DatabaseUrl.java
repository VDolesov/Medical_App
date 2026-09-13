package org.example.config;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.Optional;

/**
 * Перевод строки подключения вида {@code postgres://user:pass@host:5432/db?sslmode=require}
 * (так её отдают Render, Neon, Railway, Heroku) в JDBC-URL + логин + пароль, которые ждёт Spring.
 * Если строка уже начинается с {@code jdbc:}, она возвращается как есть.
 */
public final class DatabaseUrl {

    public record Jdbc(String url, String username, String password) {}

    private DatabaseUrl() {}

    public static Optional<Jdbc> parse(String raw) {
        if (raw == null || raw.isBlank()) {
            return Optional.empty();
        }
        String s = raw.trim();
        if (s.startsWith("jdbc:")) {
            return Optional.of(new Jdbc(s, null, null));
        }
        if (!s.startsWith("postgres://") && !s.startsWith("postgresql://")) {
            return Optional.empty();
        }
        URI uri;
        try {
            uri = new URI(s.replaceFirst("^postgres(ql)?://", "postgresql://"));
        } catch (URISyntaxException e) {
            throw new IllegalArgumentException("Некорректный DATABASE_URL: " + e.getMessage(), e);
        }
        if (uri.getHost() == null) {
            throw new IllegalArgumentException("Некорректный DATABASE_URL: не удалось разобрать хост");
        }
        String username = null;
        String password = null;
        String userInfo = uri.getUserInfo(); // уже раскодирован: %40 -> @
        if (userInfo != null) {
            int colon = userInfo.indexOf(':');
            username = colon < 0 ? userInfo : userInfo.substring(0, colon);
            password = colon < 0 ? null : userInfo.substring(colon + 1);
        }
        int port = uri.getPort() == -1 ? 5432 : uri.getPort();
        String path = uri.getPath() == null || uri.getPath().isEmpty() ? "/" : uri.getPath();
        String query = uri.getRawQuery() == null ? "" : "?" + uri.getRawQuery();
        String jdbc = "jdbc:postgresql://" + uri.getHost() + ":" + port + path + query;
        return Optional.of(new Jdbc(jdbc, username, password));
    }

    /**
     * Если задан {@code DATABASE_URL}, а явных {@code SPRING_DATASOURCE_*} нет — подставляет
     * разобранные значения в системные свойства до старта Spring. Системные свойства имеют
     * приоритет над application*.yml, поэтому плейсхолдеры prod-профиля не понадобятся.
     */
    public static void applyToSystemProperties(String databaseUrl) {
        if (System.getenv("SPRING_DATASOURCE_URL") != null || System.getProperty("spring.datasource.url") != null) {
            return;
        }
        parse(databaseUrl).ifPresent(j -> {
            System.setProperty("spring.datasource.url", j.url());
            if (j.username() != null && System.getenv("SPRING_DATASOURCE_USERNAME") == null) {
                System.setProperty("spring.datasource.username", j.username());
            }
            if (j.password() != null && System.getenv("SPRING_DATASOURCE_PASSWORD") == null) {
                System.setProperty("spring.datasource.password", j.password());
            }
        });
    }
}
