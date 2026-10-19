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
import 'package:optimum/data/music_link.dart';
import 'package:optimum/playback/controller.dart';
import 'package:optimum/ui/app.dart';
import 'package:optimum/ui/music_links.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows: saved link flow, actual WebView2 audio, provider rendering, close stops player',
    (tester) async {
      JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
      final folder = await Directory.systemTemp.createTemp(
        'optimum-web-native-',
      );
      final store = await LibraryStore.open(
        databasePath: p.join(folder.path, 'library.db'),
      );
      final model = AppModel(store);
      final player = PlaybackController(store);
      final boundary = GlobalKey();
      final artifacts = Directory(
        p.join(Directory.current.path, '..', 'artifacts'),
      );
      await artifacts.create(recursive: true);
      final results = <String, Object?>{};
      Future<Object?> tryProviderPlayback(
        ServicePlayerState s,
        String selector,
      ) async {
        await s.controller!.executeScript(
          'window.__optimumMedia=[];const originalPlay=HTMLMediaElement.prototype.play;HTMLMediaElement.prototype.play=function(){this.volume=.08;if(!window.__optimumMedia.includes(this))window.__optimumMedia.push(this);return originalPlay.apply(this,arguments)};document.querySelector(${jsonEncode(selector)})?.click();',
        );
        await tester.pump(const Duration(seconds: 3));
        return s.controller!.executeScript(
          'JSON.stringify({media:[...new Set([...window.__optimumMedia,...document.querySelectorAll("audio,video")])].map(m=>({time:m.currentTime,duration:Number.isFinite(m.duration)?m.duration:null,paused:m.paused,error:m.error?.code??null})),text:document.body.innerText.slice(0,400)})',
        );
      }

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

      Future<ServicePlayerState> state() async {
        for (var i = 0; i < 80; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          final matches = find.byType(ServicePlayer);
          if (matches.evaluate().isNotEmpty) {
            final s = tester.state<ServicePlayerState>(matches);
            if (s.ready) return s;
            if (s.error != null) fail(s.error!);
          }
        }
        throw StateError('WebView2 did not initialize');
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
        await tester.tap(find.text('По ссылке'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).at(1),
          'https://open.spotify.com/track/0Lr4kGOYn9l83EjuK6cZFQ?si=fixture',
        );
        await tester.enterText(find.byType(TextField).last, 'Проверка Spotify');
        await tester.tap(find.text('Сохранить ссылку'));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('Библиотека').first);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('По ссылке'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Проверка Spotify'), findsOneWidget);
        await capture('windows-music-links.png');
        await model.addStudies();
        await player.select(model.tracks, 0);
        expect(player.playing, true);
        await tester.tap(find.text('Проверка Spotify'));
        final s = await state();
        expect(player.playing, false);
        await tester.pump(const Duration(seconds: 10));
        results['spotify'] = await s.controller!.executeScript(
          'JSON.stringify({url:location.href,title:document.title,text:document.body.innerText.slice(0,800)})',
        );
        results['spotify_controls'] = await s.controller!.executeScript(
          'JSON.stringify(Array.from(document.querySelectorAll("button,[role=button]")).map(b=>({text:b.innerText,aria:b.getAttribute("aria-label"),testid:b.getAttribute("data-testid"),cls:b.className})).slice(0,30))',
        );
        await capture('windows-service-spotify.png');
        results['spotify_playback_attempt'] = await tryProviderPlayback(
          s,
          '[aria-label="Слушать"]',
        );

        // Our generated study, not a provider stream: verify actual HTML audio clock.
        final wav = await File('test/fixtures/audio/signal.wav').readAsBytes();
        await s.controller!.loadStringContent(
          '<html><body style="background:#101016;color:white"><p>OPTIMUM · WebView2 audio fixture</p><audio id="audio" controls src="data:audio/wav;base64,${base64Encode(wav)}"></audio></body></html>',
        );
        await tester.pump(const Duration(seconds: 1));
        await s.controller!.executeScript(
          'document.getElementById("audio").volume=0.1;document.getElementById("audio").play()',
        );
        await tester.pump(const Duration(seconds: 2));
        final clock =
            jsonDecode(
                  await s.controller!.executeScript(
                        'JSON.stringify({time:audio.currentTime,paused:audio.paused,duration:audio.duration})',
                      )
                      as String,
                )
                as Map;
        expect(clock['paused'], false);
        expect(clock['time'], greaterThan(.5));
        expect(clock['duration'], closeTo(4, .2));
        results['native_web_audio'] = clock;
        await s.controller!.executeScript('audio.pause()');
        final paused =
            await s.controller!.executeScript('audio.currentTime') as num;
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          await s.controller!.executeScript('audio.currentTime') as num,
          closeTo(paused, .1),
        );

        for (final entry in {
          'soundcloud': 'https://soundcloud.com/forss/flickermood',
          'yandex': 'https://music.yandex.ru/album/419460/track/71263',
        }.entries) {
          await s.controller!.loadUrl(
            MusicLink.parse(entry.value).embedUri.toString(),
          );
          await tester.pump(const Duration(seconds: 10));
          results[entry.key] = await s.controller!.executeScript(
            'JSON.stringify({url:location.href,title:document.title,text:document.body.innerText.slice(0,800)})',
          );
          results['${entry.key}_controls'] = await s.controller!.executeScript(
            'JSON.stringify(Array.from(document.querySelectorAll("button,[role=button],a.playButton")).map(b=>({text:b.innerText,aria:b.getAttribute("aria-label"),title:b.getAttribute("title"),cls:b.className})).slice(0,30))',
          );
          await capture('windows-service-${entry.key}.png');
          results['${entry.key}_playback_attempt'] = await tryProviderPlayback(
            s,
            entry.key == 'soundcloud'
                ? '.playButton'
                : 'button[class*="_iframe-play_"]',
          );
        }
        await tester.pageBack();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ServicePlayer), findsNothing);
        expect(s.mounted, false);
        expect(player.playing, false);
        results['closed_and_local_paused'] = true;
        const direct =
            'https://raw.githubusercontent.com/nobklop/OPTIMUM/main/client/assets/audio/orbit_1.wav';
        await store.saveLink(MusicLink.parse(direct), 'Этюд из HTTPS-ссылки');
        await model.refresh();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Этюд из HTTPS-ссылки'));
        final audioState = await state();
        await tester.tap(find.text('Скачать и сохранить'));
        for (var i = 0; i < 120; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (!audioState.downloading) break;
        }
        expect(audioState.downloaded, true, reason: audioState.downloadMessage);
        final savedFile = (await store.links()).first.downloadPath!;
        final originalStudy = await File(
          'assets/audio/orbit_1.wav',
        ).readAsBytes();
        expect(await File(savedFile).readAsBytes(), originalStudy);
        await capture('windows-direct-download.png');
        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 500));
        final downloadedTrack = model.tracks.firstWhere(
          (t) => t.path == savedFile,
        );
        await player.select([downloadedTrack], 0);
        await tester.pump(const Duration(seconds: 2));
        expect(player.playing, true);
        expect(player.position.inMilliseconds, greaterThan(500));
        expect(player.error, isNull);
        results['direct_https_download'] = {
          'bytes': originalStudy.length,
          'local_decode_position_ms': player.position.inMilliseconds,
        };
        await player.stop();
        // This native fixture is our own downloaded study, not user music.
        await File(savedFile).delete();
        expect(tester.takeException(), isNull);
        await File(
          p.join(artifacts.path, 'music-links-native-results.json'),
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await player.stop();
        player.dispose();
        model.dispose();
        await model.idle;
        await store.close();
        await folder.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
