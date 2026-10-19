# OPTIMUM

Текущая версия: **0.4.0**. Windows-прототип с переносом плейлистов Яндекса.

[![Скачать и установить](docs/assets/install-windows.svg)](https://github.com/nobklop/OPTIMUM/releases/download/v0.4.0/OPTIMUM-0.4.0-Setup-x64.exe)

Windows 10/11 x64: скачайте EXE, запустите и нажмите **Установить**. Дальше всё автоматически,
без администратора, Flutter и Visual Studio. Первая установка требует интернета.
Windows может попросить подтвердить запуск неподписанного приложения.
[Все версии с установщиками](https://github.com/nobklop/OPTIMUM/releases).

Локальные portable-пакеты сохраняются в `dist/OPTIMUM-<версия>-windows-x64/`.

Музыкальное пространство с Cosmic-интерфейсом. Первый локальный прототип:
Flutter + SQLite + just_audio, с отдельной основой FastAPI и Together domain.
Точная матрица проверок и ограничения: [VERIFICATION](docs/VERIFICATION.md).

## Что реализовано

- **Перенос из Яндекса**: текущий трек и полный состав открытого плейлиста/альбома
  в OPTIMUM. Предпросмотр, проверка полноты, порядок и повторы, отмена и обновление
  существующего плейлиста. Названия и ссылки сохраняются; аудио сервиса не скачивается.
- **Свой файл для офлайна**: при добавлении трека прикрепите аудиофайл. Он играет
  локально; исходный файл остаётся на своём месте. Плейлист можно открыть целиком
  в сервисе через сохранённый аккаунт.

- **Аккаунты сервисов**: вход и библиотека Яндекс Музыки / SoundCloud / Spotify
  внутри OPTIMUM, сохранение веб-сессии между открытиями. API-ключи не нужны;
  доступ и поддержка встроенного браузера определяются сервисом.
- Сохранение ссылок Spotify / Яндекс Музыки / SoundCloud без API-ключей;
  настоящие веб-плееры внутри Windows-приложения, поиск и удаление сохранённых ссылок.
- Скачивание прямых HTTPS-аудиофайлов с прогрессом, отменой и сохранением в локальную
  библиотеку. Полнота воспроизведения сервисов зависит от их доступа/подписки/страны;
  ссылки на их страницы не превращаются в MP3. Полный перенос состава реализован
  для Яндекса; для Spotify/SoundCloud пока сохраняются отдельные ссылки.
- Импорт локальных файлов и рекурсивное сканирование папки без перехода по symlinks.
- Метаданные в isolate; SQLite-библиотека, поиск, избранное, история.
- JSON-копии библиотеки: плейлисты, избранное, история, reduced motion; атомарное
  объединение при восстановлении. JSON v3 включает состав перенесённых плейлистов;
  v1/v2 читаются. SQLite v4 создаёт согласованную копию перед обновлением v1/v2/v3.
- Создание, переименование и удаление плейлистов; добавление/удаление треков.
- Аудиоплеер: play/pause, seek, next/previous, volume, repeat и ручное shuffle.
- Чтение встроенной обложки выбранного трека; ошибки повреждённых/пропавших файлов.
- Адаптивный Cosmic: 184 звезды, пять отдельных туманностей, детали главного блока,
  параллакс и орбиты; reduced motion, мини-плеер и полный плеер.
- Три настоящих авторских звуковых этюда для проверки без своей музыки.
- Серверное ядро Together: revision, идемпотентность, права, очередь, голоса,
  запланированный старт, актуальная позиция, rejoin и передача управления.

Together ещё не соединяет устройства. Аккаунты, облачная синхронизация, друзья,
чат, рекомендации, полный перенос Spotify/SoundCloud и фоновые альбомы — будущие этапы.
Кнопки не имитируют эти функции. Готовность полного продукта не заявляется.
Сценарий по ссылке, скачивание и ограничения: [LINK_IMPORT](docs/LINK_IMPORT.ru.md).
Для встроенных плееров нужен Microsoft Edge WebView2 Runtime; при его отсутствии
приложение показывает официальный установщик. Ключи разработчика не нужны.
Измерение и исправление плавности 0.2.2: [PERFORMANCE](docs/PERFORMANCE.md).

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
Для резервной копии используйте **Настройки → Сохранить копию**; восстановление —
**Восстановить из JSON**. Аудиофайлы не входят в JSON и должны оставаться на прежних
путях. Перед открытием 0.4.0 закройте старые экземпляры OPTIMUM.
Подробности формата и отката миграции: [BACKUPS](docs/BACKUPS.ru.md).

## Проверки и сборка

```powershell
cd D:\OptimumTools\workspace\client
& D:\OptimumTools\flutter\bin\flutter.bat analyze
& D:\OptimumTools\flutter\bin\flutter.bat test
& D:\OptimumTools\flutter\bin\flutter.bat test integration_test/windows_player_test.dart -d windows
& D:\OptimumTools\flutter\bin\flutter.bat test integration_test/codecs_test.dart -d windows
& D:\OptimumTools\flutter\bin\flutter.bat test integration_test/music_links_test.dart -d windows
& D:\OptimumTools\flutter\bin\flutter.bat test integration_test/service_transfer_test.dart -d windows
& D:\OptimumTools\flutter\bin\flutter.bat build windows --release
```

Результат release: `client/build/windows/x64/runner/Release/optimum.exe`.
Запускать с соседними DLL и data/, не переносить только exe.
UI-тесты сохраняют кадры в `artifacts/`; это output, не заранее нарисованные макеты.
Layout tests используют тестовый playback model; нативное декодирование проверяется
отдельным Windows integration test с настоящим libmpv.

## Установщики и GitHub Releases

`scripts/build-installer.ps1 -Version <версия>` упаковывает сохранённую portable-папку
через Inno Setup 6.7.3. Runtime MSVC размещается рядом с EXE; аудиодвижок получается
на машине пользователя из исходного релиза с проверкой двух SHA-256.
`scripts/test-installers.ps1` проверяет чистую установку, обновления, все хэши файлов,
защиту от отката, запуск приложения и удаление с сохранением библиотеки.
`scripts/publish-release.py <версия>` показывает план; `--publish` публикует после
проверок, `--latest` помечает последнюю версию. Доступ берётся из Git Credential
Manager и не выводится в журнал. Исходный тег проверяется перед загрузкой.
Подробности: [INSTALLER](docs/INSTALLER.ru.md), [native notices](docs/NATIVE_NOTICES.md).

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
