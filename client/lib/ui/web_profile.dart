import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:webview_windows/webview_windows.dart';

/// One persistent WebView2 environment shared by provider pages and embeds.
class WebProfile {
  static Future<void>? _ready;
  static Future<void> initialize({String? directory}) =>
      _ready ??= _create(directory).catchError((Object e) {
        _ready = null;
        throw e;
      });
  static Future<void> _create(String? directory) async {
    if (await WebviewController.getWebViewVersion() == null) {
      throw const FormatException(
        'Установите Microsoft Edge WebView2 Runtime для встроенного плеера',
      );
    }
    final path =
        directory ??
        p.join((await getApplicationSupportDirectory()).path, 'WebPlayer');
    await WebviewController.initializeEnvironment(userDataPath: path);
  }
}
