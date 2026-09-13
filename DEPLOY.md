# Развёртывание

Бэкенд — Spring Boot в Docker на Render, база — PostgreSQL, фронт — статика
`Medical_React_frontend` на `reportmed.ru`, мобильный клиент — `mobile_v2`.

```
reportmed.ru (React, статика за Cloudflare)        mobile_v2 (Flutter)
        │ VITE_API_URL                                  │ --dart-define=API_BASE_URL
        └──────────────┬───────────────────────────────┘
                       ▼
     https://reportmed-api-v3.onrender.com   — этот репозиторий, Dockerfile, Render free
                       │ DATABASE_URL
                       ▼
                PostgreSQL (Render reportmed-db или Neon)
```

Node-версия (ветка `node-v1`, сервис `reportmed-api` на Render) остаётся резервом,
пока фронт и мобилка не переключены на новый адрес.

## 1. Render: сервис и база одним Blueprint

1. Render Dashboard → **New → Blueprint** → репозиторий `VDolesov/Medical_App`, ветка `main` → **Apply**.
   По [render.yaml](render.yaml) создаются база `reportmed-db` и сервис `reportmed-api-v3`.
2. Первая сборка идёт 5–8 минут (Maven внутри Docker). Готовность:
   `https://reportmed-api-v3.onrender.com/actuator/health` → `{"status":"UP"}`.
3. Секреты Render генерирует сам. `ADMIN_SECRET` (код персонала для регистрации врачей и
   администраторов) смотреть в **сервис → Environment**.
4. Если имя `reportmed-api-v3` окажется занято, Render добавит суффикс к адресу — тогда
   поправить адрес в `.github/workflows/keepalive.yml`, во фронте и в мобилке.

Переменные окружения сервиса (все заданы в `render.yaml`):

| Переменная | Значение |
|---|---|
| `SPRING_PROFILES_ACTIVE` | `prod` |
| `DATABASE_URL` | `postgres://user:pass@host/db` — приложение само превращает её в `spring.datasource.*` |
| `JWT_SECRET` | не короче 32 символов |
| `ADMIN_SECRET` | не короче 16 символов |
| `CORS_ALLOWED_ORIGINS` | домены фронта через запятую |
| `JAVA_TOOL_OPTIONS`, `DB_POOL_MAX`, `TOMCAT_THREADS_MAX` | ограничения под 512 МБ free-инстанса |

**База.** Free-план PostgreSQL на Render ограничен по сроку (условия — в Dashboard при
создании). Бессрочная бесплатная альтернатива — [Neon](https://neon.tech): создать проект,
взять connection string вида `postgres://…?sslmode=require` и вставить его в `DATABASE_URL`
сервиса. Схему в любой пустой базе создаёт Liquibase при первом старте.

## 2. Перенос данных из Node-версии

Инструмент `org.example.tools.MigrateFromNodeV1` читает базу Node напрямую и пишет в базу Java:

- пользователи — с теми же `id` и bcrypt-хешами (пароли сохраняются);
- нормы — добавляются только те, которых нет в справочнике Java;
- пациенты и отчёты — с теми же `id` (ссылки `/report/123` продолжают работать);
- в каждую строку отчёта восстанавливается массив `measurements` из `analysis_results`
  (Node хранил значения отдельно, Java считает индекс отклонений по ним);
- строки отчётов привязываются к пациентам, лечащим врачом становится врач первого отчёта.

Аналитика и выводы экспертной системы не переносятся — их пересчитывает Java (шаг 5).

1. Собрать jar: `mvn -DskipTests package` → `target/medical-app-0.0.1-SNAPSHOT.jar`.
2. Строки подключения (нужны **внешние** адреса, с ноутбука):
   - Node: Render → сервис `reportmed-api` → Environment → `DATABASE_URL`;
   - Java: Render → `reportmed-db` → Info → *External Database URL* (или строка из Neon).
3. Java-сервис должен стартовать хотя бы раз (схема создана), в базе — ни одного пользователя.
4. Пробный прогон без записи:

   ```bash
   export MIGRATE_SRC_URL='postgres://…база Node…'
   export MIGRATE_DST_URL='postgres://…база Java…'
   MIGRATE_DRY_RUN=true java -cp target/medical-app-0.0.1-SNAPSHOT.jar \
       -Dloader.main=org.example.tools.MigrateFromNodeV1 \
       org.springframework.boot.loader.launch.PropertiesLauncher
   ```

   В PowerShell переменные задаются как `$env:MIGRATE_SRC_URL='…'`.
5. Боевой прогон — та же команда без `MIGRATE_DRY_RUN`. Затем пересчёт аналитики:

   ```bash
   python scripts/regenerate_analytics.py --api https://reportmed-api-v3.onrender.com \
       --username <админ> --password '<пароль>'
   ```

Инструмент отказывается работать, если в целевой базе уже есть пользователи или отчёты —
чтобы не перепутать `id`. Повторный запуск — только в пустую базу.

## 3. Фронт

В `Medical_React_frontend/.env`:

```
VITE_API_URL=https://reportmed-api-v3.onrender.com
```

`npm run build` и выложить `build/` туда, где хостится `reportmed.ru`. Код фронта менять не
нужно: пути и поля ответов Java-API совпадают с Node-версией. Домен фронта должен быть в
`CORS_ALLOWED_ORIGINS`.

## 4. Мобильное приложение

```bash
cd mobile_v2
flutter build apk --release --dart-define=API_BASE_URL=https://reportmed-api-v3.onrender.com
```

## 5. После переключения

- `.github/workflows/keepalive.yml` пингует оба API каждые 10 минут (работает только с
  default-ветки). Когда Node больше не нужен — убрать второй шаг и остановить сервис
  `reportmed-api` на Render.
- Ветка `node-v1` остаётся в репозитории как архив Node-версии.

## Локально

`docker compose up --build` (см. README) либо jar напрямую:

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5433/medical java -jar target/medical-app-0.0.1-SNAPSHOT.jar
```
