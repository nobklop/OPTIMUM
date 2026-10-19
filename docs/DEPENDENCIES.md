# Проверка upstream и лицензий — 19 октября 2026

Изучены README/официальные страницы перечисленных проектов. GitHub REST API
в этом окружении вернул HTTP 403, поэтому API не использовался как подтверждение.
Ни один сторонний набор skills не устанавливался. Версии клиента зафиксированы
в pubspec.yaml/pubspec.lock, сервера — в backend/requirements.lock.

| Проект и первичный источник | Лицензия / совместимость | Решение этапа 1 |
|---|---|---|
| [Flutter](https://github.com/flutter/flutter) | BSD-3-Clause, общий Dart-клиент, нативные runners | Flutter stable 3.47.7 / Dart 3.13.5 |
| [just_audio](https://github.com/ryanheise/just_audio/tree/minor/just_audio) | Apache-2.0; Windows требует отдельный backend; API 0.10 использует errorStream | Установлен 0.10.6 |
| [audio_service](https://github.com/ryanheise/audio_service) | MIT, background/lock-screen требуют платформенной настройки | Отложен до этапа мобильного фона |
| [just_audio_media_kit](https://github.com/Pato05/just_audio_media_kit) | Unlicense, media_kit — MIT; native libs лицензируются отдельно; shuffleOrder игнорируется | 2.1.0 + windows_audio 1.0.9, порядок задаёт приложение |
| [Supabase](https://github.com/supabase/supabase) | Apache-2.0 для главного repo; сервисные компоненты имеют свои лицензии | Архитектура Auth/PostgreSQL, без подключения и ключей |
| [Troi](https://github.com/metabrainz/troi-recommendation-playground) | GPL-2.0, Python recommendation pipelines | Будущий отдельный адаптер, не в клиентском binary |
| [ListenBrainz](https://github.com/metabrainz/listenbrainz-server) | GPL-2.0-or-later для server; API/data terms проверяются отдельно | Будущее API, сервер не установлен |
| [MusicBrainz](https://github.com/metabrainz/musicbrainz-server) | GPL-2.0-or-later для server; metadata/data имеют отдельные условия | Будущее metadata API, не источник аудио |
| [Spotipy](https://github.com/spotipy-dev/spotipy) | MIT; Spotify OAuth/scopes и актуальные ограничения API | Будущий metadata import, не загрузчик аудио |
| [Essentia](https://github.com/MTG/essentia) | AGPL-3.0; корректный upstream MTG/essentia, а не essentia/essentia | Не установлен; до интеграции решить лицензирование |
| [Playwright MCP](https://github.com/microsoft/playwright-mcp) | Apache-2.0; браузерный automation | Не нужен для native Flutter; Flutter tests вместо браузерных |
| [Superpowers](https://github.com/obra/superpowers) | MIT, набор development skills, не runtime | README изучен, набор не устанавливался |
| [Redis](https://github.com/redis/redis/blob/unstable/LICENSE.txt) | Для Redis 8+ выбор RSALv2 / SSPLv1 / AGPLv3, не прежняя BSD | Отложен до нескольких серверных процессов |
| [FastAPI](https://github.com/fastapi/fastapi) | MIT, ASGI/WebSocket, Python | 0.148.0; только реализованные endpoints |
| [animations](https://github.com/flutter/packages/tree/main/packages/animations) | BSD-3-Clause, актуальное расположение flutter/packages | Встроенных Flutter transitions достаточно |

Дополнительно: audio_metadata_reader 1.8.1 — MIT; file_picker 13.1.0 — новый
статический API (pickFiles возвращает List, прежнего .platform больше нет);
sqflite / sqflite_common_ffi / path_provider — локальная инфраструктура.
Manrope — SIL Open Font License, полный текст `client/assets/fonts/OFL.txt`.
Проверены реальные downloaded package sources при настройке API.

Adapter `just_audio_media_kit` закреплён локально как 2.1.0+optimum.1 в third_party/.
Обнаруженные на Windows ошибки `osc` и disk cache исправлены точечно, без изменения
Pub cache. Изменения и исходная лицензия сохранены рядом с кодом в OPTIMUM_PATCH.md.

В приложении есть экран «Лицензии компонентов». Перед публичным распространением
нужно дополнить notices для точного Windows libmpv/FFmpeg binary, проверить build
configuration и выполнить соответствующие требования к исходникам. Текущая версия
binary предназначена для локальной проверки на этой машине; исходники опубликованы
в github.com/nobklop/OPTIMUM. Публичные binary releases пока не публиковались.

Три аудиоэтюда синтезированы воспроизводимым скриптом `scripts/generate_studies.py`:
никаких чужих записей, samples или коммерческого каталога. Изображения планет,
звёзды и launcher mark построены кодом проекта.

Codec fixtures — первые 4 секунды собственного orbit_1.wav в пяти форматах.
`scripts/generate_codec_fixtures.py` использует FFmpeg только как инструмент
разработки (imageio-ffmpeg 0.6.0 в D:\OptimumTools\media-fixtures); этот encoder
не добавлен в зависимости и не включён в приложение.
