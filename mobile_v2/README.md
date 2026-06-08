# mobile_v2 — переработанный UI/UX

Это альтернативная сборка фронтенда. Полностью переписана с нуля на Material 3,
с тёмной и светлой темой, Material 3 navigation bar, Inter-шрифтом (Google Fonts),
адаптивными карточками, осмысленными empty/error-состояниями. Бэкенд и API те же —
переключать `API_BASE_URL` не нужно, она использует те же endpoint'ы Spring-приложения.

Папка `mobile/` (старая версия) остаётся рядом для сравнения.

## Что внутри переделано (по сравнению с mobile/)

| Слой | Было (mobile/) | Стало (mobile_v2/) |
|---|---|---|
| Дизайн-система | Material 2-ish, BlueGrey | **Material 3**, seed-палитра teal, динамические цвета |
| Тема | только светлая | **светлая + тёмная**, авто-переключение по системе |
| Шрифты | Roboto by default | **Inter via Google Fonts**, согласованные веса |
| Навигация | `BottomNavigationBar` | **`NavigationBar` (M3)** с Badge на «Чатах» |
| Карточки | прямоугольные с тенями | скругление 18, без теней, в `surfaceContainer*` |
| Login | базовая форма | hero-аватар, демо-доступы, glass-карточка |
| Home | списка нет | **dashboard** с приветствием, stats, quick actions, последние отчёты |
| Reports | плоский список с длинной подписью | компактные карточки с аватаром, дата `dd MMM yyyy · HH:mm` |
| Report detail | модал + ExpansionTile | **отдельный экран**, экспертная карточка с tertiary-цветом |
| Chat | плоские bubbles | **Material 3 bubbles**, day-separator, time-pill, индикатор связи с правилом |
| Empty/Error | `Text('Нет данных')` | **EmptyState**: иконка-blob, заголовок, подсказка, кнопка действия |
| Loading | голый `CircularProgressIndicator` | **LoadingIndicator** с подписью «Загружаем…» |
| Severity-бейдж | Container с opacity | **SeverityBadge** с иконкой + цвет из `colorScheme` |

## Первый запуск

Поскольку папка содержит только `lib/` и `pubspec.yaml`, нужны нативные шаблоны
(android/ios) — их можно создать одной командой:

```bash
cd mobile_v2
flutter create --org ru.valdolesov --project-name medical_app_v2 \
  --platforms android,ios,web .
flutter pub get
flutter run
```

`flutter create` со ссылкой `.` НЕ перетирает уже существующие `lib/` и `pubspec.yaml` —
он добавляет недостающие `android/`, `ios/`, `web/` (если выбрана платформа) и т.д.

## Где меняется бэкенд-адрес

В `lib/config/api_config.dart` — для Android-эмулятора по умолчанию `http://10.0.2.2:8080`.
Переопределяется без правки кода:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080
```

## Что пока не перенесено

В админ-разделе сделана **только** «База знаний» (read-only список правил с цветной
индикацией severity и ссылкой на источник). «Пациенты» и «Все отчёты» — заглушки,
эти разделы остаются в `mobile/`.

«Привязка строк к пациенту» (`row-bind`) — тоже заглушка; это технический экран
доктора, его UI/UX в v2 пока не переработан.

## Демо-логины (через тот же сидер)

| Логин | Пароль | Роль |
|---|---|---|
| `admin` | `123` | ADMIN |
| `val` | `123` | DOCTOR |
| `kos` | `123` | DOCTOR |
| `patient1…30` | `123` | PATIENT |
