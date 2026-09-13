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
                PostgreSQL в Neon (бесплатно, без срока)
```

Node-версия (ветка `node-v1`, сервис `reportmed-api` на Render) остаётся резервом,
пока фронт и мобилка не переключены на новый адрес.

## 1. База в Neon и сервис в Render

Бесплатная PostgreSQL самого Render удаляется через 30 дней после создания (плюс 14 дней
на апгрейд), поэтому база — в [Neon](https://neon.tech): бесплатный план без срока, 0.5 ГБ,
засыпает без запросов и просыпается за секунду.

1. Neon → **New project** (регион EU Frankfurt) → на странице проекта **Connect** →
   скопировать строку вида
   `postgresql://neondb_owner:…@ep-….eu-central-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require`.
   Схему в пустой базе создаст Liquibase при первом старте.
2. Render Dashboard → **New → Blueprint** → репозиторий `VDolesov/Medical_App`, ветка `main`.
   Render покажет [render.yaml](render.yaml) и попросит значение `DATABASE_URL` — вставить
   строку из Neon → **Apply**. Создаётся сервис `reportmed-api-v3` (Docker, free).
3. Первая сборка идёт 5–8 минут (Maven внутри Docker). Готовность:
   `https://reportmed-api-v3.onrender.com/actuator/health` → `{"status":"UP"}`.
4. Секреты Render генерирует сам. `ADMIN_SECRET` (код персонала для регистрации врачей и
   администраторов) смотреть в **сервис → Environment**.
5. Если имя `reportmed-api-v3` окажется занято, Render добавит суффикс к адресу — тогда
   поправить адрес в `.github/workflows/keepalive.yml`, во фронте и в мобилке.

Переменные окружения сервиса (все заданы в `render.yaml`):

| Переменная | Значение |
|---|---|
| `SPRING_PROFILES_ACTIVE` | `prod` |
| `DATABASE_URL` | `postgres://user:pass@host/db?sslmode=require` — приложение само превращает её в `spring.datasource.*` |
| `JWT_SECRET` | не короче 32 символов |
| `ADMIN_SECRET` | не короче 16 символов |
| `CORS_ALLOWED_ORIGINS` | домены фронта через запятую |
| `JAVA_TOOL_OPTIONS`, `DB_POOL_MAX`, `TOMCAT_THREADS_MAX` | ограничения под 512 МБ free-инстанса |

Free-инстанс Render засыпает через 15 минут без трафика и просыпается ~30–60 секунд —
для этого и нужен `keepalive.yml` (раздел 5).

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
2. Строки подключения (обе должны быть доступны с ноутбука):
   - Node: Render → сервис `reportmed-api` → Environment → `DATABASE_URL`
     (если база Node тоже на Render — брать *External Database URL*);
   - Java: строка из Neon (та же, что в `DATABASE_URL` сервиса).
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

## 5. Порядок переключения и вывод Node из эксплуатации

Free-план Render даёт 750 часов в месяц на весь аккаунт; сервис под keepalive не спит и
тратит ~720. Поэтому `keepalive.yml` пингует только один адрес (`API_URL`) — текущий прод.

1. **Старый Node-сервис `reportmed-api`** сразу: Settings → Build & Deploy → Branch → `node-v1`
   (или Auto-Deploy → Off). Иначе каждый пуш в `main` запускает у него сборку Java, которая
   падает и тратит build-минуты. Больше его не трогать — он прод до переключения фронта.
2. **База Node** — источник миграции, ничего не менять. Перед миграцией снять дамп на всякий
   случай: `pg_dump "<DATABASE_URL Node>" -Fc -f node-backup.dump`
   (Windows: `"C:\Program Files\PostgreSQLin\pg_dump.exe"`).
3. Развернуть Java (раздел 1), сделать пробную миграцию (раздел 2), проверить: вход своим
   аккаунтом, список отчётов, аналитика, PDF.
4. **День переключения.** Данные, добавленные в Node после пробной миграции, в Java не
   попадут, поэтому миграцию повторяют начисто:
   - Neon → SQL Editor: `DROP SCHEMA public CASCADE; CREATE SCHEMA public;`
   - Render → сервис → Manual Deploy → *Restart* — Liquibase пересоздаст схему;
   - миграция (раздел 2) и `regenerate_analytics.py`;
   - фронт (раздел 3) и мобилка (раздел 4);
   - `keepalive.yml`: `API_URL` → адрес Java-сервиса.
5. Через 1–2 недели без проблем: Node-сервис → Settings → **Suspend** (не удалять сразу —
   это откат за минуту), позже Delete. Базу Node удалить после того, как дамп сохранён.
6. Ветка `node-v1` остаётся в репозитории как архив Node-версии.

## Локально

`docker compose up --build` (см. README) либо jar напрямую:

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5433/medical java -jar target/medical-app-0.0.1-SNAPSHOT.jar
```
