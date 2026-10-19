import 'library.dart';

enum MusicService { spotify, yandex, soundcloud, audio }

/// A public permalink, never a scraped stream URL or provider credential.
class MusicLink {
  final Uri uri;
  final MusicService service;
  final String kind;
  const MusicLink._(this.uri, this.service, this.kind);

  String get provider => switch (service) {
    MusicService.spotify => 'Spotify',
    MusicService.yandex => 'Яндекс Музыка',
    MusicService.soundcloud => 'SoundCloud',
    MusicService.audio => 'Аудиофайл',
  };
  String get description => kind == 'playlist'
      ? 'Плейлист'
      : kind == 'album'
      ? 'Альбом'
      : 'Трек';

  static MusicLink parse(String input) {
    final value = input.trim();
    final u = Uri.tryParse(value);
    if (value.length > 4096 ||
        u == null ||
        u.scheme != 'https' ||
        u.host.isEmpty ||
        u.userInfo.isNotEmpty ||
        u.port != 443 ||
        value.contains(RegExp(r'[\x00-\x20<>"\\]'))) {
      throw const FormatException(
        'Нужна полная ссылка https:// без логина и пароля',
      );
    }
    final parts = u.pathSegments.where((s) => s.isNotEmpty).toList();
    if (u.host == 'open.spotify.com') {
      if (parts.isNotEmpty &&
          RegExp(r'^intl-[a-z]{2}$').hasMatch(parts.first)) {
        parts.removeAt(0);
      }
      if (parts.length == 2 &&
          ['track', 'playlist', 'album'].contains(parts[0]) &&
          RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(parts[1])) {
        return MusicLink._(
          Uri.https(u.host, '/${parts.join('/')}'),
          MusicService.spotify,
          parts[0],
        );
      }
    } else if ([
      'music.yandex.ru',
      'music.yandex.com',
      'music.yandex.kz',
      'music.yandex.by',
      'music.yandex.uz',
    ].contains(u.host)) {
      if ((parts.length == 2 &&
              ['album', 'track'].contains(parts[0]) &&
              _digits(parts[1])) ||
          (parts.length == 4 &&
              parts[0] == 'album' &&
              _digits(parts[1]) &&
              parts[2] == 'track' &&
              _digits(parts[3])) ||
          (parts.length == 4 &&
              parts[0] == 'users' &&
              RegExp(r'^[a-zA-Z0-9_.@-]{1,100}$').hasMatch(parts[1]) &&
              parts[2] == 'playlists' &&
              _digits(parts[3]))) {
        return MusicLink._(
          Uri.https('music.yandex.ru', '/${parts.join('/')}'),
          MusicService.yandex,
          parts[0] == 'users'
              ? 'playlist'
              : parts.length == 4
              ? 'track'
              : parts[0],
        );
      }
      // Current public playlist identifiers, supported by the service's page player.
      if (parts.length == 2 &&
          parts[0] == 'playlists' &&
          RegExp(r'^(?:lk\.)?[a-zA-Z0-9-]{8,100}$').hasMatch(parts[1])) {
        return MusicLink._(
          Uri.https('music.yandex.ru', '/${parts.join('/')}'),
          MusicService.yandex,
          'playlist',
        );
      }
    } else if ([
      'soundcloud.com',
      'www.soundcloud.com',
      'm.soundcloud.com',
    ].contains(u.host)) {
      if ((parts.length == 2 || (parts.length == 3 && parts[1] == 'sets')) &&
          parts.every((s) => RegExp(r'^[a-zA-Z0-9_-]{1,200}$').hasMatch(s)) &&
          ![
            'discover',
            'stream',
            'you',
            'search',
            'settings',
            'login',
          ].contains(parts[0])) {
        if (u.queryParameters.containsKey('secret_token') ||
            (parts.length > 2 && parts.last.startsWith('s-'))) {
          throw const FormatException(
            'Используйте публичную ссылку SoundCloud',
          );
        }
        return MusicLink._(
          Uri.https('soundcloud.com', '/${parts.join('/')}'),
          MusicService.soundcloud,
          parts.length == 3 ? 'playlist' : 'track',
        );
      }
    } else {
      final ext = u.path.split('.').last.toLowerCase();
      if (audioExtensions.contains(ext) && u.fragment.isEmpty) {
        return MusicLink._(u, MusicService.audio, 'track');
      }
    }
    throw const FormatException(
      'Нужна ссылка на трек, альбом или плейлист. Для короткой ссылки скопируйте полный адрес страницы сервиса.',
    );
  }

  static bool _digits(String s) => RegExp(r'^\d{1,20}$').hasMatch(s);

  Uri get embedUri => switch (service) {
    MusicService.spotify => uri.replace(path: '/embed${uri.path}'),
    MusicService.soundcloud => Uri.https('w.soundcloud.com', '/player/', {
      'url': uri.toString(),
      'auto_play': 'false',
      'visual': 'true',
      'show_user': 'true',
      'show_reposts': 'false',
    }),
    MusicService.yandex => _yandexEmbed,
    MusicService.audio => uri,
  };

  Uri get _yandexEmbed {
    final s = uri.pathSegments;
    if (s.first == 'users') {
      return Uri.https(
        'music.yandex.ru',
        '/iframe/',
        null,
      ).replace(fragment: 'playlist/${s[1]}/${s[3]}');
    }
    if (s.first == 'playlists' || s.first == 'track') {
      // Modern UUID playlists and track-only URLs use the official page player.
      return uri;
    }
    return uri.replace(path: '/iframe${uri.path}');
  }
}

class SavedMusicLink {
  final int id;
  final String title;
  final MusicLink link;
  final String? downloadPath;
  final int? playlistPosition;
  const SavedMusicLink(
    this.id,
    this.title,
    this.link, {
    this.downloadPath,
    this.playlistPosition,
  });
  factory SavedMusicLink.fromMap(Map<String, Object?> row) => SavedMusicLink(
    row['id'] as int,
    row['title'] as String,
    MusicLink.parse(row['url'] as String),
    downloadPath: row['download_path'] as String?,
    playlistPosition: row['playlist_position'] as int?,
  );
}
