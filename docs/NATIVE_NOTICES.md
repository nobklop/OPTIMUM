# Windows native components

The OPTIMUM installer contains the application and its Dart/Flutter assets,
Flutter Windows engine, SQLite, media-kit Windows plugin and Microsoft Visual C++
runtime libraries. It does not bundle libmpv: that dependency is downloaded by the
user's installer from the upstream provider, with a pinned archive and DLL hash.

- Flutter 3.47.7: BSD-3-Clause and engine dependency notices, supplied in
  Flutter-LICENSE.txt, Flutter-engine-LICENSE.md and Flutter-engine-full-LICENSE.txt.
  Source: https://github.com/flutter/flutter
- Dart and package notices: `data/flutter_assets/NOTICES.Z` (Flutter-generated
  compressed notice bundle); readable through the in-app licenses screen.
- Manrope font: SIL Open Font License, Manrope-OFL.txt.
- SQLite: public domain, https://sqlite.org/copyright.html and https://sqlite.org/src/
- media-kit / Windows plugin: MIT, https://github.com/media-kit/media-kit
- Microsoft Visual C++ 14.44 CRT: unmodified signed Microsoft redistributable
  DLLs from the installed Visual Studio Build Tools redist directory. App-local
  deployment: https://learn.microsoft.com/cpp/windows/walkthrough-deploying-a-visual-cpp-application-to-an-application-local-folder
  Redistribution terms: https://learn.microsoft.com/visualstudio/releases/2022/redistribution

## External audio engine

Provider: https://github.com/media-kit/libmpv-win32-audio-build/releases/tag/2023-09-24
Archive: mpv-dev-x86_64-20230924-git-652a1dd.7z
Archive SHA-256: 583af5a291fc99ae2641794ede1955c368eb4c19dc05f4f0a9c7f9456edeb6a8
DLL SHA-256: 0a5a0b476866c91a639a4e511e8153968f8fa23564461b0aa09acdba816164a4
mpv revision linked by the provider: 652a1dd90711839acdccc08004056d25514ef2d8.

The inspected binary's FFmpeg strings report LGPL v3 or later, with
`--disable-gpl --disable-nonfree --enable-version3`. mpv source and license:
https://github.com/mpv-player/mpv/tree/652a1dd90711839acdccc08004056d25514ef2d8
FFmpeg source and license: https://ffmpeg.org/legal.html
LGPL v3: https://www.gnu.org/licenses/lgpl-3.0.html
GPL v3 (incorporated terms): https://www.gnu.org/licenses/gpl-3.0.html

The exact complete corresponding source/build manifest for that prebuilt engine
has not been established. This is why OPTIMUM's public installer fetches the
engine from the original provider instead of redistributing that DLL or the
local portable ZIP. The library remains an ordinary replaceable DLL next to
optimum.exe; OPTIMUM does not impose a technical restriction on replacing it.
Local portable packages are development outputs and are not public release assets.
