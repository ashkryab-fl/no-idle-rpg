import 'dart:io';
import 'package:flutter/services.dart';

abstract class UserActivityService {
  Future<Duration> idleDuration();
  static UserActivityService native() => Platform.isMacOS
      ? MacOSUserActivityService()
      : WindowsUserActivityService();
}

class MacOSUserActivityService implements UserActivityService {
  static const channel = MethodChannel('idle_companion/desktop');
  @override
  Future<Duration> idleDuration() async => Duration(
    milliseconds: ((await channel.invokeMethod<num>('idleSeconds'))! * 1000)
        .round(),
  );
}

class WindowsUserActivityService extends MacOSUserActivityService {}
