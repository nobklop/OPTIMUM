import 'dart:async';
import 'dart:convert';
import 'link_transfer.dart';
import 'music_link.dart';

/// Copies user-visible metadata only. Never reads cookies, app state or media URLs.
class YandexPage {
  final Future<dynamic> Function(String) execute;
  YandexPage(this.execute);
  Future<Map<String, dynamic>> _json(String script) async {
    final result = await execute(script).timeout(const Duration(seconds: 12));
    if (result is! String || result.length > 4000000) {
      throw const FormatException('Страница не ответила');
    }
    final value = jsonDecode(result);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Не удалось прочитать страницу');
    }
    final uri = Uri.tryParse(value['url'] is String ? value['url'] : '');
    if (uri?.scheme != 'https' || uri?.host != 'music.yandex.ru') {
      throw const FormatException('Откройте страницу Яндекс Музыки');
    }
    if (value['error'] != null) throw FormatException(value['error'] as String);
    return value;
  }

  Future<ServiceTrack> currentTrack() async {
    final data = await _json(currentScript);
    if (data['track'] is! Map<String, dynamic>) {
      throw const FormatException(
        'Сначала выберите трек или начните его воспроизведение в сервисе',
      );
    }
    return ServiceTrack.fromMap(data['track'] as Map<String, dynamic>);
  }

  Future<PlaylistTransfer> playlist({
    required bool Function() cancelled,
    void Function(int, int)? progress,
  }) async {
    final initial = await _json(inspectScript);
    final source = MusicLink.parse(initial['url'] as String);
    if (!['playlist', 'album'].contains(source.kind)) {
      throw const FormatException(
        'Откройте сам плейлист, «Мне нравится» или альбом',
      );
    }
    final count = initial['totalSlots'];
    final declaredTracks = initial['declaredTracks'];
    if (count is! int || count < 1 || count > 11000) {
      throw const FormatException(
        'Не удалось подтвердить полный размер списка',
      );
    }
    final slots = <int, ServiceTrack?>{};
    final started = DateTime.now();
    try {
      await execute(beginScript).timeout(const Duration(seconds: 12));
      await Future<void>.delayed(const Duration(milliseconds: 350));
      var stalledReads = 0, previousSize = -1;
      while (true) {
        if (cancelled()) throw const TransferCancelled();
        if (DateTime.now().difference(started) > const Duration(minutes: 5)) {
          throw TimeoutException(
            'Плейлист загружается слишком долго. Данные не изменены',
          );
        }
        final data = await _json(inspectScript);
        if (MusicLink.parse(data['url'] as String).uri != source.uri ||
            data['totalSlots'] != count) {
          throw const FormatException(
            'Страница или состав плейлиста изменились во время чтения',
          );
        }
        final rows = data['slots'];
        if (rows is! List) {
          throw const FormatException('Не удалось прочитать позиции треков');
        }
        for (final row in rows) {
          if (row is! Map ||
              row['position'] is! int ||
              row['position'] < 0 ||
              row['position'] >= count) {
            throw const FormatException('Не удалось определить порядок треков');
          }
          final pos = row['position'] as int;
          final track = row['track'] == null
              ? null
              : ServiceTrack.fromMap(
                  Map<String, dynamic>.from(row['track'] as Map),
                );
          if (slots.containsKey(pos) &&
              slots[pos]?.link.uri != track?.link.uri) {
            throw const FormatException('Плейлист изменился во время чтения');
          }
          slots[pos] = track;
        }
        progress?.call(slots.length, count);
        if (slots.length == count &&
            List.generate(count, (i) => i).every(slots.containsKey)) {
          final tracks = [
            for (var i = 0; i < count; i++)
              if (slots[i] != null) slots[i]!,
          ];
          if ((declaredTracks is int && declaredTracks != tracks.length) ||
              (data['declaredTracks'] is int &&
                  data['declaredTracks'] != tracks.length)) {
            throw const FormatException(
              'Число прочитанных треков не совпало с числом на странице',
            );
          }
          final transfer = PlaylistTransfer(
            source,
            (data['name'] as String).trim(),
            tracks.length,
            tracks,
          );
          transfer.validate();
          return transfer;
        }
        if (slots.length == previousSize) {
          if (++stalledReads >= 12) {
            throw FormatException(
              'Прочитано ${slots.values.whereType<ServiceTrack>().length} треков, но полный список не получен. Библиотека не изменена',
            );
          }
        } else {
          stalledReads = 0;
        }
        previousSize = slots.length;
        var next = 0;
        while (slots.containsKey(next)) {
          next++;
        }
        await execute(
          seekScript.replaceFirst('__POSITION__', next.toString()),
        ).timeout(const Duration(seconds: 12));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    } finally {
      try {
        await execute(restoreScript).timeout(const Duration(seconds: 3));
      } catch (_) {
        /* Scroll restoration must not hide the import result. */
      }
    }
  }

  static const currentScript = r'''(()=>{
    const clean=s=>(s||'').replace(/[\u0000-\u001f]/g,' ').replace(/\s+/g,' ').trim();
    const meta=navigator.mediaSession?.metadata;
    const all=[...document.querySelectorAll('a[href]')].filter(a=>/^\/(?:album\/\d+\/)?track\/\d+\/?$/.test(new URL(a.href,location.href).pathname));
    const player=a=>{for(let e=a,n=0;e&&n<12;e=e.parentElement,n++)if(/PlayerBar|PlayerWidget|player-bar/i.test(e.className||''))return true;return false};
    const onPage=all.find(a=>new URL(a.href,location.href).pathname===location.pathname);
    const a=onPage||all.find(a=>player(a)&&(!meta?.title||clean(a.textContent)===clean(meta.title)))||all.find(a=>player(a));
    if(!a)return JSON.stringify({url:location.href});
    const title=clean((!onPage&&meta?.title)||a.getAttribute('aria-label')?.replace(/^Трек /,'')||a.textContent);
    const row=a.closest('[class*="CommonTrack_root"]');
    const artist=clean((!onPage&&meta?.artist)||[...row?.querySelectorAll('a[href^="/artist/"]')||[]].map(a=>a.textContent).join(', ')||document.querySelector('a[href^="/artist/"]')?.textContent);
    return JSON.stringify({url:location.href,track:{url:new URL(a.href,location.href).origin+new URL(a.href,location.href).pathname,title:clean(artist?artist+' — '+title:title).slice(0,160)}});
  })()''';

  static const inspectScript = r'''(()=>{
    const clean=s=>(s||'').replace(/[\u0000-\u001f]/g,' ').replace(/\s+/g,' ').trim();
    const root=[...document.querySelectorAll('[role="region"][aria-label*="Список треков"],[class*="virtualScroll"]')].find(e=>[...e.children].some(c=>c.hasAttribute('data-index')));
    if(!root)return JSON.stringify({url:location.href,error:'Откройте список треков плейлиста или альбома и дождитесь загрузки'});
    const items=[...root.children].filter(e=>e.hasAttribute('data-index'));
    const height=items[0]?.getBoundingClientRect().height||0;
    const full=root.getBoundingClientRect().height;
    const count=Math.round(full/height);
    if(height<10||Math.abs(full/height-count)>.03||items.some(e=>Math.abs(e.getBoundingClientRect().height-height)>1))return JSON.stringify({url:location.href,error:'Изменилась разметка списка; полный перенос не подтверждён'});
    const albumArtist=clean(document.querySelector('a[href^="/artist/"]')?.textContent);
    const slots=[];
    for(const item of items){
      const position=Number(item.getAttribute('data-index'));
      const row=item.querySelector('[class*="CommonTrack_root"]');
      if(!row){const text=clean(item.innerText);if(!text)continue;if(!/^Диск\s*\d+$/.test(text))return JSON.stringify({url:location.href,error:'Недоступна позиция '+position+' ('+text.slice(0,80)+'). Полный перенос остановлен'});slots.push({position,track:null});continue;}
      const a=[...row.querySelectorAll('a[href]')].find(a=>/^\/(?:album\/\d+\/)?track\/\d+\/?$/.test(new URL(a.href,location.href).pathname));
      if(!a)return JSON.stringify({url:location.href,error:'Один из треков не содержит ссылки; неполный список не сохранён'});
      const title=clean(a.getAttribute('aria-label')?.replace(/^Трек /,'')||a.textContent);
      const artist=clean([...row.querySelectorAll('a[href^="/artist/"]')].map(a=>a.textContent).join(', ')||albumArtist);
      slots.push({position,track:{url:new URL(a.href,location.href).origin+new URL(a.href,location.href).pathname,title:clean(artist?artist+' — '+title:title).slice(0,160)}});
    }
    const header=document.querySelector('h1')?.parentElement?.parentElement?.innerText||'';
    const match=header.match(/([\d \u00a0]+)\s+(?:трек(?:ов|а)?|пес(?:ен|ни)|tracks?)(?:\s|$)/i);
    return JSON.stringify({url:location.href,name:clean(document.querySelector('h1')?.textContent).slice(0,80),totalSlots:count,declaredTracks:match?Number(match[1].replace(/\D/g,'')):null,slots});
  })()''';
  static const beginScript = r'''(()=>{
    const root=[...document.querySelectorAll('[role="region"][aria-label*="Список треков"],[class*="virtualScroll"]')].find(e=>[...e.children].some(c=>c.hasAttribute('data-index')));
    let box=root?.parentElement;
    while(box&&!(box.scrollHeight>box.clientHeight+5&&/auto|scroll/.test(getComputedStyle(box).overflowY)))box=box.parentElement;
    box=box||document.scrollingElement;
    window.__optimumMetadataScroll={box,top:box.scrollTop,url:location.href};box.scrollTop=0;return true;
  })()''';
  static const seekScript = r'''(()=>{
    const s=window.__optimumMetadataScroll;if(!s||s.url!==location.href)return false;
    const root=[...document.querySelectorAll('[role="region"][aria-label*="Список треков"],[class*="virtualScroll"]')].find(e=>[...e.children].some(c=>c.hasAttribute('data-index')));
    if(!root)return false;const b=s.box;
    const height=[...root.children].find(e=>e.hasAttribute('data-index')).getBoundingClientRect().height;
    const origin=b.scrollTop+root.getBoundingClientRect().top-(b===document.scrollingElement?0:b.getBoundingClientRect().top);
    b.scrollTop=Math.max(0,Math.min(b.scrollHeight-b.clientHeight,origin+__POSITION__*height-Math.min(b.clientHeight,innerHeight)*.15));return true;
  })()''';
  static const restoreScript =
      r'''(()=>{const s=window.__optimumMetadataScroll;if(s&&s.url===location.href)s.box.scrollTop=s.top;delete window.__optimumMetadataScroll;return true})()''';
}

class TransferCancelled implements Exception {
  const TransferCancelled();
}
