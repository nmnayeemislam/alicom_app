import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Puts a file the app already wrote into the phone's own Downloads folder.
///
/// Android 10+ does this through MediaStore, which needs no permission and
/// makes the file show up in Files like any other download. Everywhere else
/// — older Android, and iOS, which has no shared Downloads folder — this
/// returns null and the caller offers the share sheet instead ("Save to
/// Files" is the native way on iOS anyway).
class FileDownloads {
  FileDownloads._();

  static const _channel = MethodChannel('alicom/downloads');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Returns the saved file's name, or null when the platform cannot do it.
  static Future<String?> saveToDownloads(
    File file, {
    required String fileName,
    String mimeType = 'application/octet-stream',
  }) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('saveToDownloads', {
        'sourcePath': file.path,
        'fileName': fileName,
        'mimeType': mimeType,
      });
    } on PlatformException catch (error) {
      debugPrint('Saving to Downloads failed: ${error.message}');
      rethrow;
    } on MissingPluginException {
      // Old build of the app shell — treat it as "not supported".
      return null;
    }
  }
}
