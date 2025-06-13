import 'package:shared_preferences/shared_preferences.dart';

/// Settings service for the TouchPad Pro Server
class SettingsService {
  static const String _serverPortKey = 'server_port';
  static const String _autoStartKey = 'auto_start';
  static const String _requirePermissionKey = 'require_permission';
  static const String _minimizeToTrayKey = 'minimize_to_tray';
  static const String _showNotificationsKey = 'show_notifications';
  static const String _startMinimizedKey = 'start_minimized';
  static const int _defaultServerPort = 8080;
  static const bool _defaultAutoStart = true; // Enable auto-start by default
  static const bool _defaultRequirePermission = true;
  static const bool _defaultMinimizeToTray = true;
  static const bool _defaultShowNotifications = true;
  static const bool _defaultStartMinimized = true; // Start minimized by default

  SharedPreferences? _prefs;

  /// Initialize the settings service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Server port setting
  int get serverPort {
    return _prefs?.getInt(_serverPortKey) ?? _defaultServerPort;
  }

  Future<void> setServerPort(int port) async {
    await _prefs?.setInt(_serverPortKey, port);
  }

  /// Auto start setting
  bool get autoStart {
    return _prefs?.getBool(_autoStartKey) ?? _defaultAutoStart;
  }

  Future<void> setAutoStart(bool value) async {
    await _prefs?.setBool(_autoStartKey, value);
  }

  /// Require permission setting
  bool get requirePermission {
    return _prefs?.getBool(_requirePermissionKey) ?? _defaultRequirePermission;
  }

  Future<void> setRequirePermission(bool value) async {
    await _prefs?.setBool(_requirePermissionKey, value);
  }

  /// Minimize to tray setting
  bool get minimizeToTray {
    return _prefs?.getBool(_minimizeToTrayKey) ?? _defaultMinimizeToTray;
  }

  Future<void> setMinimizeToTray(bool value) async {
    await _prefs?.setBool(_minimizeToTrayKey, value);
  }

  /// Show notifications setting
  bool get showNotifications {
    return _prefs?.getBool(_showNotificationsKey) ?? _defaultShowNotifications;
  }

  Future<void> setShowNotifications(bool value) async {
    await _prefs?.setBool(_showNotificationsKey, value);
  }

  /// Start minimized setting
  bool get startMinimized {
    return _prefs?.getBool(_startMinimizedKey) ?? _defaultStartMinimized;
  }

  Future<void> setStartMinimized(bool value) async {
    await _prefs?.setBool(_startMinimizedKey, value);
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await setServerPort(_defaultServerPort);
    await setAutoStart(_defaultAutoStart);
    await setRequirePermission(_defaultRequirePermission);
    await setMinimizeToTray(_defaultMinimizeToTray);
    await setShowNotifications(_defaultShowNotifications);
    await setStartMinimized(_defaultStartMinimized);
  }

  /// Get all settings as a map
  Map<String, dynamic> getAllSettings() {
    return {
      'serverPort': serverPort,
      'autoStart': autoStart,
      'requirePermission': requirePermission,
      'minimizeToTray': minimizeToTray,
      'showNotifications': showNotifications,
      'startMinimized': startMinimized,
    };
  }
}
