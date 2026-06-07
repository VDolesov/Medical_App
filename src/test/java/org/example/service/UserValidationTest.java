package org.example.service;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DisplayName("UserValidation — нормализация и валидация регистрационных данных")
class UserValidationTest {

    @Nested
    @DisplayName("normalizeUsername")
    class UsernameValidation {

        @ParameterizedTest
        @ValueSource(strings = {"doctor", "val_d", "user.name", "врач-1", "abc", "a1234567890"})
        @DisplayName("корректные логины принимаются без изменений")
        void validUsernames_accepted(String username) {
            assertThat(UserValidation.normalizeUsername(username)).isEqualTo(username);
        }

        @Test
        @DisplayName("ведущие и хвостовые пробелы обрезаются")
        void username_isTrimmed() {
            assertThat(UserValidation.normalizeUsername("  doctor_val  ")).isEqualTo("doctor_val");
        }

        @ParameterizedTest
        @ValueSource(strings = {"ab", "has space", "user@name", "знак!", "a/b"})
        @DisplayName("логины с недопустимыми символами или слишком короткие отклоняются")
        void invalidUsernames_rejected(String username) {
            assertThatThrownBy(() -> UserValidation.normalizeUsername(username))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("логин длиннее 64 символов отклоняется")
        void tooLongUsername_rejected() {
            assertThatThrownBy(() -> UserValidation.normalizeUsername("a".repeat(65)))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("null трактуется как пустой логин и отклоняется")
        void nullUsername_rejected() {
            assertThatThrownBy(() -> UserValidation.normalizeUsername(null))
                    .isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Nested
    @DisplayName("normalizeEmail")
    class EmailValidation {

        @Test
        @DisplayName("email приводится к нижнему регистру и обрезается")
        void email_normalizedToLowercase() {
            assertThat(UserValidation.normalizeEmail("  Doctor@Clinic.COM ")).isEqualTo("doctor@clinic.com");
        }

        @ParameterizedTest
        @ValueSource(strings = {"a@b.co", "user.name@sub.domain.ru", "x_y@mail.com"})
        @DisplayName("корректные адреса принимаются")
        void validEmails_accepted(String email) {
            assertThatCode(() -> UserValidation.normalizeEmail(email)).doesNotThrowAnyException();
        }

        @ParameterizedTest
        @ValueSource(strings = {"no-at-sign", "@no-local.com", "no-domain@", "two@@at.com", "spaces in@mail.com"})
        @DisplayName("адреса без @ или доменной части отклоняются")
        void invalidEmails_rejected(String email) {
            assertThatThrownBy(() -> UserValidation.normalizeEmail(email))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("адрес длиннее 255 символов отклоняется")
        void tooLongEmail_rejected() {
            String tooLong = "a".repeat(250) + "@b.com";

            assertThatThrownBy(() -> UserValidation.normalizeEmail(tooLong))
                    .isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Nested
    @DisplayName("normalizePersonName")
    class PersonNameValidation {

        @ParameterizedTest
        @ValueSource(strings = {"Иван", "Пётр", "O'Brien", "Анна-Мария", "Ван Дер Берг"})
        @DisplayName("имена из букв, пробелов, апострофов и дефисов принимаются")
        void validNames_accepted(String name) {
            assertThat(UserValidation.normalizePersonName(name, "Имя")).isEqualTo(name);
        }

        @Test
        @DisplayName("пробелы по краям обрезаются")
        void name_isTrimmed() {
            assertThat(UserValidation.normalizePersonName("  Иван  ", "Имя")).isEqualTo("Иван");
        }

        @ParameterizedTest
        @ValueSource(strings = {"Иван2", "Name!", "12345", "user_name"})
        @DisplayName("имена с цифрами и спецсимволами отклоняются, ошибка называет поле")
        void invalidNames_rejected(String name) {
            assertThatThrownBy(() -> UserValidation.normalizePersonName(name, "Имя"))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("Имя");
        }

        @Test
        @DisplayName("пустое имя отклоняется")
        void emptyName_rejected() {
            assertThatThrownBy(() -> UserValidation.normalizePersonName("   ", "Фамилия"))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("имя длиннее 100 символов отклоняется")
        void tooLongName_rejected() {
            assertThatThrownBy(() -> UserValidation.normalizePersonName("Я".repeat(101), "Имя"))
                    .isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Nested
    @DisplayName("requireStrongPassword (текущая политика — проверка длины)")
    class PasswordValidation {

        @ParameterizedTest
        @ValueSource(strings = {"1944", "qwerty", "P@ssw0rd", "очень длинный пароль"})
        @DisplayName("непустой пароль допустимой длины принимается")
        void validPasswords_accepted(String password) {
            assertThatCode(() -> UserValidation.requireStrongPassword(password)).doesNotThrowAnyException();
        }

        @ParameterizedTest
        @NullAndEmptySource
        @DisplayName("null или пустой пароль отклоняется")
        void emptyPassword_rejected(String password) {
            assertThatThrownBy(() -> UserValidation.requireStrongPassword(password))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("empty");
        }

        @Test
        @DisplayName("пароль ровно 128 символов — граничный допустимый случай")
        void password128Chars_accepted() {
            assertThatCode(() -> UserValidation.requireStrongPassword("x".repeat(128)))
                    .doesNotThrowAnyException();
        }

        @Test
        @DisplayName("пароль длиннее 128 символов отклоняется")
        void tooLongPassword_rejected() {
            assertThatThrownBy(() -> UserValidation.requireStrongPassword("x".repeat(129)))
                    .isInstanceOf(IllegalArgumentException.class);
        }
    }
}
