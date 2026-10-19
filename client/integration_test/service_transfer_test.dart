import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:optimum/app_model.dart';
import 'package:optimum/data/library.dart';
import 'package:optimum/data/yandex_page.dart';
import 'package:optimum/playback/controller.dart';
import 'package:optimum/ui/app.dart';
import 'package:optimum/ui/music_links.dart';
import 'package:optimum/ui/web_profile.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows: public Yandex full album transfer, preview, track save and native playlist',
    (tester) async {
      JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
      final root = Directory(
        p.join(
          Directory.current.path,
          '..',
          '.data',
          'transfer-test-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      await root.create(recursive: true);
      await WebProfile.initialize(directory: p.join(root.path, 'profile'));
      final store = await LibraryStore.open(
        databasePath: p.join(root.path, 'library.db'),
      );
      final model = AppModel(store);
      final player = PlaybackController(store);
      final boundary = GlobalKey();
      final artifacts = Directory('../artifacts');
      await artifacts.create(recursive: true);
      Future<void> capture(String name) async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          p.join(artifacts.path, name),
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      }

      try {
        await store.setSetting('reduce_motion', 'true');
        await model.refresh();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: OptimumApp(model: model, player: player),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Аккаунты сервисов').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text('Войти и открыть библиотеку').first,
        );
        await tester.tap(find.text('Войти и открыть библиотеку').first);
        ServicePlayerState? state;
        for (var i = 0; i < 80; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          state = tester.state<ServicePlayerState>(find.byType(ServicePlayer));
          if (state.ready) break;
          if (state.error != null) fail(state.error!);
        }
        expect(state!.ready, true);
        final web = state.controller!;
        // Only public pages in an isolated, unauthenticated profile. No user cookies are read.
        await web.loadUrl('https://music.yandex.ru/album/419460');
        await tester.pump(const Duration(seconds: 12));
        await tester.pump(const Duration(milliseconds: 500));
        await capture('windows-transfer-actions.png');
        await tester.tap(find.text('Перенести плейлист'));
        for (
          var i = 0;
          i < 100 && find.text('Перенести 21 треков').evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(find.text('21 треков · полный список проверен'), findsOneWidget);
        expect(await store.playlists(), isEmpty);
        await tester.pump(const Duration(milliseconds: 500));
        await capture('windows-transfer-preview.png');
        await tester.tap(find.text('Перенести 21 треков'));
        await tester.pump(const Duration(seconds: 1));
        expect((await store.playlists()).single.count, 21);
        final album = (await store.playlists()).single;
        final id = album.id;
        final entries = await store.playlistLinks(id);
        expect(entries, hasLength(21));
        expect(
          entries.map((s) => s.playlistPosition),
          List.generate(21, (i) => i),
        );
        expect(entries.first.title, contains('Time Is On My Side'));
        expect(entries.last.title, contains('Wild Horses'));
        await web.loadUrl('https://music.yandex.ru/album/419460/track/1707366');
        await tester.pump(const Duration(seconds: 7));
        await tester.tap(find.text('Добавить текущий трек'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Трек в OPTIMUM'), findsOneWidget);
        await capture('windows-add-service-track.png');
        await tester.tap(find.text('Добавить в OPTIMUM'));
        await tester.pump(const Duration(seconds: 1));
        expect(await store.links(), hasLength(21));
        await web.loadUrl(
          'https://music.yandex.ru/users/music-blog/playlists/1175',
        );
        await tester.pump(const Duration(seconds: 8));
        final publicData =
            jsonDecode(
                  (await web.executeScript(YandexPage.inspectScript)) as String,
                )
                as Map<String, dynamic>;
        expect(publicData['error'], isNull);
        final publicCount =
            (publicData['declaredTracks'] ?? publicData['totalSlots']) as int;
        expect(publicCount, greaterThan(9));
        await tester.tap(find.text('Перенести плейлист'));
        for (
          var i = 0;
          i < 350 &&
              find.text('Перенести $publicCount треков').evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(
          find.text('$publicCount треков · полный список проверен'),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 500));
        await capture('windows-public-playlist-preview.png');
        await tester.tap(find.text('Отмена'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(await store.playlists(), hasLength(1));
        expect(await store.links(), hasLength(21));
        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(ServicePlayer), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Плейлисты').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(album.name).first);
        await tester.pumpAndSettle();
        expect(find.text('Открыть плейлист в сервисе'), findsOneWidget);
        expect(find.text(entries.first.title), findsOneWidget);
        await capture('windows-transferred-playlist.png');
        final local = p.normalize(p.absolute('test/fixtures/audio/signal.wav'));
        final saved = (await store.playlistLinks(id)).first;
        await store.linkDownload(
          saved.id,
          p.absolute('test/fixtures/audio/signal.wav'),
          saved.title,
        );
        await model.refresh();
        expect(model.tracks.single.path, local);
        expect(
          model.links.firstWhere((s) => s.id == saved.id).downloadPath,
          local,
        );
        expect(await File(local).exists(), true);
        await tester.pump(const Duration(milliseconds: 500));
        await player.setVolume(.02);
        await tester.tap(find.text(entries.first.title));
        for (var i = 0; i < 30 && player.current == null; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(player.current?.path, local);
        expect(player.error, isNull);
        expect(find.byType(ServicePlayer), findsNothing);
        expect(tester.takeException(), isNull);
        await File(
          '../artifacts/service-transfer-native-results.json',
        ).writeAsString(
          jsonEncode({
            'source': album.sourceUrl,
            'tracks': 21,
            'ordered_urls': entries.map((s) => s.link.uri.toString()).toList(),
            'preview_before_write': true,
            'saved_track_deduplicated': true,
            'public_playlist': {
              'url': publicData['url'],
              'count': publicCount,
              'complete_preview_and_cancel': true,
            },
            'attached_local_audio_plays': true,
            'real_private_playlist': 'Not tested; isolated public profile only',
          }),
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await player.stop();
        player.dispose();
        model.dispose();
        await model.idle;
        await store.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
