import 'dart:io';

/// Held for the process lifetime to prevent concurrent save writers.
class AppInstanceLock {
  AppInstanceLock._(this._handle);
  final RandomAccessFile _handle;
  static Future<AppInstanceLock> acquire(Directory directory) async {
    await directory.create(recursive: true);
    final handle = await File(
      '${directory.path}/instance.lock',
    ).open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      return AppInstanceLock._(handle);
    } catch (_) {
      await handle.close();
      throw StateError(
        'Another companion is already running. Quit that instance first.',
      );
    }
  }

  Future<void> release() async {
    await _handle.unlock();
    await _handle.close();
  }
}
