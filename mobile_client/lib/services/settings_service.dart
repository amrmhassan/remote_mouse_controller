import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing persistent application settings
class SettingsService {
  static const String _mouseSensitivityKey = 'mouse_sensitivity';
  static const String _scrollSensitivityKey = 'scroll_sensitivity';
  static const String _reverseScrollKey = 'reverse_scroll';

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
    return _prefs?.getDouble(_scrollSensitivityKey) ?? _defaultScrollSensitivity;
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

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await setMouseSensitivity(_defaultMouseSensitivity);
    await setScrollSensitivity(_defaultScrollSensitivity);
    await setReverseScroll(_defaultReverseScroll);
  }

  /// Load all settings (useful for initialization)
  Map<String, dynamic> getAllSettings() {
    return {
      'mouseSensitivity': mouseSensitivity,
      'scrollSensitivity': scrollSensitivity,
      'reverseScroll': reverseScroll,
    };
  }
}
