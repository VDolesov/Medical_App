# Деплой Spring Boot версии на Railway (параллельно со старым прод)

Цель — поднять новый Spring Boot бэкенд из ветки `spring-boot-v2` как **отдельный сервис**, не трогая работающий Node.js прод на `main`. Когда новый сервис стабильно зелёный — переключаем трафик (cutover).

## 1. Создать сервис из ветки

1. В своём проекте Railway: **New → GitHub Repo → `VDolesov/Medical_App`**.
2. В настройках сервиса **Settings → Source** выбрать ветку **`spring-boot-v2`** (НЕ `main`).
3. Build определится автоматически по `railway.json` → собирается из `Dockerfile`.

## 2. Добавить базу данных

1. В проекте: **New → Database → Add PostgreSQL**.
2. Railway создаст сервис `Postgres` с переменными `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`.

> Это **отдельная** база от старого прод — данные при необходимости перенесём отдельно (см. раздел 6).

## 3. Переменные окружения сервиса

Сервис → **Variables** → добавить. Значения с `${{Postgres.*}}` — это ссылки Railway на сервис БД (если БД названа не `Postgres`, подставь её имя).

| Переменная | Значение |
|---|---|
| `SPRING_PROFILES_ACTIVE` | `prod` |
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://${{Postgres.PGHOST}}:${{Postgres.PGPORT}}/${{Postgres.PGDATABASE}}` |
| `SPRING_DATASOURCE_USERNAME` | `${{Postgres.PGUSER}}` |
| `SPRING_DATASOURCE_PASSWORD` | `${{Postgres.PGPASSWORD}}` |
| `JWT_SECRET` | случайная строка ≥ 32 символов |
| `ADMIN_SECRET` | случайная строка ≥ 16 символов |
| `CORS_ALLOWED_ORIGINS` | origin фронта, через запятую (для мобилки можно пропустить) |

Не задавай `PORT` — Railway инжектит его сам, приложение уже слушает `$PORT`.

Сгенерировать секреты:
```bash
openssl rand -base64 48   # JWT_SECRET
openssl rand -base64 24   # ADMIN_SECRET
```

## 4. Деплой и проверка

1. **Deploy**. В логах должно быть: Liquibase прогоняет миграции `001…006`, затем `Started MedicalApplication on port <PORT>`.
2. Railway дождётся healthcheck `GET /actuator/health` → `{"status":"UP"}` (заложен в `railway.json`, таймаут 300 с на старт + миграции).
3. Сгенерировать домен: **Settings → Networking → Generate Domain**.
4. Дымовой тест по новому домену:
   ```bash
   curl https://<new-domain>/actuator/health        # {"status":"UP"}
   curl https://<new-domain>/ping                    # проверка веб-слоя
   curl -X POST https://<new-domain>/register ...    # создать пользователя
   curl -X POST https://<new-domain>/login ...       # получить JWT
   ```

> Swagger в prod закрыт (`app.swagger.public-enabled=false`). Чтобы временно открыть для проверки — добавь `SWAGGER_PUBLIC_ENABLED=true`, потом убери.

## 5. Cutover (когда новый сервис стабилен)

1. Перенацелить мобильные клиенты (`mobile_v2`) на новый базовый URL.
2. Переключить публичный домен/трафик на новый сервис.
3. Старый Node.js сервис (`main`) оставить включённым ещё на пару дней как быстрый откат.
4. После подтверждения — сделать `spring-boot-v2` основной веткой (или влить в `main`) и перенаправить деплой Railway на неё.

## 6. Перенос данных (если нужен)

Старый Node прод и новый Spring Boot используют разные схемы. Если нужно перенести существующих пользователей/отчёты — делаем отдельным шагом: дамп нужных таблиц из старой БД → скрипт-маппинг в новую схему. Не делать «вживую» на работающем прод.

---

**Текущее состояние веток:**
- `main` → Node.js, **живой прод**, не трогаем до cutover.
- `spring-boot-v2` → новый Spring Boot, деплоится в отдельный Railway-сервис.
