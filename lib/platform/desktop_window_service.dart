import 'package:flutter/services.dart';

abstract class DesktopWindowService {
  Future<void> configure({
    required bool alwaysOnTop,
    required bool expanded,
    bool heroVisible = true,
  });
  Future<void> quit();
  Future<void> cancelClose();
  void onCloseRequested(Future<void> Function() handler);
}

class NativeDesktopWindowService implements DesktopWindowService {
  static const channel = MethodChannel('idle_companion/desktop');
  @override
  Future<void> configure({
    required bool alwaysOnTop,
    required bool expanded,
    bool heroVisible = true,
  }) async {
    await channel.invokeMethod<void>('configure', {
      'alwaysOnTop': alwaysOnTop,
      'expanded': expanded,
      'heroVisible': heroVisible,
    });
  }

  @override
  Future<void> cancelClose() => channel.invokeMethod<void>('cancelClose');
  @override
  Future<void> quit() => channel.invokeMethod<void>('quit');
  @override
  void onCloseRequested(Future<void> Function() handler) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'closeRequested') await handler();
    });
  }
}
