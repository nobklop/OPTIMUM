import 'dart:async';
import 'dart:io';
import 'music_link.dart';

/// Resolve only known provider share domains; never scrape hidden media endpoints.
Future<MusicLink> resolveMusicLink(String input) async {
  if (input.length > 4096) {
    throw const FormatException('Ссылка длиннее 4096 символов');
  }
  final uri = Uri.tryParse(input.trim());
  final allowed = switch (uri?.host) {
    'spotify.link' ||
    'spoti.fi' => {'spotify.link', 'spoti.fi', 'open.spotify.com'},
    'on.soundcloud.com' || 'snd.sc' => {
      'on.soundcloud.com',
      'snd.sc',
      'soundcloud.com',
      'www.soundcloud.com',
      'm.soundcloud.com',
    },
    _ => <String>{},
  };
  if (allowed.isEmpty) return MusicLink.parse(input);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    return await (() async {
      var current = uri!;
      for (var i = 0; i < 6; i++) {
        if (current.scheme != 'https' ||
            current.userInfo.isNotEmpty ||
            current.port != 443 ||
            !allowed.contains(current.host)) {
          throw const FormatException(
            'Короткая ссылка ведёт за пределы сервиса',
          );
        }
        if ([
          'open.spotify.com',
          'soundcloud.com',
          'www.soundcloud.com',
          'm.soundcloud.com',
        ].contains(current.host)) {
          return MusicLink.parse(current.toString());
        }
        final request = await client.getUrl(current);
        request.followRedirects = false;
        final response = await request.close();
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.listen((_) {}).cancel();
        if (![301, 302, 303, 307, 308].contains(response.statusCode) ||
            location == null) {
          throw const FormatException(
            'Короткая ссылка не раскрылась. Скопируйте полный адрес страницы сервиса',
          );
        }
        current = current.resolve(location);
      }
      throw const FormatException('Слишком много перенаправлений');
    })().timeout(const Duration(seconds: 20));
  } finally {
    client.close(force: true);
  }
}
