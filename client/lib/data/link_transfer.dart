import 'music_link.dart';

class ServiceTrack {
  final MusicLink link;
  final String title;
  const ServiceTrack(this.link, this.title);
  factory ServiceTrack.fromMap(Map<String, dynamic> row) {
    final link = MusicLink.parse(
      row['url'] is String ? row['url'] as String : '',
    );
    final title = row['title'];
    if (link.kind != 'track' ||
        title is! String ||
        title.trim().isEmpty ||
        title.length > 160 ||
        title.contains('\u0000')) {
      throw const FormatException(
        'Не удалось прочитать название или ссылку трека',
      );
    }
    return ServiceTrack(link, title.trim());
  }
}

/// Only an explicitly complete, ordered selection can become a native playlist.
class PlaylistTransfer {
  final MusicLink source;
  final String name;
  final int expectedCount;
  final List<ServiceTrack> tracks;
  PlaylistTransfer(
    this.source,
    this.name,
    this.expectedCount,
    List<ServiceTrack> tracks,
  ) : tracks = List.unmodifiable(tracks);

  void validate() {
    if (!['playlist', 'album'].contains(source.kind) ||
        name.trim().isEmpty ||
        name.length > 80 ||
        name.contains('\u0000') ||
        expectedCount < 1 ||
        expectedCount > 10000 ||
        tracks.length != expectedCount ||
        tracks.any(
          (t) =>
              t.link.kind != 'track' ||
              t.link.service != source.service ||
              t.title.trim().isEmpty ||
              t.title.length > 160 ||
              t.title.contains('\u0000'),
        )) {
      throw const FormatException(
        'Полный состав плейлиста не подтверждён. Библиотека не изменена',
      );
    }
  }
}
