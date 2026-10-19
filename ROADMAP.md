# План разработки

Каждый этап: код-ревью → релевантные тесты → сценарии → документация → Git checkpoint.
Текущий статус подтверждается в `docs/VERIFICATION.md`; этот список не заменяет тесты.

1. **Основа и Windows-прототип (реализован, проверки в VERIFICATION).** Flutter runners Windows/Android/iOS,
   FastAPI health, локальное аудио, SQLite, Cosmic, тестируемое ядро Together.
2. **Cosmic (базовый интерфейс и бесшовная анимация реализованы).** Расширить проверки доступности, переходов,
   reduced motion, клавиатуру, настоящие кадры приложения.
3. **Аудио.** Матрица MP3/FLAC/WAV/OGG, повреждённые файлы, audio focus,
   `audio_service`, фон/lock-screen, длительное воспроизведение, ресурсы.
4. **Библиотека.** Плейлисты, обложки, большие каталоги, безопасный импорт,
   восстановление/экспорт локальной базы, миграции.
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
13. **Интеграции.** Только разрешённые API; metadata import и честные unavailable states.
14. **Windows/Android.** Release profiling, installer/signing, battery/memory/network checks.
15. **iOS.** macOS/Xcode, signing, реальные устройства, interruptions/background, release QA.

## Критерий готовности Together

Два физических устройства с законным доступом к записи; одинаковая очередь и revision;
измеренная рассинхронизация при play/pause/seek/next, ограниченных latency/jitter/loss;
восстановление после разрыва, рестарта и смены владельца; отсутствие неавторизованного
доступа, дубликатов команд и утечки приватных путей/токенов. Только после этого
модуль называется готовым совместным прослушиванием.
