import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/app_data.dart';

/// Keeps all data in one JSON file. Writes go through a queue and are atomic
/// (write a temp file, then rename), so a crash can't leave half a file.
class StorageService {
  StorageService(this.file, {this.onError});

  final File file;
  final void Function(Object error)? onError;

  Future<void> _queue = Future<void>.value();

  Future<AppData> load() async {
    try {
      if (!await file.exists()) return const AppData();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) throw const FormatException('Root is not an object');
      return AppData.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      onError?.call(e);
      await _quarantine();
      return const AppData();
    }
  }

  /// Moves an unreadable file aside so it is never silently overwritten.
  Future<void> _quarantine() async {
    try {
      if (await file.exists()) {
        await file.rename('${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      }
    } catch (_) {
      // Nothing more we can do.
    }
  }

  /// Queues a write. The snapshot is serialised immediately, so later changes
  /// to [data] can't leak into this write.
  Future<void> save(AppData data) {
    final snapshot = const JsonEncoder.withIndent('  ').convert(data.toJson());
    _queue = _queue.then((_) => _write(snapshot)).catchError((Object e) {
      onError?.call(e);
    });
    return _queue;
  }

  Future<void> _write(String contents) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(contents, flush: true);
    await tmp.rename(file.path);
  }
}
