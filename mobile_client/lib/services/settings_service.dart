import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

/// Service for managing persistent application settings
class SettingsService {
  static const String _mouseSensitivityKey = 'mouse_sensitivity';
  static const String _scrollSensitivityKey = 'scroll_sensitivity';
  static const String _reverseScrollKey = 'reverse_scroll';
  static const String _deviceNameKey = 'device_name';

  static const double _defaultMouseSensitivity = 2.0;
  static const double _defaultScrollSensitivity = 1.0;
  static const bool _defaultReverseScroll = false;

  SharedPreferences? _prefs;

  /// Initialize the settings service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get mouse sensitivity setting
  double get mouseSensitivity {
    return _prefs?.getDouble(_mouseSensitivityKey) ?? _defaultMouseSensitivity;
  }

  /// Set mouse sensitivity setting
  Future<void> setMouseSensitivity(double value) async {
    await _prefs?.setDouble(_mouseSensitivityKey, value);
  }

  /// Get scroll sensitivity setting
  double get scrollSensitivity {
    return _prefs?.getDouble(_scrollSensitivityKey) ??
        _defaultScrollSensitivity;
  }

  /// Set scroll sensitivity setting
  Future<void> setScrollSensitivity(double value) async {
    await _prefs?.setDouble(_scrollSensitivityKey, value);
  }

  /// Get reverse scroll setting
  bool get reverseScroll {
    return _prefs?.getBool(_reverseScrollKey) ?? _defaultReverseScroll;
  }

  /// Set reverse scroll setting
  Future<void> setReverseScroll(bool value) async {
    await _prefs?.setBool(_reverseScrollKey, value);
  }

  /// Get device name setting
  String get deviceName {
    return _prefs?.getString(_deviceNameKey) ?? _getDefaultDeviceName();
  }

  /// Set device name setting
  Future<void> setDeviceName(String value) async {
    await _prefs?.setString(_deviceNameKey, value);
  }

  /// Get default device name based on platform
  String _getDefaultDeviceName() {
    // Return a default name that will be enhanced by the WebSocket service
    // when it gets actual device info during connection
    return 'My Mobile Device';
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await setMouseSensitivity(_defaultMouseSensitivity);
    await setScrollSensitivity(_defaultScrollSensitivity);
    await setReverseScroll(_defaultReverseScroll);
    await setDeviceName(_getDefaultDeviceName());
  }

  /// Load all settings (useful for initialization)
  Map<String, dynamic> getAllSettings() {
    return {
      'mouseSensitivity': mouseSensitivity,
      'scrollSensitivity': scrollSensitivity,
      'reverseScroll': reverseScroll,
      'deviceName': deviceName,
    };
  }
}
