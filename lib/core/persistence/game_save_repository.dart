import 'dart:convert';
import 'dart:io';
import 'game_save.dart';

abstract class GameSaveRepository {
  Future<GameSave?> load();
  Future<void> save(GameSave save);
  Future<void> reset();
}

enum SaveLoadStatus { newGame, current, recoveredBackup, discardedLegacy }

extension SaveLoadMessage on SaveLoadStatus {
  String? get notice => switch (this) {
    SaveLoadStatus.newGame || SaveLoadStatus.current => null,
    SaveLoadStatus.recoveredBackup =>
      'Progress restored from backup. Changes since that save may be lost.',
    SaveLoadStatus.discardedLegacy =>
      'An older pre-release save was reset. A new adventure has started.',
  };
}

/// Serialized writes, atomic rename and last-known-good backup.
class FileGameSaveRepository implements GameSaveRepository {
  FileGameSaveRepository(this.directory);
  final Directory directory;
  SaveLoadStatus _lastLoadStatus = SaveLoadStatus.newGame;
  SaveLoadStatus get lastLoadStatus => _lastLoadStatus;
  Future<void> _queue = Future.value();
  File get _file => File('${directory.path}/save.json');
  File get _backup => File('${directory.path}/save.backup.json');
  Future<_SaveRead> _read(File file) async {
    if (!await file.exists()) return const _SaveRead();
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic> || json['saveVersion'] is! int) {
        throw const FormatException('Missing or invalid save version');
      }
      final version = json['saveVersion'] as int;
      if (version >= 1 && version < GameSave.currentVersion) {
        return const _SaveRead(legacy: true);
      }
      return _SaveRead(save: GameSave.fromJson(json));
    } catch (error) {
      return _SaveRead(error: error);
    }
  }

  @override
  Future<GameSave?> load() => _serialized(() async {
    _lastLoadStatus = SaveLoadStatus.newGame;
    final primary = await _read(_file);
    final backup = await _read(_backup);
    // Never automatically downgrade or overwrite an unknown schema, even if
    // a readable older current-schema backup is available.
    for (final read in [primary, backup]) {
      if (read.error is UnsupportedError) throw read.error!;
    }
    if (primary.save != null) {
      _lastLoadStatus = SaveLoadStatus.current;
      return primary.save;
    }
    if (backup.save != null) {
      _lastLoadStatus = SaveLoadStatus.recoveredBackup;
      return backup.save;
    }
    final failure = primary.error ?? backup.error;
    if (failure != null) {
      throw FormatException('Save and backup could not be read: $failure');
    }
    // Only positively identified pre-release schemas may be cleared. This
    // runs in the same queue as save/reset, so legacy cannot reappear later.
    if (primary.legacy || backup.legacy) {
      await _deleteFiles();
      _lastLoadStatus = SaveLoadStatus.discardedLegacy;
    }
    return null;
  });

  @override
  Future<void> save(GameSave save) {
    // Capture mutable game state synchronously, before a queued write starts.
    final contents = jsonEncode(save.toJson());
    return _serialized(() async {
      for (final file in [_file, _backup]) {
        final read = await _read(file);
        if (read.error is UnsupportedError) throw read.error!;
      }
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

  Future<T> _serialized<T>(Future<T> Function() work) {
    final result = _queue.then((_) => work());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _deleteFiles() async {
    for (final file in [_file, _backup, File('${directory.path}/save.tmp')]) {
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> reset() => _serialized(_deleteFiles);
}

class _SaveRead {
  const _SaveRead({this.save, this.legacy = false, this.error});
  final GameSave? save;
  final bool legacy;
  final Object? error;
}
