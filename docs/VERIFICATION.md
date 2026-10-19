# Проверки первой версии — 19 октября 2026

## Среда

Windows 11 x64 25H2; Flutter stable 3.47.7 / Dart 3.13.5;
Visual Studio Build Tools 2022 17.14.42; Windows SDK 10.0.26100.0;
Windows Developer Mode включён пользователем. Python 3.12.14, FastAPI 0.148.0.
Сборки запускаются через ASCII junction `D:\OptimumTools\workspace`.

## Подтверждено

| Проверка | Результат |
|---|---|
| Backend pytest | 17 passed: серверное время, play/pause/seek/next, rejoin, concurrency, retry, права, transfer, leave, votes, validation, HTTP ASGI |
| Backend ruff | All checks passed |
| Flutter analyzer | No issues found |
| Flutter unit/widget | 11 passed: прежние 8 проверок и 3 проверки JSON backup/restore, transaction rollback, миграции v1→v2 с целостной копией |
| Цикл Cosmic | Реальные Flutter кадры t=0 и t=90 совпадают; порог: менее 0.001% цветовых каналов отличаются более чем на 1/255 |
| Windows native integration | 1 passed повторно для 0.2.0: настоящий libmpv, WAV decode/duration, pause, seek, next/previous в паузе, repeat-one, auto-next, конец очереди, история после 10 секунд, missing-file/retry, новые настройки |
| Windows codec matrix | 1 passed: WAV/MP3/FLAC/OGG/M4A (AAC), русские пути, теги, duration/play/pause/seek; повреждённый WAV даёт ошибку, затем валидный MP3 играет |
| Анимация native UI | В активном lifecycle последовательные кадры отличаются; reduced motion даёт одинаковые кадры через секунду. В 0.2 тест явно задаёт resumed, чтобы переключение на редактор/GitHub не замораживало проверку |
| Windows release | Нативная x64 release-сборка, не web/PWA |

## Пакет 0.2.0

Release собран успешно; ProductVersion/FileVersion `0.2.0+3`. Portable:
`dist/OPTIMUM-0.2.0-windows-x64/optimum.exe`, ZIP рядом; SHA-256:
`75571c6e1f1cfd5dd4c4a5627d3aa1fe228bb6d54262b4b4b890a29f6a3b3fde`.
Старые пакеты сохранены. Backend после 17 passed/ruff не изменялся.

## Пакет 0.1.1 (сохранён)

Release exe имеет ProductVersion/FileVersion `0.1.1+2`. Portable-папка и ZIP:
`dist/OPTIMUM-0.1.1-windows-x64`. Архив снабжён SHA-256:
`fc2c6c78c74222ffc986aee78ac864c4f3d01fbbeeff65af216b4ac8e745082f`.
Приложение запущено из packaged folder; создало настоящую базу в
`%APPDATA%/app.optimum/OPTIMUM/library.db` и продолжает работать.

Короткий замер процесса 0.1.1: рабочий набор около 112 МБ, пик 118 МБ;
за 3.06 с — 0.5% одного CPU-ядра. Фокус окна не контролировался, поэтому это
smoke-замер процесса, а не benchmark активной анимации и не доказательство FPS.
JSON сохранён в `artifacts/release-idle-metrics-0.1.1.json`.
Туманности кэшируются в двух 256×256 текстурах; фон имеет отдельный clock 30 Гц,
проверенный бесшовный период 90 с. Неактивное окно не продолжает анимацию.

Native integration после compatibility patch не выводит прежние ошибки
`property not found ... osc` и `lavf: Failed to create file cache`.
CMake первого configure выдавал upstream dev warning CMP0175 в
media_kit_libs_windows_audio; сборка успешна. Логи не фильтровались.

## Визуальные артефакты

- `artifacts/flutter-home-1440.png`, `flutter-home-390.png`: кадры Flutter renderer,
  не дизайнерские картинки. Layout tests используют IdlePlayback test double.
- `artifacts/windows-library.png`, `windows-cosmic.png`: настоящие кадры нативного
  Windows integration test, с реальным аудиоплеером.
- `artifacts/windows-backup-settings.png`: новые настройки резервного копирования,
  настоящий Windows integration test. Выбор файлов в системных диалогах вручную
  не автоматизировался; чтение/запись JSON и транзакции проверены отдельно.
- `artifacts/cosmic-frames/`: короткий фрагмент нативной анимации.
- `artifacts/cosmic-loop-frames/`: полный цикл тех же Flutter painters в 120 фазах.
- `artifacts/optimum-cosmic.gif`: полный цикл, ускоренный с 90 до 9.6 секунд для
  осмотра стыка. Это не скорость движения в приложении.

Computer-use UI helper не удалось инициализировать: `failed to write kernel assets ...
os error 3`, включая попытку reset/retry. Ручная автоматизация окна не заявляется;
настоящие кадры и действия внутри приложения проверены native integration test.

## Ограничения

- Codec matrix подтверждена на коротких оригинальных fixtures. Большие каталоги,
  многочасовое воспроизведение, остальные варианты кодирования и Bluetooth не проверены.
- Измерения рассинхронизации двух реальных аудиоустройств отсутствуют. Domain/clock
  tests не равны готовому Together: WSS, Supabase JWT, PostgreSQL/RLS пока не подключены.
- Android SDK отсутствует; Android/iOS сборки, scoped storage, фон и lock-screen
  не проверены. Для iOS потребуются macOS/Xcode и signing.
- Нет cloud backup, экспорта аккаунта, автоматических подборок и платформенных интеграций.
- Нет release-профиля батареи/GPU и долговременного memory soak. Нельзя заявлять
  целевую частоту кадров или мобильное энергопотребление на основе desktop теста.
- Исходники опубликованы в github.com/nobklop/OPTIMUM; signing и installer отсутствуют. Native dependency
  notices и условия libmpv/FFmpeg требуют завершения проверки перед распространением.
