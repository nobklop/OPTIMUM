import 'package:flutter/material.dart' hide RepeatMode;
import '../app_model.dart';
import '../data/library.dart';
import '../playback/model.dart';
import '../playback/queue.dart';
import 'cosmos.dart';

String timeLabel(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

class OptimumApp extends StatelessWidget {
  final AppModel model;
  final PlaybackModel player;
  const OptimumApp({super.key, required this.model, required this.player});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OPTIMUM',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: ink,
      fontFamily: 'Manrope',
      colorScheme: const ColorScheme.dark(
        primary: paper,
        onPrimary: ink,
        surface: panel,
        onSurface: paper,
        secondary: muted,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -.5,
        ),
      ),
      dividerColor: const Color(0xFF24242B),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: muted),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
      ),
    ),
    home: Workspace(model: model, player: player),
  );
}

class Workspace extends StatefulWidget {
  final AppModel model;
  final PlaybackModel player;
  const Workspace({super.key, required this.model, required this.player});
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  int page = 0, filter = 0;
  int? selectedPlaylist;
  String search = '';
  AppModel get model => widget.model;
  PlaybackModel get player => widget.player;
  static const titles = [
    'Главная',
    'Библиотека',
    'Плейлисты',
    'Together',
    'Настройки',
  ];
  static const icons = [
    Icons.blur_on_rounded,
    Icons.library_music_outlined,
    Icons.queue_music_rounded,
    Icons.people_outline_rounded,
    Icons.tune_rounded,
  ];
  void navigate(int value) {
    setState(() {
      page = value;
      selectedPlaylist = null;
      search = '';
    });
    model.refresh();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      final wide = MediaQuery.sizeOf(context).width >= 900;
      final reduced =
          model.reduceMotion || MediaQuery.disableAnimationsOf(context);
      return Scaffold(
        body: SafeArea(
          child: Cosmos(
            reduced: reduced,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (wide) _sidebar(),
                      Expanded(
                        child: Column(
                          children: [
                            _header(wide),
                            if (model.busy)
                              const LinearProgressIndicator(minHeight: 2),
                            if (model.message != null)
                              Container(
                                color: panel,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(model.message!, maxLines: 3),
                                    ),
                                    IconButton(
                                      onPressed: model.dismissMessage,
                                      icon: const Icon(Icons.close),
                                      tooltip: 'Закрыть сообщение',
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: reduced
                                    ? Duration.zero
                                    : const Duration(milliseconds: 220),
                                child: KeyedSubtree(
                                  key: ValueKey('$page-$selectedPlaylist'),
                                  child: _content(wide),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                PlayerBar(player: player, model: model, onExpand: _fullPlayer),
                if (!wide)
                  NavigationBar(
                    height: 64,
                    backgroundColor: panel,
                    selectedIndex: page,
                    onDestinationSelected: navigate,
                    destinations: List.generate(
                      titles.length,
                      (i) => NavigationDestination(
                        icon: Icon(icons[i], size: 21),
                        label: titles[i],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _sidebar() => Container(
    width: 218,
    decoration: const BoxDecoration(
      color: Color(0xDD08080B),
      border: Border(right: BorderSide(color: Color(0xFF202026))),
    ),
    padding: const EdgeInsets.fromLTRB(22, 32, 18, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.adjust_rounded, size: 29, color: paper),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'OPTIMUM',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'МУЗЫКА НА ВАШЕЙ ОРБИТЕ',
          style: TextStyle(fontSize: 8, color: muted, letterSpacing: 1.5),
        ),
        const SizedBox(height: 48),
        ...List.generate(
          titles.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: page == i ? const Color(0xFF1B1B22) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 13),
                leading: Icon(
                  icons[i],
                  color: page == i ? paper : muted,
                  size: 21,
                ),
                title: Text(
                  titles[i],
                  style: TextStyle(
                    color: page == i ? paper : muted,
                    fontSize: 13,
                  ),
                ),
                onTap: () => navigate(i),
              ),
            ),
          ),
        ),
        const Spacer(),
        const Divider(),
        const SizedBox(height: 18),
        const Row(
          children: [
            Icon(Icons.offline_bolt_outlined, size: 17, color: muted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Локальное пространство',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Версия 0.1 · первый сигнал',
          style: TextStyle(fontSize: 10, color: muted),
        ),
      ],
    ),
  );

  Widget _header(bool wide) => Padding(
    padding: EdgeInsets.fromLTRB(wide ? 36 : 20, 22, wide ? 36 : 20, 18),
    child: Row(
      children: [
        if (!wide) ...[
          const Icon(Icons.adjust, size: 26),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: TextField(
            onChanged: (value) => setState(() {
              search = value;
              page = 1;
              selectedPlaylist = null;
            }),
            decoration: const InputDecoration(
              hintText: 'Найти в своей музыке',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        if (wide) ...[
          const SizedBox(width: 28),
          const Icon(Icons.person_outline, size: 20, color: muted),
          const SizedBox(width: 9),
          const Text(
            'Локальный профиль',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ],
    ),
  );

  Widget _content(bool wide) {
    if (page == 1) return _library();
    if (page == 2) return _playlists();
    if (page == 3) return _together();
    if (page == 4) return _settings();
    return _home(wide);
  }

  Widget _scroll(List<Widget> children) => ListView(
    padding: EdgeInsets.fromLTRB(
      MediaQuery.sizeOf(context).width >= 900 ? 36 : 20,
      12,
      MediaQuery.sizeOf(context).width >= 900 ? 36 : 20,
      32,
    ),
    children: children,
  );
  Widget _eyebrow(String text) => Text(
    text,
    style: const TextStyle(color: muted, fontSize: 10, letterSpacing: 2),
  );
  Widget _section(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            letterSpacing: -.9,
          ),
        ),
        const SizedBox(height: 7),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 13)),
      ],
    ),
  );

  Widget _home(bool wide) => _scroll([
    const SizedBox(height: 12),
    _eyebrow('ЛИЧНОЕ МУЗЫКАЛЬНОЕ ПРОСТРАНСТВО'),
    const SizedBox(height: 22),
    LayoutBuilder(
      builder: (context, constraints) {
        final large = constraints.maxWidth > 650;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2B2B35)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF191920), Color(0xFF0C0C11), Color(0xFF11111A)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: large ? -15 : -100,
                top: large ? -35 : 10,
                child: Opacity(
                  opacity: large ? 1 : .45,
                  child: OrbitArt(size: large ? 390 : 320, animated: true),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(large ? 36 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _eyebrow('OPTIMUM / FIRST SIGNAL'),
                    const SizedBox(height: 25),
                    Text(
                      'Музыка.\nБлиже к вам.',
                      style: TextStyle(
                        fontSize: large ? 49 : 37,
                        height: 1.1,
                        letterSpacing: -2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(
                      width: 330,
                      child: Text(
                        'Ваши треки, ваше настроение, ваша орбита.\nНачните с музыки, которую любите.',
                        style: TextStyle(
                          color: Color(0xFFB0B0BC),
                          fontSize: 13,
                          height: 1.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: model.busy ? null : model.importFiles,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Добавить музыку'),
                        ),
                        OutlinedButton(
                          onPressed: model.busy
                              ? null
                              : () async {
                                  await model.addStudies();
                                  if (model.tracks.isNotEmpty) {
                                    await player.select(model.tracks, 0);
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 19,
                            ),
                            side: const BorderSide(color: Color(0xFF44444E)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Послушать этюд',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'MP3 · FLAC · WAV    /    Без аккаунта и подключения к сети',
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
    const SizedBox(height: 26),
    LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _destinationCard(
            'Ваша коллекция',
            '${model.tracks.length} треков · ${model.playlists.length} плейлистов',
            'Всё любимое — рядом.',
            Icons.library_music_outlined,
            () => navigate(1),
          ),
          _destinationCard(
            'OPTIMUM TOGETHER',
            'Следующий большой этап',
            'Одна музыка. Общее пространство.',
            Icons.people_outline,
            () => navigate(3),
          ),
        ];
        return constraints.maxWidth > 650
            ? Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 18),
                  Expanded(child: cards[1]),
                ],
              )
            : Column(
                children: [cards[0], const SizedBox(height: 14), cards[1]],
              );
      },
    ),
    const SizedBox(height: 32),
    Row(
      children: [
        const Expanded(
          child: Text(
            'На вашей орбите',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
          ),
        ),
        TextButton(
          onPressed: () => navigate(1),
          child: const Text(
            'Вся библиотека →',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ),
      ],
    ),
    const SizedBox(height: 14),
    if (model.tracks.isEmpty)
      _empty(
        Icons.music_note_outlined,
        'Первый трек задаёт направление',
        'Добавьте аудиофайлы или послушайте авторские звуковые этюды OPTIMUM.',
      )
    else
      ...model.tracks.take(4).map((t) => _track(t, model.tracks)),
  ]);

  Widget _destinationCard(
    String title,
    String label,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Surface(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF22222B),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 23),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: muted, fontSize: 9),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.north_east, color: muted, size: 18),
          ],
        ),
      ),
    ),
  );

  Widget _empty(IconData icon, String title, String description) => Surface(
    child: Column(
      children: [
        Icon(icon, size: 32, color: muted),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center),
        const SizedBox(height: 7),
        Text(
          description,
          style: const TextStyle(color: muted, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _library() => FutureBuilder<List<Track>>(
    future: selectedPlaylist == null
        ? Future.value(model.tracks)
        : model.store.tracks(playlistId: selectedPlaylist),
    builder: (context, snapshot) {
      var tracks = snapshot.data ?? <Track>[];
      if (selectedPlaylist == null && filter == 1) {
        tracks = tracks.where((t) => t.liked).toList();
      }
      if (selectedPlaylist == null && filter == 2) tracks = model.recent;
      tracks = tracks
          .where(
            (t) => '${t.title} ${t.artist} ${t.album}'.toLowerCase().contains(
              search.toLowerCase(),
            ),
          )
          .toList();
      final playlist = model.playlists
          .where((p) => p.id == selectedPlaylist)
          .firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: _section(
              playlist?.name ?? 'Ваша библиотека',
              '${tracks.length} треков · музыка хранится на вашем устройстве',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                if (selectedPlaylist == null)
                  ...List.generate(
                    3,
                    (i) => ChoiceChip(
                      label: Text(['Все треки', 'Избранное', 'История'][i]),
                      selected: filter == i,
                      onSelected: (_) => setState(() => filter = i),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: model.busy ? null : model.importFiles,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Файлы'),
                ),
                OutlinedButton.icon(
                  onPressed: model.busy ? null : model.importFolder,
                  icon: const Icon(Icons.folder_open, size: 17),
                  label: const Text('Папка'),
                ),
                if (tracks.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => player.select(tracks, 0),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Слушать'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _empty(
                        Icons.library_music_outlined,
                        search.isEmpty
                            ? 'Здесь будет ваша музыка'
                            : 'Ничего не найдено',
                        'Добавляйте файлы и сохраняйте любимые композиции.',
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: tracks.length,
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    itemBuilder: (context, index) => _track(
                      tracks[index],
                      tracks,
                      playlist: selectedPlaylist,
                    ),
                  ),
          ),
        ],
      );
    },
  );

  Widget _track(Track track, List<Track> source, {int? playlist}) {
    track =
        model.tracks
            .where((candidate) => candidate.id == track.id)
            .firstOrNull ??
        track;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E28),
              borderRadius: BorderRadius.circular(9),
            ),
            child: OrbitArt(size: 46, variant: track.id % 3),
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          onTap: () => player.select(
            source,
            source.indexWhere((candidate) => candidate.id == track.id),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (MediaQuery.sizeOf(context).width > 600)
                Text(
                  track.durationMs > 0
                      ? timeLabel(Duration(milliseconds: track.durationMs))
                      : '—',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              IconButton(
                onPressed: model.busy ? null : () => model.like(track),
                tooltip: track.liked ? 'Убрать из избранного' : 'В избранное',
                icon: Icon(
                  track.liked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: track.liked ? paper : muted,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Действия с треком',
                onSelected: (value) async {
                  if (value == 'playlist') {
                    await _choosePlaylist(track);
                  }
                  if (value == 'remove') {
                    await model.task(() async {
                      await player.removeFromQueue(track.id);
                      await model.store.remove(track.id);
                    });
                  }
                  if (value == 'unlink' && playlist != null) {
                    await model.task(
                      () => model.store.removeFromPlaylist(playlist, track.id),
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'playlist',
                    child: Text('Добавить в плейлист'),
                  ),
                  if (playlist != null)
                    const PopupMenuItem(
                      value: 'unlink',
                      child: Text('Убрать из плейлиста'),
                    ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Убрать из библиотеки (файл останется)'),
                  ),
                ],
                icon: const Icon(Icons.more_horiz, size: 19, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _nameDialog(String title, [String value = '']) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(hintText: 'Название'),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(context, v);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    // Disposal after the route's exit animation avoids a TextField lifecycle race.
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    return result;
  }

  Future<void> _newPlaylist() async {
    final name = await _nameDialog('Новый плейлист');
    if (name != null) {
      await model.task(() async {
        await model.store.createPlaylist(name);
      });
    }
  }

  Future<void> _choosePlaylist(Track track) async {
    if (model.playlists.isEmpty) await _newPlaylist();
    if (!mounted || model.playlists.isEmpty) return;
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Добавить в плейлист'),
        children: model.playlists
            .map(
              (p) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, p.id),
                child: Text(p.name),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) {
      await model.task(() => model.store.addToPlaylist(selected, track.id));
    }
  }

  Widget _playlists() => _scroll([
    _section('Плейлисты', 'Соберите музыку для своего момента.'),
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: model.busy ? null : _newPlaylist,
        icon: const Icon(Icons.add),
        label: const Text('Создать плейлист'),
      ),
    ),
    const SizedBox(height: 24),
    if (model.playlists.isEmpty)
      _empty(
        Icons.queue_music,
        'Своя музыка — свой порядок',
        'Создайте плейлист, затем добавьте треки через меню в библиотеке.',
      ),
    ...model.playlists.map(
      (p) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Surface(
          padding: const EdgeInsets.all(8),
          child: ListTile(
            leading: const Icon(Icons.album_outlined),
            title: Text(p.name),
            subtitle: Text(
              '${p.count} треков',
              style: const TextStyle(color: muted),
            ),
            onTap: () => setState(() {
              selectedPlaylist = p.id;
              page = 1;
            }),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'rename') {
                  final name = await _nameDialog('Название плейлиста', p.name);
                  if (name != null) {
                    await model.task(
                      () => model.store.renamePlaylist(p.id, name),
                    );
                  }
                }
                if (value == 'delete') {
                  await model.task(() => model.store.deletePlaylist(p.id));
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Text('Переименовать'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Удалить плейлист'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ]);

  Widget _together() => _scroll([
    _eyebrow('OPTIMUM TOGETHER'),
    const SizedBox(height: 18),
    const OrbitArt(size: 250, variant: 2, animated: true),
    const Text(
      'Расстояние —\nтолько координаты.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 35, height: 1.15, letterSpacing: -1),
    ),
    const SizedBox(height: 18),
    const Text(
      'Совместное прослушивание — следующий большой этап OPTIMUM.',
      textAlign: TextAlign.center,
      style: TextStyle(color: muted),
    ),
    const SizedBox(height: 30),
    const Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Разработка модуля', style: TextStyle(fontSize: 19)),
          SizedBox(height: 16),
          Text(
            'Серверное ядро: последовательные команды, очередь, права, передача управления и повторный вход.',
          ),
          SizedBox(height: 14),
          Text(
            'Комнаты ещё недоступны. Следующие шаги: Supabase-аккаунты, защищённый WebSocket и проверка синхронизации на двух устройствах.',
            style: TextStyle(color: muted),
          ),
        ],
      ),
    ),
  ]);
  Widget _settings() => _scroll([
    _section('Настройки', 'Ваше пространство должно быть комфортным.'),
    Surface(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Уменьшить движение'),
            subtitle: const Text(
              'Остановить звёзды и переходы',
              style: TextStyle(color: muted),
            ),
            value: model.reduceMotion,
            onChanged: model.busy ? null : model.motion,
          ),
          const Divider(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.offline_bolt_outlined),
            title: Text('Музыка без сети'),
            subtitle: Text(
              'Локальные файлы воспроизводятся без аккаунта. Исходные файлы не копируются и не удаляются.',
              style: TextStyle(color: muted),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 18),
    Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Локальная база данных'),
          const SizedBox(height: 9),
          SelectableText(
            model.store.db.path,
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 18),
          const Text(
            'OPTIMUM 0.1.1 · первый рабочий прототип',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            'Фоновое мобильное воспроизведение, аккаунты, рекомендации и интеграции ещё не реализованы.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'OPTIMUM',
              applicationVersion: '0.1.1',
            ),
            child: const Text('Лицензии компонентов'),
          ),
        ],
      ),
    ),
  ]);

  void _fullPlayer() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ink,
    constraints: const BoxConstraints(maxWidth: 860),
    builder: (context) => Cosmos(
      reduced: model.reduceMotion || MediaQuery.disableAnimationsOf(context),
      child: DraggableScrollableSheet(
        initialChildSize: .9,
        minChildSize: .5,
        maxChildSize: .96,
        expand: false,
        builder: (context, scroll) => AnimatedBuilder(
          animation: Listenable.merge([player, model]),
          builder: (context, _) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'СЕЙЧАС В ВАШЕМ ПРОСТРАНСТВЕ',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    tooltip: 'Свернуть плеер',
                  ),
                ],
              ),
              Center(
                child: player.cover != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.memory(
                          player.cover!,
                          width: 250,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const OrbitArt(size: 250, animated: true),
                        ),
                      )
                    : const OrbitArt(size: 250, animated: true),
              ),
              Text(
                player.current?.title ?? 'Выберите музыку',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 25),
              ),
              Text(
                player.current?.artist ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 20),
              PlayerBar(player: player, model: model),
              const SizedBox(height: 24),
              const Text('Очередь', style: TextStyle(fontSize: 19)),
              const SizedBox(height: 12),
              ...player.queue.tracks.map((t) => _track(t, player.queue.tracks)),
            ],
          ),
        ),
      ),
    ),
  );
}

class PlayerBar extends StatelessWidget {
  final PlaybackModel player;
  final AppModel model;
  final VoidCallback? onExpand;
  const PlayerBar({
    super.key,
    required this.player,
    required this.model,
    this.onExpand,
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: player,
    builder: (context, _) {
      final compact = MediaQuery.sizeOf(context).width < 650;
      final current = player.current;
      final track = model.tracks.where((t) => t.id == current?.id).firstOrNull;
      final enabled = current != null && !player.loading;
      final duration = player.duration.inMilliseconds.toDouble();
      final controls = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            IconButton(
              onPressed: enabled ? player.shuffle : null,
              tooltip: 'Перемешивание',
              icon: Icon(
                Icons.shuffle,
                size: 18,
                color: player.queue.shuffled ? paper : muted,
              ),
            ),
          IconButton(
            onPressed: enabled ? player.previous : null,
            icon: const Icon(Icons.skip_previous_rounded),
            tooltip: 'Предыдущая',
          ),
          IconButton.filled(
            onPressed: enabled ? player.toggle : null,
            tooltip: player.playing ? 'Пауза' : 'Воспроизвести',
            icon: player.loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    player.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
          ),
          IconButton(
            onPressed: enabled ? player.next : null,
            icon: const Icon(Icons.skip_next_rounded),
            tooltip: 'Следующая',
          ),
          if (!compact)
            IconButton(
              onPressed: enabled ? player.repeat : null,
              tooltip: 'Повтор: ${player.queue.repeat.name}',
              icon: Icon(
                player.queue.repeat == RepeatMode.one
                    ? Icons.repeat_one
                    : Icons.repeat,
                size: 18,
                color: player.queue.repeat == RepeatMode.off ? muted : paper,
              ),
            ),
        ],
      );
      final info = Row(
        children: [
          if (!compact) ...[
            SizedBox.square(
              dimension: 44,
              child: player.cover != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        player.cover!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const OrbitArt(size: 44),
                      ),
                    )
                  : const OrbitArt(size: 44),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: InkWell(
              onTap: onExpand,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      current?.title ?? 'Ваша музыка ждёт',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      current?.artist ?? 'Добавьте первый трек',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!compact && track != null)
            IconButton(
              onPressed: model.busy ? null : () => model.like(track),
              icon: Icon(
                track.liked ? Icons.favorite : Icons.favorite_border,
                size: 18,
              ),
              tooltip: 'Избранное',
            ),
        ],
      );
      final timeline = Row(
        children: [
          Text(
            timeLabel(player.position),
            style: const TextStyle(color: muted, fontSize: 10),
          ),
          Expanded(
            child: Slider(
              min: 0,
              max: duration > 0 ? duration : 1,
              value: player.position.inMilliseconds.toDouble().clamp(
                0,
                duration > 0 ? duration : 1,
              ),
              onChanged: enabled && duration > 0
                  ? (v) => player.seek(Duration(milliseconds: v.round()))
                  : null,
            ),
          ),
          Text(
            timeLabel(player.duration),
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        ],
      );
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E0E13),
          border: Border(top: BorderSide(color: Color(0xFF25252E))),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 24,
          vertical: compact ? 5 : 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (player.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  player.error!,
                  maxLines: 3,
                  style: const TextStyle(
                    color: Color(0xFFE4BDBD),
                    fontSize: 11,
                  ),
                ),
              ),
            if (compact) ...[
              Row(
                children: [
                  Expanded(child: info),
                  controls,
                ],
              ),
              timeline,
            ] else
              Row(
                children: [
                  Expanded(flex: 3, child: info),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [controls, timeline],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        const Icon(Icons.volume_down, size: 19, color: muted),
                        Expanded(
                          child: Slider(
                            value: player.volume,
                            onChanged: player.setVolume,
                          ),
                        ),
                        if (onExpand != null)
                          IconButton(
                            onPressed: onExpand,
                            icon: const Icon(Icons.open_in_full, size: 17),
                            tooltip: 'Открыть плеер',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}
