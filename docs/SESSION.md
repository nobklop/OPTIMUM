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
