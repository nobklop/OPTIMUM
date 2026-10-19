# OPTIMUM

Музыкальное пространство с Cosmic-интерфейсом. Первый локальный прототип:
Flutter + SQLite + just_audio, с отдельной основой FastAPI и Together domain.
Точная матрица проверок и ограничения: [VERIFICATION](docs/VERIFICATION.md).

## Что реализовано

- Импорт локальных файлов и рекурсивное сканирование папки без перехода по symlinks.
- Метаданные в isolate; SQLite-библиотека, поиск, избранное, история.
- Создание, переименование и удаление плейлистов; добавление/удаление треков.
- Аудиоплеер: play/pause, seek, next/previous, volume, repeat и ручное shuffle.
- Чтение встроенной обложки выбранного трека; ошибки повреждённых/пропавших файлов.
- Адаптивный Cosmic: многослойные звёзды, мерцание, движущиеся туманности,
  параллакс и орбиты; reduced motion, мини-плеер и полный плеер.
- Три настоящих авторских звуковых этюда для проверки без своей музыки.
- Серверное ядро Together: revision, идемпотентность, права, очередь, голоса,
  запланированный старт, актуальная позиция, rejoin и передача управления.

Together ещё не соединяет устройства. Аккаунты, облачная синхронизация, друзья,
чат, рекомендации, загрузки из сервисов и фоновые альбомы — будущие этапы.
Кнопки не имитируют эти функции. Готовность полного продукта не заявляется.

## Быстрый запуск Windows

Требуются Flutter stable, Visual Studio Build Tools с Desktop C++, MSVC/CMake/Windows SDK,
и Windows Developer Mode для symlinks. Проверка: `flutter doctor -v`.

В текущем окружении SDK: `D:\OptimumTools\flutter`; короткий путь к исходникам:
`D:\OptimumTools\workspace` (junction к этой папке, не отдельная копия).
Сборку выполнять из короткого ASCII-пути: Flutter 3.47.7 analyzer некорректно
обработал исходный путь с кириллицей. Junction используется также для CMake.

```powershell
cd D:\OptimumTools\workspace\client
& D:\OptimumTools\flutter\bin\flutter.bat pub get
& D:\OptimumTools\flutter\bin\flutter.bat run -d windows
```

Пользовательские аудиофайлы не отправляются на сервер и не удаляются.
База — в application support directory Windows; точный путь виден в настройках.
Если переместить исходную музыку, её нужно импортировать заново.
Для backup закройте приложение и скопируйте папку базы вместе с файлами SQLite.
Плейлисты/избранное сохраняются локально; экспорт в облако пока отсутствует.

## Проверки и сборка

```powershell
cd D:\OptimumTools\workspace\client
& D:\OptimumTools\flutter\bin\flutter.bat analyze
& D:\OptimumTools\flutter\bin\flutter.bat test
& D:\OptimumTools\flutter\bin\flutter.bat test integration_test/windows_player_test.dart -d windows
& D:\OptimumTools\flutter\bin\flutter.bat build windows --release
```

Результат release: `client/build/windows/x64/runner/Release/optimum.exe`.
Запускать с соседними DLL и data/, не переносить только exe.
UI-тесты сохраняют кадры в `artifacts/`; это output, не заранее нарисованные макеты.
Layout tests используют тестовый playback model; нативное декодирование проверяется
отдельным Windows integration test с настоящим libmpv.

## Backend

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.lock
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\python.exe -m ruff check app tests
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8787
```

HTTP: `/health`, `/v1/capabilities`, `/docs`. Сетевых операций комнат нет до JWT
и постоянного хранения. Domain tests не подтверждают точность реальных аудиовыходов.

## Android / iOS

Runners сохранены, общий UI/домен на Dart. Android SDK в текущей среде отсутствует;
iOS требует macOS/Xcode/signing. Сборки этих платформ, scoped storage, audio focus,
фон и управление с lock-screen ещё не подтверждены. Не устанавливайте лишние SDK
до соответствующего этапа.

Архитектура: [ARCHITECTURE](ARCHITECTURE.md), план: [ROADMAP](ROADMAP.md),
upstream/лицензии: [DEPENDENCIES](docs/DEPENDENCIES.md), задание: [PRODUCT_BRIEF](docs/PRODUCT_BRIEF.ru.md).
