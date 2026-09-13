package org.example.config;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DatabaseUrlTest {

    @Test
    @DisplayName("postgres:// с логином, паролем, портом и параметрами -> JDBC")
    void parsesFullUrl() {
        DatabaseUrl.Jdbc j = DatabaseUrl.parse("postgres://medical:s3cret@db.internal:5433/medical?sslmode=require").orElseThrow();
        assertThat(j.url()).isEqualTo("jdbc:postgresql://db.internal:5433/medical?sslmode=require");
        assertThat(j.username()).isEqualTo("medical");
        assertThat(j.password()).isEqualTo("s3cret");
    }

    @Test
    @DisplayName("postgresql:// без порта -> 5432; спецсимволы пароля раскодируются")
    void defaultsPortAndDecodesPassword() {
        DatabaseUrl.Jdbc j = DatabaseUrl.parse("postgresql://u:p%40ss%3Aword@host/db").orElseThrow();
        assertThat(j.url()).isEqualTo("jdbc:postgresql://host:5432/db");
        assertThat(j.password()).isEqualTo("p@ss:word");
    }

    @Test
    @DisplayName("jdbc:-строка возвращается без изменений, пустая/чужая -> empty")
    void passesJdbcThroughAndIgnoresOthers() {
        assertThat(DatabaseUrl.parse("jdbc:postgresql://h:5432/d").orElseThrow().url()).isEqualTo("jdbc:postgresql://h:5432/d");
        assertThat(DatabaseUrl.parse(null)).isEmpty();
        assertThat(DatabaseUrl.parse("   ")).isEmpty();
        assertThat(DatabaseUrl.parse("mysql://u:p@h/d")).isEmpty();
    }

    @Test
    @DisplayName("мусор вместо URL -> понятная ошибка")
    void rejectsGarbage() {
        assertThatThrownBy(() -> DatabaseUrl.parse("postgres://:@"))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
