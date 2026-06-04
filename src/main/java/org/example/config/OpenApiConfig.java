package org.example.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.servers.Server;
import io.swagger.v3.oas.models.tags.Tag;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class OpenApiConfig {

    public static final String SECURITY_SCHEME = "bearerAuth";

    public static final String TAG_AUTH = "Авторизация";
    public static final String TAG_PROFILE = "Профиль";
    public static final String TAG_NORMS = "Нормы анализов";
    public static final String TAG_UPLOAD = "Загрузка XLSX";
    public static final String TAG_REPORTS_DOCTOR = "Отчёты врача";
    public static final String TAG_REPORTS_PDF = "Отчёты PDF";
    public static final String TAG_REPORT_BIND = "Привязка пациентов";
    public static final String TAG_PATIENT_DIRECTORY = "Справочник пациентов";
    public static final String TAG_EXPERT = "Экспертная система";
    public static final String TAG_ANALYTICS = "Аналитика отчётов";
    public static final String TAG_PATIENT_PORTAL = "Кабинет пациента";
    public static final String TAG_CHAT = "Чат";
    public static final String TAG_ADMIN_USERS = "Админ: пользователи";
    public static final String TAG_ADMIN_PATIENTS = "Админ: пациенты";
    public static final String TAG_ADMIN_REPORTS = "Админ: отчёты";
    public static final String TAG_ADMIN_KNOWLEDGE = "Админ: база знаний";
    public static final String TAG_ADMIN_NORMS = "Админ: нормы анализов";
    public static final String TAG_SYSTEM = "Служебные";

    @Bean
    public OpenAPI medicalOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Medical App API")
                        .version("1.0")
                        .description("""
                                REST-API приложения «Лабораторная аналитика».

                                Авторизация — JWT в заголовке `Authorization: Bearer <token>`.
                                Токен выдаётся ручкой `POST /login`.

                                Роли: `PATIENT`, `DOCTOR`, `ADMIN`. Доступ к ручкам ограничен по роли,
                                несоответствие роли возвращает `403 Forbidden`.""")
                        .contact(new Contact().name("Medical App").email("noreply@medical-app.local")))
                .servers(List.of(
                        new Server().url("/").description("Medical App backend")
                ))
                .components(new Components()
                        .addSecuritySchemes(SECURITY_SCHEME, new SecurityScheme()
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")
                                .description("JWT-токен, полученный через POST /login")))
                .addSecurityItem(new SecurityRequirement().addList(SECURITY_SCHEME))
                .tags(List.of(
                        new Tag().name(TAG_AUTH).description("Регистрация и вход. Публичные ручки, токен не требуется."),
                        new Tag().name(TAG_PROFILE).description("Информация о текущем пользователе."),
                        new Tag().name(TAG_NORMS).description("Справочник лабораторных норм (референсные диапазоны)."),
                        new Tag().name(TAG_UPLOAD).description("Загрузка XLSX-файла с результатами анализов."),
                        new Tag().name(TAG_REPORTS_DOCTOR).description("Просмотр и удаление загруженных отчётов (роль DOCTOR)."),
                        new Tag().name(TAG_REPORTS_PDF).description("Генерация PDF по конкретному пациенту в отчёте."),
                        new Tag().name(TAG_REPORT_BIND).description("Привязка строк отчёта к карточкам пациентов и закрепление за врачом."),
                        new Tag().name(TAG_PATIENT_DIRECTORY).description("Поиск пациентов по коду или ФИО — для привязки и переписки."),
                        new Tag().name(TAG_EXPERT).description("Каталог правил экспертной системы и сработавшие выводы."),
                        new Tag().name(TAG_ANALYTICS).description("Числовая аналитика отчёта: интегральная оценка и динамика."),
                        new Tag().name(TAG_PATIENT_PORTAL).description("Ручки личного кабинета пациента."),
                        new Tag().name(TAG_CHAT).description("Чат пациент↔врач и админ↔врач: треды, сообщения, блокировка."),
                        new Tag().name(TAG_ADMIN_USERS).description("Управление пользователями (CRUD), доступно только ADMIN."),
                        new Tag().name(TAG_ADMIN_PATIENTS).description("Просмотр всех пациентов и назначение лечащего врача."),
                        new Tag().name(TAG_ADMIN_REPORTS).description("Все отчёты системы вне зависимости от автора."),
                        new Tag().name(TAG_ADMIN_KNOWLEDGE).description("Управление клиническими правилами и источниками."),
                        new Tag().name(TAG_ADMIN_NORMS).description("Управление справочником лабораторных норм."),
                        new Tag().name(TAG_SYSTEM).description("Служебные ручки (health-check).")
                ));
    }
}
