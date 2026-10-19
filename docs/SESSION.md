# Состояние разработки

Текущий checkpoint: **0.2.2**, source tag `af86a77`, опубликован на GitHub и latest.
Установлена и открыта `D:\OptimumTools\OPTIMUM-app\optimum.exe` (0.2.2+5),
есть ярлык; процесс отвечал. Все пять версий имеют проверенные EXE installers.
12 Flutter tests, analyzer, native Windows audio/UI passed; profile pacing исправлен.
Публичный 0.2.2 installer скачан обратно и совпал с локальным SHA-256, latest проверен.
Итог для пользователя: docs/INTERIM_REPORT.ru.md. Следующий модуль — LINK_IMPORT.ru.md;
API-доступ SoundCloud/Artist Pro уточнён, ответ пока не получен. Импорта ссылок ещё нет.

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

## Этап 0.2.0

Пользователь попросил продолжать до лимитов и сохранять промежуточные версии.
Remote origin: https://github.com/nobklop/OPTIMUM.git (изначально пуст).
Git Credential Manager авторизован пользователем через GitHub device flow;
main/v0.1.0/v0.1.1 успешно отправлены, remote refs проверены. Секреты не записаны.

Добавлены metadata-only JSON backups: data/backup.dart, AppModel и Settings UI.
SQLite v2: стабильные ключи плейлистов и VACUUM INTO перед v1-миграцией.
Тесты подтверждают roundtrip, одноимённые плейлисты, идемпотентность, сохранение
текущих данных, rollback при ошибке, целостную автоматическую v1-копию.
История сортируется по времени, поэтому старый backup не меняет свежий порядок.

Windows codec matrix прошла WAV/MP3/FLAC/OGG/M4A и damaged WAV→recovery.
Патч adapter завершает ошибочную загрузку и устраняет stale seek position;
controller ограничивает load 15 сек, next/previous сохраняют паузу.
11 unit/widget tests, analyzer и повторный native Windows UI/audio test прошли.
Native rendering test явно задаёт active lifecycle, потому что переход на GitHub
ожидаемо останавливал фон при потере фокуса; сама анимация не сломана.
Новый native кадр: artifacts/windows-backup-settings.png.
Release 0.2.0+3 собран, portable ZIP и SHA-256 сохранены в dist, предыдущие пакеты
оставлены. Следующий локальный этап: сохранять очередь/позицию/громкость между
запусками без autoplay, затем улучшить импорт больших папок. Together остаётся
главным большим сетевым этапом; для него ещё нужны Supabase/JWT/PostgreSQL/WSS.

## Этап 0.2.1 и текущие приоритеты

0.2.0 сохранён как a435fbe и отправлен main/v0.2.0. При первой попытке commit
не прошёл из-за отсутствующей identity; неверная свежая метка исправлена с
force-with-lease только для известного нашего SHA, remote main/tag перепроверены.
Для будущих commits использовать -c user.name=Codex -c user.email=codex@local.invalid.

По пользовательским скриншотам: 184 звезды вместо 136, 5 отдельных туманностей,
HeroSkyPainter со звёздами/созвездием/спутниками/дугами. 3 UI/loop tests + native
Windows integration + analyzer passed. Новые реальные кадры показаны пользователю.

Пользователь просит кнопку установки у каждой версии GitHub. Реализованы Inno
setup, build/test/publish scripts, release notes, badge. Тихая установка самого
компилятора была отклонена policy; скачивание отдельно и подпись Pyrsys проверены,
мастер открыт интерактивно, пользователь установил в D:\OptimumTools\Inno Setup 6.
4 installer EXE собраны. Последовательные install/upgrade, payload hashes,
downgrade guard, installed launch, uninstall и сохранение библиотеки passed.
Движок mpv получается из исходного upstream с pinned SHA, не включён в публичный
setup из-за незакрытого corresponding-source audit. Полные engine/package notices
и CRT включены. Не публиковать локальные portable ZIP как release assets.

Следующее: опубликовать installers 0.1.0/0.1.1/0.2.0/0.2.1 после source checkpoint.
Главный новый сценарий пользователя: ссылки Яндекс Музыки/Spotify/SoundCloud →
трек/плейлист в OPTIMUM, воспроизведение и доступное по правилам сервиса скачивание.
Нужны provider APIs/OAuth; имитации импорта нет. Изучены официальные документы.
Сохранение очереди/позиции было запланировано, но ещё не начато.
Пользователь снова сообщил о рывках анимации и попросил исправить именно под конец
лимитов: после текущего этапа измерить frame pacing, снять 30Hz cap при необходимости,
проверить плавность и бесшовность перед финальной промежуточной сборкой.

## Заключительный этап 0.2.2

0.2.1 commit 9c472b5 опубликован main/tag. Публичные releases 0.1.0, 0.1.1,
0.2.0, 0.2.1 созданы с EXE-установщиками и SHA-256; digest каждого asset проверен.
0.2.1 дополнительно скачан с публичной прямой ссылки: SHA совпал. Кнопка README
и кнопки в notes у каждой версии ведут на реальный installer.

Сняты настоящие profile benchmark до/после: 180→414 motion ticks за 6 секунд,
30.0576→69.1186 Гц, p95 интервал 45.002→20.001 мс. GPU raster p95 не ухудшился:
15.862→15.437 мс. Удалён floor(time*30) из Cosmos; обновления каждый vsync.
Новый тест: 120 последовательных кадров, inactive, reduced. Всего 12 tests passed;
analyzer no issues. Benchmark tool в client/tool, использует только :memory: SQLite.
Метрики в artifacts/cosmic-pacing-before/after.json, объяснение docs/PERFORMANCE.md.

Новый главный link-import сценарий записан в docs/LINK_IMPORT.ru.md с точными
проверенными API-границами. SoundCloud OpenAPI помечает stream_url deprecated/
preview-only; использовать /tracks/{urn}/streams. Регистрация API требует Artist Pro,
вопрос пользователю задан, ответ пока не получен. Live интеграции нет, не заявлять её.
Далее завершить native test/release 0.2.2, portable+installer, проверку обновления,
публикацию и установку финальной промежуточной версии на D: с отчётом.
Native Windows test прошёл после raw-vsync, release 0.2.2+5 и portable ZIP собраны.
Новый installer проверен upgrade 0.2.1→0.2.2, hash match, downgrade blocked,
installed launch, uninstall/library preservation. SHA-256 в VERIFICATION.md.
Подробный пользовательский отчёт: docs/INTERIM_REPORT.ru.md.
Обычный setup оставляет одну кнопку «Установить» (официальный fallback DisableReadyPage),
поэтому тексты исправлены на точный сценарий. Новый installer ещё раз пересобран и
проверен, SHA теперь 7bac31ba3cdf2081d7e41aaa5914bf269d4f382c0966379bcc1c77e5589bf7c9.
Итоговая 0.2.2 установлена через проверенный installer в D:\OptimumTools\OPTIMUM-app,
запущена; библиотека остаётся в прежнем AppData. Не закрывать её без необходимости.
Публикация v0.2.2 завершена, все старые notes уточнены про кнопку «Установить».
Public installer 14 403 171 байт, SHA-256 совпал; releases/latest ведёт на v0.2.2.
Подтверждение: artifacts/release-0.2.2-public.json. Working tree сохранить чистым.
