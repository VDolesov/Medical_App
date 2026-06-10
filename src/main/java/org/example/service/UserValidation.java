package org.example.service;

import java.util.Locale;
import java.util.regex.Pattern;

final class UserValidation {

    private static final Pattern USERNAME_PATTERN = Pattern.compile("^[\\p{L}\\p{N}._-]{3,64}$");
    private static final Pattern NAME_PATTERN = Pattern.compile("^[\\p{L}\\s'-]{1,100}$");
    private static final Pattern EMAIL_PATTERN = Pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$");

    private UserValidation() {
    }

    static String normalizeUsername(String raw) {
        String value = trim(raw);
        if (!USERNAME_PATTERN.matcher(value).matches()) {
            throw new IllegalArgumentException("Username must be 3-64 characters and contain only letters, digits, dot, underscore or dash");
        }
        return value;
    }

    static String normalizeEmail(String raw) {
        String value = trim(raw).toLowerCase(Locale.ROOT);
        if (value.length() > 255 || !EMAIL_PATTERN.matcher(value).matches()) {
            throw new IllegalArgumentException("Invalid email");
        }
        return value;
    }

    static String normalizePersonName(String raw, String fieldName) {
        String value = trim(raw);
        if (!NAME_PATTERN.matcher(value).matches()) {
            throw new IllegalArgumentException(fieldName + " may contain only letters, spaces, apostrophes and dashes");
        }
        return value;
    }

    static void requireStrongPassword(String password) {
        if (password == null || password.isEmpty()) {
            throw new IllegalArgumentException("Password must not be empty");
        }
        if (password.length() < 8) {
            throw new IllegalArgumentException("Минимальная длина пароля — 8 символов");
        }
        if (password.length() > 128) {
            throw new IllegalArgumentException("Максимальная длина пароля — 128 символов");
        }
        boolean hasLetter = password.chars().anyMatch(Character::isLetter);
        boolean hasDigit = password.chars().anyMatch(Character::isDigit);
        if (!hasLetter || !hasDigit) {
            throw new IllegalArgumentException("Пароль должен содержать хотя бы одну букву и одну цифру");
        }
    }

    private static String trim(String value) {
        return value != null ? value.trim() : "";
    }
}
