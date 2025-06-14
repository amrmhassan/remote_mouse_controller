import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/debug_logger.dart';

/// Simplified background connection management using app lifecycle
class BackgroundConnectionService {
  static Timer? _connectionTimer;
  static bool _isMonitoring = false;

  /// Start connection monitoring when app goes to background
  static void startMonitoring({required Function() onShouldReconnect}) {
    if (_isMonitoring) return;

    _isMonitoring = true;

    // Check connection every 30 seconds when app is in background
    _connectionTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      try {
        final shouldReconnect = await _checkShouldReconnect();
        if (shouldReconnect) {
          onShouldReconnect();
        }
      } catch (e) {
        DebugLogger.log('Background monitoring error: $e', tag: 'BG_SERVICE');
      }
    });

    DebugLogger.log('Background monitoring started', tag: 'BG_SERVICE');
  }

  /// Stop connection monitoring
  static void stopMonitoring() {
    _connectionTimer?.cancel();
    _connectionTimer = null;
    _isMonitoring = false;
    DebugLogger.log('Background monitoring stopped', tag: 'BG_SERVICE');
  }

  /// Check if reconnection should be attempted
  static Future<bool> _checkShouldReconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if background reconnection is enabled
      final isEnabled = prefs.getBool('background_reconnect_enabled') ?? true;
      if (!isEnabled) return false;

      // Check if currently connected
      final isConnected = prefs.getBool('is_connected') ?? false;
      if (isConnected) return false;

      // Check if we have connection details
      final lastIp = prefs.getString('last_connected_ip');
      final lastPort = prefs.getInt('last_connected_port');
      if (lastIp == null || lastPort == null) return false;

      // Check if enough time has passed since last disconnect
      final lastDisconnectTime = prefs.getInt('last_disconnect_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final timeSinceDisconnect = now - lastDisconnectTime;

      // Only attempt reconnection if disconnected for more than 1 minute
      return timeSinceDisconnect > 60000;
    } catch (e) {
      DebugLogger.log(
        'Error checking reconnection status: $e',
        tag: 'BG_SERVICE',
      );
      return false;
    }
  }

  /// Set background reconnection enabled/disabled
  static Future<void> setBackgroundReconnectEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_reconnect_enabled', enabled);
      DebugLogger.log(
        'Background reconnect ${enabled ? 'enabled' : 'disabled'}',
        tag: 'BG_SERVICE',
      );
    } catch (e) {
      DebugLogger.log(
        'Failed to set background reconnect: $e',
        tag: 'BG_SERVICE',
      );
    }
  }

  /// Check if background reconnect is enabled
  static Future<bool> isBackgroundReconnectEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('background_reconnect_enabled') ?? true;
    } catch (e) {
      DebugLogger.log(
        'Failed to check background reconnect status: $e',
        tag: 'BG_SERVICE',
      );
      return true;
    }
  }

  /// Update connection status in preferences
  static Future<void> updateConnectionStatus(
    bool isConnected, {
    String? ip,
    int? port,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_connected', isConnected);

      if (isConnected && ip != null && port != null) {
        await prefs.setString('last_connected_ip', ip);
        await prefs.setInt('last_connected_port', port);
      } else if (!isConnected) {
        await prefs.setInt(
          'last_disconnect_time',
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      DebugLogger.log(
        'Failed to update connection status: $e',
        tag: 'BG_SERVICE',
      );
    }
  }
}
