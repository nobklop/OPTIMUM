import 'music_link.dart';

/// Official website sessions. These are not OPTIMUM OAuth/API connections.
class ServiceAccount {
  final MusicService service;
  final String name, libraryUrl, loginUrl;
  const ServiceAccount(this.service, this.name, this.libraryUrl, this.loginUrl);
  Uri get libraryUri => Uri.parse(libraryUrl);
  Uri get loginUri => Uri.parse(loginUrl);
  static const all = [
    ServiceAccount(
      MusicService.yandex,
      'Яндекс Музыка',
      'https://music.yandex.ru/collection',
      'https://passport.yandex.ru/auth?retpath=https%3A%2F%2Fmusic.yandex.ru%2Fcollection',
    ),
    ServiceAccount(
      MusicService.soundcloud,
      'SoundCloud',
      'https://soundcloud.com/you/library',
      'https://soundcloud.com/login',
    ),
    ServiceAccount(
      MusicService.spotify,
      'Spotify',
      'https://open.spotify.com/collection/playlists',
      'https://accounts.spotify.com/login?continue=https%3A%2F%2Fopen.spotify.com%2Fcollection%2Fplaylists',
    ),
  ];
}
