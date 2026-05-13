import 'package:flutter/foundation.dart';

class AppEnvironment {
  /// Prefer compile-time `--dart-define=APP_ENV=prod` when available.
  /// Fallback to `kReleaseMode` so release builds automatically pick
  /// the production env file when `--dart-define` is not provided.
  static String get mode {
    final fromDefine = const String.fromEnvironment('APP_ENV', defaultValue: '');
    if (fromDefine.isNotEmpty) return fromDefine;
    return kReleaseMode ? 'prod' : 'dev';
  }

  static bool get isProduction => mode == 'prod';
  static bool get isDevelopment => !isProduction;

  static String get envFileName => isProduction ? '.env.prod' : '.env.dev';
}