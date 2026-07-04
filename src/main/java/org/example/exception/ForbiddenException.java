package org.example.exception;

/** Пользователь аутентифицирован, но не имеет прав на операцию — HTTP 403. */
public class ForbiddenException extends RuntimeException {

    public ForbiddenException() {
        super("Доступ запрещён");
    }

    public ForbiddenException(String message) {
        super(message);
    }
}
