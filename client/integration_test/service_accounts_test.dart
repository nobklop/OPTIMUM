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
import 'package:optimum/data/service_account.dart';
import 'package:optimum/playback/controller.dart';
import 'package:optimum/ui/app.dart';
import 'package:optimum/ui/music_links.dart';
import 'package:optimum/ui/web_profile.dart';
import 'package:path/path.dart' as p;
import 'package:webview_windows/webview_windows.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows: official account pages, login forms, persistent isolated browser session',
    (tester) async {
      JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
      final root = Directory(
        p.join(
          Directory.current.path,
          '..',
          '.data',
          'account-test-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      await root.create(recursive: true);
      final profile = p.join(root.path, 'profile');
      await WebProfile.initialize(directory: profile);
      final store = await LibraryStore.open(
        databasePath: p.join(root.path, 'library.db'),
      );
      final model = AppModel(store);
      final player = PlaybackController(store);
      final boundary = GlobalKey();
      final artifacts = Directory(
        p.join(Directory.current.path, '..', 'artifacts'),
      );
      await artifacts.create(recursive: true);
      final results = <String, Object?>{
        'profile': profile,
        'real_account_login':
            'Not performed: no credentials requested or entered',
      };
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

      Future<ServicePlayerState> open(int index) async {
        await tester.ensureVisible(
          find.text('Войти и открыть библиотеку').at(index),
        );
        await tester.tap(find.text('Войти и открыть библиотеку').at(index));
        for (var i = 0; i < 80; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          final s = tester.state<ServicePlayerState>(
            find.byType(ServicePlayer),
          );
          if (s.ready) return s;
          if (s.error != null) fail(s.error!);
        }
        throw StateError('Account WebView did not initialize');
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
        await capture('windows-service-accounts.png');
        for (var i = 0; i < ServiceAccount.all.length; i++) {
          final account = ServiceAccount.all[i];
          final state = await open(i);
          await tester.pump(const Duration(seconds: 7));
          results['${account.name}_library'] = await state.controller!
              .executeScript(
                'JSON.stringify({url:location.origin+location.pathname,title:document.title,text:document.body.innerText.slice(0,350)})',
              );
          await tester.tap(find.text('Войти / сменить аккаунт'));
          await tester.pump(const Duration(seconds: 8));
          results['${account.name}_login'] = await state.controller!.executeScript(
            'JSON.stringify({url:location.origin+location.pathname,title:document.title,inputTypes:[...document.querySelectorAll("input")].map(i=>i.type),text:document.body.innerText.slice(0,500)})',
          );
          await capture('windows-login-${account.service.name}.png');
          expect(tester.takeException(), isNull);
          await tester.pageBack();
          await tester.pump(const Duration(milliseconds: 400));
        }
        // Only synthetic state on our own local HTTPS virtual host; no provider cookies are read.
        final fixture = Directory(p.join(root.path, 'fixture'));
        await fixture.create();
        await File(p.join(fixture.path, 'index.html')).writeAsString(
          '<!doctype html><html><body>OPTIMUM session fixture</body></html>',
        );
        var state = await open(0);
        await state.controller!.addVirtualHostNameMapping(
          'optimum-session.test',
          fixture.path,
          WebviewHostResourceAccessKind.denyCors,
        );
        await state.controller!.loadUrl(
          'https://optimum-session.test/index.html',
        );
        await tester.pump(const Duration(seconds: 1));
        await state.controller!.executeScript(
          'document.cookie="optimum_session=fixture; Max-Age=3600; Secure; SameSite=Lax";localStorage.setItem("optimum_fixture","retained")',
        );
        await tester.pageBack();
        await tester.pump(const Duration(seconds: 1));
        state = await open(1);
        await state.controller!.addVirtualHostNameMapping(
          'optimum-session.test',
          fixture.path,
          WebviewHostResourceAccessKind.denyCors,
        );
        await state.controller!.loadUrl(
          'https://optimum-session.test/index.html',
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          await state.controller!.executeScript('document.cookie'),
          contains('optimum_session=fixture'),
        );
        expect(
          await state.controller!.executeScript(
            'localStorage.getItem("optimum_fixture")',
          ),
          'retained',
        );
        results['synthetic_session_survived_reopening'] = true;
        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(ServicePlayer), findsNothing);
        expect(tester.takeException(), isNull);
        await File(
          p.join(artifacts.path, 'service-accounts-native-results.json'),
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await player.stop();
        player.dispose();
        model.dispose();
        await model.idle;
        await store.close();
        // Native browser may hold test profile files until the process exits.
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
