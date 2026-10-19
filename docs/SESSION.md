# Состояние разработки

Задание: `PRODUCT_BRIEF.ru.md`. Текущая граница — первый рабочий локальный Windows-прототип.
Полный продукт разрабатывается по ROADMAP, не объявляется готовым на этапе основы.

Среда: Windows 11 x64. В исходной папке не было файлов или Git.
Flutter stable установлен отдельно в `D:\OptimumTools\flutter`.
Python runtime встроенный; backend venv в `backend/.venv`.
На C: мало места; SDK расположены на D:.
Автоматический запуск VS Build Tools установщика был отклонён policy.
По просьбе пользователя установщик отдельно скачан в `D:\OptimumTools\vs_BuildTools.exe`,
Authenticode Microsoft valid. Пользователь установил C++ toolchain и включил Developer Mode.
Flutter doctor подтвердил Visual Studio Build Tools 2022 17.14.42 и Windows SDK 10.0.26100.0.
Создан junction D:\OptimumTools\workspace к проекту из-за ошибки LSP на пути с кириллицей.

Решения: реальное локальное аудио/SQLite; Together domain сначала под тестами;
не открывать сетевые room endpoints до Supabase JWT + durable storage.
Не использовать Sites/Godot для Flutter-продукта. Не устанавливать все upstream-проекты.
Нативный тест воспроизведения прошёл; обнаружены upstream mpv ошибки OSC/disk cache.
Минимальный локальный fork adapter в third_party/just_audio_media_kit исправляет настройки;
проверяется повторно без подавления логов. Computer-use node kernel не запустился
дважды с `failed to write kernel assets ... os error 3`; native UI снят integration test.

Остаток: подробные подтверждения и блокеры находятся в VERIFICATION.md.

Дополнение пользователя: фон должен быть анимированным, цикличным и плавным.
Реализован общий 90-секундный периодический clock, многослойные звёзды/туманности,
параллакс, orbit animation и edge fade. Отдельный renderer test сравнивает t=0/90;
native test проверяет движение и reduced motion. Старое GIF-превью было фрагментом
с заметным стыком; заменено полным циклом (в превью ускорение явно документировано).
Native тест дополнен реальными repeat/auto-next/end-of-queue/history сценариями — passed.

Первый проверенный этап сохранён commit `607ebe6` (0.1.0).
Финальная версия 0.1.1: кэшированные туманности, фон 30 Гц, lifecycle-aware startup;
8 Flutter tests, analyzer и native Windows integration повторно прошли.
Portable ZIP создан, SHA-256 записан; приложение открыто из dist/OPTIMUM-0.1.1-windows-x64.
Backend 17 tests/ruff passed; после этого backend не менялся.
Следующий большой этап: продолжить ROADMAP, приоритет — auth/persistence и настоящий WSS Together.
