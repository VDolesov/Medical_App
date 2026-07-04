package org.example.exception;

/** Ресурс не существует или недоступен текущему пользователю — HTTP 404. */
public class NotFoundException extends RuntimeException {

    public NotFoundException() {
        super("Не найдено");
    }

    public NotFoundException(String message) {
        super(message);
    }
}
