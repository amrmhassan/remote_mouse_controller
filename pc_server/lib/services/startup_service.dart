import 'dart:io';
import 'package:launch_at_startup/launch_at_startup.dart';
import '../utils/debug_logger.dart';

/// Service to handle application startup configuration
class StartupService {
  static bool _isInitialized = false;

  /// Initialize the startup service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      DebugLogger.log('Initializing startup service...', tag: 'STARTUP');

      // Configure launch at startup
      launchAtStartup.setup(
        appName: 'TouchPad Pro Server',
        appPath: Platform.resolvedExecutable,
        args: ['--minimized'], // Start minimized when launched at startup
      );

      _isInitialized = true;
      DebugLogger.log('Startup service initialized successfully',
          tag: 'STARTUP');
    } catch (e) {
      DebugLogger.error('Failed to initialize startup service',
          tag: 'STARTUP', error: e);
    }
  }

  /// Enable or disable startup with Windows
  static Future<bool> setStartupEnabled(bool enabled) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      DebugLogger.log('Setting startup enabled: $enabled', tag: 'STARTUP');

      if (enabled) {
        await launchAtStartup.enable();
        DebugLogger.log('Startup enabled successfully', tag: 'STARTUP');
      } else {
        await launchAtStartup.disable();
        DebugLogger.log('Startup disabled successfully', tag: 'STARTUP');
      }

      return true;
    } catch (e) {
      DebugLogger.error('Failed to set startup enabled: $enabled',
          tag: 'STARTUP', error: e);
      return false;
    }
  }

  /// Check if startup is currently enabled
  static Future<bool> isStartupEnabled() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final enabled = await launchAtStartup.isEnabled();
      DebugLogger.log('Startup enabled status: $enabled', tag: 'STARTUP');
      return enabled;
    } catch (e) {
      DebugLogger.error('Failed to check startup status',
          tag: 'STARTUP', error: e);
      return false;
    }
  }
}
