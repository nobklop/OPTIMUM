# План разработки

Каждый этап: код-ревью → релевантные тесты → сценарии → документация → Git checkpoint.
Текущий статус подтверждается в `docs/VERIFICATION.md`; этот список не заменяет тесты.

1. **Основа и Windows-прототип (реализован, проверки в VERIFICATION).** Flutter runners Windows/Android/iOS,
   FastAPI health, локальное аудио, SQLite, Cosmic, тестируемое ядро Together.
2. **Cosmic (базовый интерфейс и бесшовная анимация реализованы).** Расширить проверки доступности, переходов,
   reduced motion, клавиатуру, настоящие кадры приложения.
3. **Аудио.** Windows-матрица MP3/FLAC/WAV/OGG/M4A и повреждённый WAV проверены.
   Далее: audio focus,
   `audio_service`, фон/lock-screen, длительное воспроизведение, ресурсы.
4. **Библиотека.** Плейлисты, обложки, JSON export/restore и миграция с backup реализованы.
   Далее: большие каталоги, прогресс/отмена импорта, восстановление путей.
5. **Аккаунты.** Supabase Auth, PostgreSQL migrations, RLS positive/negative tests,
   secure storage, cloud sync, экспорт и удаление.
6. **Социальное.** Друзья, приглашения, privacy, блокировки, жалобы, moderation.
7. **Together — приоритетный крупный модуль.** Authenticated WSS, durable room state,
   создание/вход/leave/transfer, two-client integration tests.
8. **Синхронизация.** Реальный клиентский transport, clock estimate, мягкая коррекция,
   измерения двух аудиовыходов; latency/loss/reconnect/clock-skew fault injection.
9. **Очередь и чат.** Голосования, permissions, history, общие плейлисты, чат, reactions.
10. **Моя волна.** Explainable local ranker, реакции, тесты адаптации/разнообразия.
11. **Совместная волна.** Fair exposure, room modes, group preference tests.
12. **Альбомы настроения.** Durable worker каждые 5 часов, timezone/retry/idempotence tests.
13. **Интеграции.** В 0.3 добавлены ссылки Spotify / Яндекс / SoundCloud без API-ключей,
    официальные веб-плееры в Windows, сохранение ссылок и загрузка прямых аудиофайлов.
    Также добавлены официальный вход/личная библиотека сервисов внутри WebView,
    постоянный профиль и общая сессия для страниц и embeds — по выбору пользователя.
    Веб-плеер сохраняет ограничения сервиса. Далее: перенос состава плейлистов через
    разрешённый экспорт/интеграцию, мобильный WebView, управление очередью источников.
    Защищённые офлайн-кэши и скрытые endpoints не импортируются.
14. **Windows/Android.** Release profiling, installer/signing, battery/memory/network checks.
15. **iOS.** macOS/Xcode, signing, реальные устройства, interruptions/background, release QA.

## Критерий готовности Together

Два физических устройства с законным доступом к записи; одинаковая очередь и revision;
измеренная рассинхронизация при play/pause/seek/next, ограниченных latency/jitter/loss;
восстановление после разрыва, рестарта и смены владельца; отсутствие неавторизованного
доступа, дубликатов команд и утечки приватных путей/токенов. Только после этого
модуль называется готовым совместным прослушиванием.
