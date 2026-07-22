# Развёртывание

Приложение поднимается одной командой через Docker Compose: Caddy отдаёт фронт и
терминирует HTTPS, Node обслуживает API, PostgreSQL хранит данные.

```
интернет :443
     │
   Caddy ──── /api/*  → срезается /api → api:5000 (Node)
     │  └──── всё остальное → build/ фронта (React SPA)
     │
  postgres — только во внутренней сети, наружу не публикуется
```

Один домен на всё: `https://example.ru` — сайт, `https://example.ru/api/...` — API.
Общий origin избавляет от CORS, сертификат нужен один.

## Требования

- Сервер с Ubuntu 24.04, от 2 vCPU / 4 GB (Selectel Cloud, Timeweb Cloud, любой VPS)
- Домен, A-запись которого указывает на IP сервера

## Раскладка на сервере

```
/opt/medapp/
├── backend/    этот репозиторий: docker-compose.yml, Caddyfile, .env
└── frontend/   репозиторий Medical_React_frontend, собирается в build/
```

## Установка

### 1. Docker и файрвол

```bash
apt update && apt -y upgrade
curl -fsSL https://get.docker.com | sh

ufw allow OpenSSH
ufw allow 80
ufw allow 443
ufw --force enable
```

### 2. Исходники

```bash
mkdir -p /opt/medapp && cd /opt/medapp
git clone https://github.com/VDolesov/Medical_App.git backend
git clone https://github.com/VDolesov/Medical_React_frontend.git frontend
```

### 3. Сборка фронтенда

Node на хост ставить не нужно, сборка идёт в одноразовом контейнере:

```bash
docker run --rm -v /opt/medapp/frontend:/app -w /app \
  -e VITE_API_URL=/api node:20 sh -c "npm ci && npm run build"
```

`VITE_API_URL=/api` вшивается в сборку, поэтому фронт обращается к API по
относительному пути и не зависит от домена.

### 4. Переменные окружения

```bash
cd /opt/medapp/backend
cp .env.example .env
openssl rand -hex 32   # PGPASSWORD
openssl rand -hex 32   # JWT_SECRET
openssl rand -hex 16   # ADMIN_SECRET
nano .env              # вписать DOMAIN и три секрета
```

`.env` в git не попадает. Значения по умолчанию из примера в проде недопустимы.

### 5. Запуск

```bash
docker compose up -d --build
docker compose logs -f
```

Сертификат Caddy получит сам при первом старте — при условии, что домен уже
резолвится на этот сервер и порты 80/443 открыты.

### 6. Проверка

```bash
curl https://ВАШ_ДОМЕН/api/ping     # ожидается: pong
```

Ответ `pong` подтверждает всю цепочку: Caddy принял запрос, срезал префикс
`/api` и достучался до Node. После этого можно открывать сайт в браузере.

## Схема базы данных

`db/init.sql` выполняется автоматически при первом создании тома `pgdata`.
На уже существующей базе он не запускается — том нужно удалить или применять
изменения вручную.

## Обновление

```bash
cd /opt/medapp/backend && git pull
cd /opt/medapp/frontend && git pull
docker run --rm -v /opt/medapp/frontend:/app -w /app \
  -e VITE_API_URL=/api node:20 sh -c "npm ci && npm run build"
cd /opt/medapp/backend && docker compose up -d --build
```

## Резервные копии

```bash
mkdir -p /opt/backups
# crontab -e
0 3 * * * cd /opt/medapp/backend && docker compose exec -T db \
  pg_dump -U medapp medapp | gzip > /opt/backups/medapp_$(date +\%F).sql.gz
```

## Масштабирование

- Перенести базу в управляемый PostgreSQL провайдера — меняется только `PGHOST` в `.env`
- Поднять несколько экземпляров API: `docker compose up -d --scale api=3`,
  Caddy распределяет запросы между ними автоматически

## Мобильное приложение

Адрес сервера задан в `medical_app/lib/providers/` — константа `_baseUrl`
в трёх провайдерах, значение вида `https://ВАШ_ДОМЕН/api`. При смене адреса
нужно поднять `version` в `medical_app/pubspec.yaml` (число после `+` обязано
вырасти), пересобрать релиз тем же ключом подписи и загрузить в RuStore.

Поскольку домен собственный, дальнейшая смена хостинга не требует пересборки
приложения — достаточно изменить A-запись.
