import 'dart:convert';
import 'dart:io';
import 'game_save.dart';

abstract class GameSaveRepository {
  Future<GameSave?> load();
  Future<void> save(GameSave save);
  Future<void> reset();
}

/// Serialized writes, atomic rename and last-known-good backup.
class FileGameSaveRepository implements GameSaveRepository {
  FileGameSaveRepository(this.directory);
  final Directory directory;
  Future<void> _queue = Future.value();
  File get _file => File('${directory.path}/save.json');
  File get _backup => File('${directory.path}/save.backup.json');
  @override
  Future<GameSave?> load() async {
    await _queue;
    Object? failure;
    for (final file in [_file, _backup]) {
      if (!await file.exists()) continue;
      try {
        return GameSave.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        );
      } catch (error) {
        if (error is UnsupportedError) rethrow;
        failure = error;
      }
    }
    if (failure != null) {
      throw FormatException('Save and backup could not be read: $failure');
    }
    return null;
  }

  @override
  Future<void> save(GameSave save) {
    // Capture mutable game state synchronously, before a queued write starts.
    final contents = jsonEncode(save.toJson());
    return _serialized(() async {
      await directory.create(recursive: true);
      final temporary = File('${directory.path}/save.tmp');
      await temporary.writeAsString(contents, flush: true);
      if (await _file.exists()) {
        var valid = false;
        try {
          GameSave.fromJson(
            jsonDecode(await _file.readAsString()) as Map<String, dynamic>,
          );
          valid = true;
        } catch (_) {
          /* Preserve good backup if primary is damaged. */
        }
        if (valid) await _file.copy(_backup.path);
      }
      if (Platform.isWindows && await _file.exists()) await _file.delete();
      await temporary.rename(_file.path);
    });
  }

  Future<void> _serialized(Future<void> Function() work) {
    final result = _queue.then((_) => work());
    _queue = result.catchError((Object _) {});
    return result;
  }

  @override
  Future<void> reset() => _serialized(() async {
    for (final file in [_file, _backup, File('${directory.path}/save.tmp')]) {
      if (await file.exists()) await file.delete();
    }
  });
}
