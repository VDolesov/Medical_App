# Деплой на Railway

## Шаг 1: Подготовка

1. Зарегистрируйтесь на [Railway](https://railway.app/)
2. Создайте новый проект
3. Подключите GitHub репозиторий или загрузите файлы

## Шаг 2: Настройка базы данных

1. В проекте Railway добавьте PostgreSQL сервис
2. Скопируйте переменные окружения из PostgreSQL сервиса

## Шаг 3: Настройка переменных окружения

В настройках вашего Node.js сервиса добавьте переменные:

```
PGUSER=postgres
PGHOST=containers-us-west-XX.railway.app
PGDATABASE=railway
PGPASSWORD=your_password
PGPORT=5432
JWT_SECRET=your_secret_key_here
ADMIN_SECRET=1111
```

## Шаг 4: Деплой

1. Railway автоматически определит, что это Node.js проект
2. Деплой произойдет автоматически после push в репозиторий
3. Получите URL вашего API (например: https://your-app.railway.app)

## Шаг 5: Обновление Flutter приложения

Обновите URL в `lib/providers/auth_provider.dart`:

```dart
static const String _baseUrl = 'https://your-app.railway.app';
```

Пересоберите приложение и загрузите в RuStore. 