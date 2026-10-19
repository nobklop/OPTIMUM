# Проверки OPTIMUM — 20 октября 2026

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
| Flutter unit/widget | 12 passed для 0.2.2: прежние 11 и проверка каждого кадра clock, inactive/reduced motion |
| Цикл Cosmic | Реальные Flutter кадры t=0 и t=90 совпадают; порог: менее 0.001% цветовых каналов отличаются более чем на 1/255 |
| Windows native integration | 1 passed повторно для 0.2.2: настоящий libmpv, WAV decode/duration, pause, seek, next/previous в паузе, repeat-one, auto-next, конец очереди, история после 10 секунд, missing-file/retry, настройки |
| Windows codec matrix | 1 passed: WAV/MP3/FLAC/OGG/M4A (AAC), русские пути, теги, duration/play/pause/seek; повреждённый WAV даёт ошибку, затем валидный MP3 играет |
| Анимация native UI | В активном lifecycle последовательные кадры отличаются; reduced motion даёт одинаковые кадры через секунду. В 0.2 тест явно задаёт resumed, чтобы переключение на редактор/GitHub не замораживало проверку |
| Windows release | Нативная x64 release-сборка, не web/PWA |

## Пакет 0.2.0

Release собран успешно; ProductVersion/FileVersion `0.2.0+3`. Portable:
`dist/OPTIMUM-0.2.0-windows-x64/optimum.exe`, ZIP рядом; SHA-256:
`75571c6e1f1cfd5dd4c4a5627d3aa1fe228bb6d54262b4b4b890a29f6a3b3fde`.
Старые пакеты сохранены. Backend после 17 passed/ruff не изменялся.

## 0.2.1: внешний вид и установщики

3 затронутых UI/loop tests прошли: 1440×960, 390×844, совпадение начала/конца
полного цикла с новым HeroSkyPainter. Analyzer — no issues. Windows native UI/audio
test повторно passed. Release `0.2.1+4` собран, native кадр windows-cosmic.png обновлён.
Portable ZIP SHA-256: `34d05ea668929bc9a8906a9ff77ce0e2a2a9a33b08b529de75c83791d02ab815`.
Installer SHA-256: `fa1abcf8408349dd0845d841743350a5c3669fb0fa083e12fa37171090621342`.

Inno Setup 6.7.3: собраны 0.1.0 / 0.1.1 / 0.2.0 / 0.2.1. Проверена настоящая
чистая установка и последовательные обновления без admin; payload каждого файла
совпал по SHA-256; движок скачан с upstream, archive/DLL hashes совпали. Downgrade
блокируется до изменения файлов. Установленное приложение запустилось и отвечало.
Uninstall exit 0; программа/регистрация удалены, пользовательская библиотека сохранена.
Логи и JSON: artifacts/installer-tests/. Без автоматизации кликов системного UI.
Первый тест не прошёл из-за RedirectionGuard на junction D:\OptimumTools\workspace:
исправлен тестовый путь на настоящий workspace; защиту установщика не отключали.
После добавления полных Flutter engine notices пакеты пересобраны и проверены снова.

В 0.2.1 пользователь сообщил о дёргании анимации и попросил исправить на заключительном
этапе. Исправление и профильные замеры выполнены в 0.2.2, см. ниже.

## 0.2.2: равномерность движения

Analyzer — no issues; полный набор Flutter tests — 12 passed. Profile benchmark
настоящего Windows UI без пользовательской базы: motion 30.06→69.12 Гц,
интервал p95 45.002→20.001 мс; raster p95 15.862→15.437 мс, build p95 1.175→1.240 мс.
По 6 секунд после 2 секунд прогрева, lifecycle явно active; это локальный замер,
не обещание FPS для всех устройств. Подробности и воспроизведение — PERFORMANCE.md.
Кэш туманностей, 90-секундный период, inactive и reduced motion сохранены.
Windows native audio/UI test повторно прошёл после изменения clock; release 0.2.2+5
собран. Installer: чистая установка 0.2.1 → обновление 0.2.2, все payload hashes,
downgrade guard, запуск и uninstall с сохранением библиотеки прошли.
Portable ZIP SHA-256: `97ff487c8b846b5a04ce689905b29146a9056986b13388a444fffff1364298ab`.
Installer SHA-256: `7bac31ba3cdf2081d7e41aaa5914bf269d4f382c0966379bcc1c77e5589bf7c9`.
При обычном запуске Inno показывает одну кнопку «Установить», даже когда страницы
welcome/dir/ready отключены: fallback описан в официальном DisableReadyPage.
Это проверено настоящим обычным запуском; описания уточнены. После правки текста
INSTALLATION новый 0.2.2 installer пересобран и ещё раз проверен install/launch/uninstall.
Финальная версия установлена в D:\OptimumTools\OPTIMUM-app, зарегистрирована 0.2.2,
запущена и отвечает. Публичный EXE 14 403 171 байт скачан обратно, SHA совпал;
releases/latest перенаправляет на v0.2.2. Все пять версий имеют EXE + SHA assets.

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
- Signing отсутствует. Для libmpv полный corresponding source audit ещё не закрыт:
  публичные установщики получают движок из upstream, локальные ZIP не публикуются.

## 0.3.0 — ссылки и аккаунты сервисов (20 октября 2026)

- Analyzer: no issues. 17 unit/widget passed; после изменения cleanup отдельно
  повторены 5 link/download tests. Layout 1440×960 и 390×844 включает аккаунты.
- SQLite v1→v3/v2→v3: снимок до миграции, сохранность данных, rollback при ошибке.
  JSON v2: ссылки и download paths, идемпотентный merge, v1 backward input.
  Удаление локального трека очищает download_path через FK; файл не удаляется.
- Windows native music_links_test passed: UI сохранения, остановка libmpv перед WebView,
  все три настоящих embeds, HTML audio play/pause/time/duration. Авторский WAV
  скачан по реальной HTTPS-ссылке (1344044 bytes), байты совпали; сохранённый файл
  декодирован libmpv с растущей позицией около 2 секунд без URL в источнике плеера.
- Нажаты реальные элементы play в плеерах: Spotify video-preview 29.552 s,
  time 0.480 s/paused=false; SoundCloud 213.886 s, time 2.950 s/paused=false;
  Яндекс preview 30.041 s, time 1.730 s/paused=false. Ошибок media element не было.
  Это проверка старта публичных примеров без входа, не полный каталог/дослушивание.
- Windows native service_accounts_test passed, повторён после обработки отменённой
  навигации: официальные страницы сервиса/входа открылись; Яндекс — телефон/QR,
  Spotify — email, SoundCloud — sign-in и стандартный cookie prompt. Подтверждение
  cookies/2FA и реальные аккаунты не использовались; пароли не запрашивались.
  Тестовый профиль отдельный .data/account-test-*; только на своём HTTPS virtual
  host проверены cookie/localStorage после уничтожения и повторного создания окна.
  Автологин реального аккаунта после полного перезапуска ещё не проверен.
- Windows native windows_player_test passed повторно: прежнее декодирование, пауза,
  seek, очередь/повтор/конец/история, ошибки и настройки. Codec matrix ранее passed,
  адаптер и декодер в этом этапе не изменялись. Backend: 17 passed, ruff clean.
- Реальные кадры: windows-music-links.png, windows-service-{spotify,soundcloud,yandex}.png,
  windows-direct-download.png, windows-service-accounts.png, windows-login-*.png.
  Результаты: music-links-native-results.json и service-accounts-native-results.json.

Ограничения: API-ключей нет; страницы сервисов сохраняют их политику входа/страны/
подписки. Google/Apple login и защищённое full playback во WebView могут быть недоступны.
Локальная база не получает состав сервисных плейлистов/лайки. Скачивание доступно для
прямых HTTPS-аудиофайлов; обычные Spotify/Яндекс/SoundCloud permalink не являются MP3.
Windows 11/WebView2 проверены; мобильный модуль не проверен. Runtime не включён в EXE.

Release 0.3.0+6 собран Windows x64. Installer: 14602173 bytes, SHA-256
`0ac1c58bdcabf26d98f0310ad46f5379947acef6e8ff09f014b9b44adc488a49`.
Локальный portable ZIP SHA-256:
`fda7e0ee172a5d4aec0a8e6d5ae2ab0b226ac0ec5eb38c8d636f3112777a6548`;
он не публикуется из-за прежнего corresponding-source audit libmpv.

Проверено реальное обновление установленного приложения 0.2.2→0.3.0 в
D:\OptimumTools\OPTIMUM-app: все 35 payload files по SHA-256, отдельный engine hash,
регистрация uninstall 0.3.0, запущенный процесс отвечает. SQLite v2→v3, integrity=ok;
количества и SHA-256 всех прежних строк библиотеки совпали до/после. Есть ручной
снимок до установки и автоматический before-v3. Проверка через 3 секунды сначала
опередила холодный старт: миграция завершилась примерно через 6 секунд, повторная
проверка состояния прошла. Это не выдаётся за сбой миграции или мгновенный запуск.
Артефакты: upgrade-0.3.0.log/json и upgrade-0.3.0-data-after.json.
Яндекс collection URL дополнительно проверен публичным HTTP: /collection вернул 200,
/home перенаправлял на корень, поэтому кнопка использует /collection.

Публикация: tag v0.3.0 = 03819e8, latest. Публичный EXE повторно получен без
авторизации, 14602173 bytes и SHA-256 совпали с локальным установщиком; опубликованный
checksum совпал. /releases/latest ведёт на /releases/tag/v0.3.0.
Артефакт release-0.3.0-public.json. Тег исходников не менялся после публикации.

## Этап 0.4.0 — перенос треков и полных списков Яндекса

- Flutter analyzer: no issues. 19 unit/widget tests passed; backend 17 passed,
  ruff clean. После последних изменений повторены затронутые проверки.
- Windows native `service_transfer_test.dart`: passed. Настоящий WebView2, отдельный
  профиль без входа. Публичный альбом /album/419460: полный предпросмотр 21 трека
  (23 виртуальные позиции с двумя заголовками дисков), до подтверждения база пуста;
  после подтверждения нативный плейлист с позициями 0–20, правильными первым/последним
  треками. Проверено добавление текущего трека без дубля и отображение списка в OPTIMUM.
- Настоящий публичный плейлист «Громкие новинки месяца», старый URL
  /users/music-blog/playlists/1175 → /playlists/2111e2b6-587d-a600-2fea-54df7c314477:
  полный предпросмотр 100 треков. Отмена после чтения не добавила ни плейлист, ни ссылки.
- Привязка собственного WAV со смешанными разделителями пути: нормализация пути,
  обновление модели и запуск из импортированного списка в настоящем локальном плеере;
  путь выбран верно, ошибки нет, веб-плеер не открывается. Исправлены сравнение путей
  и использование свежей связи файла при ещё не обновившейся строке списка.
- Domain/SQLite: 1295 позиций с повтором, точный порядок, повторный импорт в тот же
  плейлист с сохранением пользовательского имени, rollback при искусственной ошибке,
  обновление состава, удаление одной повторной позиции без удаления ссылки/файла.
  JSON v3: порядок/повторы, импорт в пустую базу, объединение независимо импортированного
  того же источника, повторное восстановление без дублей. Старые JSON v1/v2 читаются.
- Миграции v1→v4 и v3→v4, before-v4 snapshots, целостность и откат ошибки проверены.
  Reader отвергает смену источника, несовпадение начального числа треков и отмену;
  прокручивает первую недостающую позицию, исключает placeholders, восстанавливает scroll.
- Реальные кадры Flutter: windows-transfer-actions.png, windows-transfer-preview.png,
  windows-public-playlist-preview.png, windows-add-service-track.png,
  windows-transferred-playlist.png. Результат: service-transfer-native-results.json.

При исследовании маленького viewport обнаружены пропуски лениво загружаемых строк;
последовательная прокрутка заменена переходом к первой непрочитанной позиции.
Один повторный Debug-запуск оборвался до UI из-за старого media_kit NativeReferenceHolder
при повторном PID; итоговый тест прошёл с отдельным TEMP. Этот механизм зависимости
в release отключён (kDebugMode). Пользовательская база и профиль в тестах не использовались.

Пользователь подтвердил стабильный вход в Яндекс на 0.3. Его приватный список из
1295 треков не переносился автоматически в тестах. Подтверждён реальный публичный
список на 100 треков и отдельный синтетический тест на 1295; это разные проверки.
Код входа и WebPlayer profile не сбрасываются. Полное воспроизведение записей зависит
от сервиса/подписки; автоматическое скачивание защищённого аудио и полный перенос
плейлистов Spotify/SoundCloud не реализованы. Прямые HTTPS-аудиозагрузки сохранены.
Разметка Яндекса может измениться; неизвестный/неполный список не сохраняется.

Windows release 0.4.0+7 собран. Installer 14626421 bytes, SHA-256:
`1beb5362fc7f431c8b6b3f082ef5cbc420b47336a1fc4d5a3a54ae3e821f8a6b`.
Локальный portable ZIP:
`e046ed460cb3be53ff5363606652e78d8a0de10302156faf252956688547de65`;
он не публикуется по прежнему ограничению corresponding-source audit libmpv.
Проверено реальное обновление 0.3.0→0.4.0 в D:\OptimumTools\OPTIMUM-app:
35 payload hashes, engine hash и registry version совпали; приложение запущено и
отвечает. SQLite v3→v4, integrity=ok; количества и digest всех прежних столбцов/строк
tracks/playlists/playlist_tracks/history/settings/music_links совпали до/после.
Ручной снимок и автоматический before-v4 сохранены; папка WebPlayer остаётся на месте.
Новый автоматический вход реального аккаунта после обновления не проверялся кодом.
Артефакты: upgrade-0.4.0.log/json и upgrade-0.4.0-data-after.json.
