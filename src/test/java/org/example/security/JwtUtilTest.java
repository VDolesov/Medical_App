package org.example.security;

import io.jsonwebtoken.JwtException;
import org.example.model.enums.Role;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DisplayName("JwtUtil — выпуск и проверка JWT-токенов")
class JwtUtilTest {

    private static final String SECRET = "integration-test-secret-key-of-sufficient-length-1234567890";
    private static final long ONE_HOUR_MS = 3_600_000L;

    private final JwtUtil jwtUtil = new JwtUtil(SECRET, ONE_HOUR_MS);

    @Nested
    @DisplayName("Конструктор и конфигурация")
    class Configuration {

        @Test
        @DisplayName("секрет короче 32 байт отклоняется на старте приложения")
        void shortSecret_isRejected() {
            assertThatThrownBy(() -> new JwtUtil("too-short", ONE_HOUR_MS))
                    .isInstanceOf(IllegalStateException.class);
        }

        @Test
        @DisplayName("пустой секрет отклоняется")
        void blankSecret_isRejected() {
            assertThatThrownBy(() -> new JwtUtil("   ", ONE_HOUR_MS))
                    .isInstanceOf(IllegalStateException.class);
        }

        @Test
        @DisplayName("время жизни меньше 5 минут отклоняется")
        void tooShortExpiration_isRejected() {
            assertThatThrownBy(() -> new JwtUtil(SECRET, 60_000L))
                    .isInstanceOf(IllegalStateException.class);
        }

        @Test
        @DisplayName("время жизни больше 24 часов отклоняется")
        void tooLongExpiration_isRejected() {
            assertThatThrownBy(() -> new JwtUtil(SECRET, 86_400_001L))
                    .isInstanceOf(IllegalStateException.class);
        }

        @Test
        @DisplayName("корректная конфигурация создаётся без ошибок")
        void validConfiguration_isAccepted() {
            assertThatCode(() -> new JwtUtil(SECRET, ONE_HOUR_MS)).doesNotThrowAnyException();
        }
    }

    @Nested
    @DisplayName("Round-trip: выпуск → разбор")
    class RoundTrip {

        @Test
        @DisplayName("userId сохраняется в токене и корректно извлекается")
        void userId_survivesRoundTrip() {
            String token = jwtUtil.generateToken(42L, Role.DOCTOR);

            assertThat(jwtUtil.getUserId(token)).isEqualTo(42L);
        }

        @Test
        @DisplayName("роль сохраняется в токене и корректно извлекается")
        void role_survivesRoundTrip() {
            String token = jwtUtil.generateToken(7L, Role.ADMIN);

            assertThat(jwtUtil.getRole(token)).isEqualTo("ADMIN");
        }

        @Test
        @DisplayName("токены для разных пользователей не совпадают")
        void differentUsers_getDifferentTokens() {
            String tokenA = jwtUtil.generateToken(1L, Role.PATIENT);
            String tokenB = jwtUtil.generateToken(2L, Role.PATIENT);

            assertThat(tokenA).isNotEqualTo(tokenB);
        }
    }

    @Nested
    @DisplayName("Защита от подделки токена")
    class Tampering {

        @Test
        @DisplayName("токен, подписанный другим ключом, не проходит проверку подписи")
        void tokenSignedWithAnotherKey_isRejected() {
            JwtUtil foreignIssuer = new JwtUtil("a-completely-different-secret-key-also-32-plus-bytes", ONE_HOUR_MS);
            String foreignToken = foreignIssuer.generateToken(99L, Role.ADMIN);

            assertThatThrownBy(() -> jwtUtil.getUserId(foreignToken))
                    .isInstanceOf(JwtException.class);
        }

        @Test
        @DisplayName("искажённый токен не проходит проверку")
        void corruptedToken_isRejected() {
            String token = jwtUtil.generateToken(5L, Role.DOCTOR);
            String corrupted = token.substring(0, token.length() - 4) + "AAAA";

            assertThatThrownBy(() -> jwtUtil.getUserId(corrupted))
                    .isInstanceOf(JwtException.class);
        }

        @Test
        @DisplayName("произвольная строка вместо токена не проходит проверку")
        void garbageString_isRejected() {
            assertThatThrownBy(() -> jwtUtil.getRole("not-a-jwt-at-all"))
                    .isInstanceOf(JwtException.class);
        }
    }
}
