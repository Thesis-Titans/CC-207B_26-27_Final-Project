import 'dart:io';

import 'package:flutter/foundation.dart';

/// Compile-time environment configuration for LittleSteps.
///
/// Values can be supplied with `--dart-define` or `--dart-define-from-file`
/// so the same codebase supports local Firebase emulators during development
/// and HTTPS cloud endpoints in production without code changes.
abstract final class AppConfig {
  /// Whether authentication and API calls target local Firebase emulators.
  static const bool useFirebaseEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: true,
  );

  /// Optional override for the local emulator host (for example, `localhost`
  /// when using USB or wireless `adb reverse`).
  static const String configuredEmulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
  );

  /// Optional full HTTPS base URL for the backend API in deployed environments.
  static const String configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Firebase Web API key used for Identity Toolkit authentication requests.
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'fake-api-key',
  );

  /// Resolves the active local emulator host for the current runtime platform.
  static String get emulatorHost {
    if (configuredEmulatorHost.isNotEmpty) return configuredEmulatorHost;
    if (kIsWeb) return 'localhost';
    try {
      if (Platform.isAndroid) return '10.0.2.2';
    } catch (_) {}
    return 'localhost';
  }
}
