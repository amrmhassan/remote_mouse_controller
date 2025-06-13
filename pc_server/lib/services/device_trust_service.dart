import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for managing trusted devices
class DeviceTrustService {
  static const String _trustedDevicesKey = 'trusted_devices';

  SharedPreferences? _prefs;
  Map<String, TrustedDevice> _trustedDevices = {};

  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadTrustedDevices();
  }

  /// Check if a device is trusted
  bool isDeviceTrusted(String deviceId) {
    return _trustedDevices.containsKey(deviceId);
  }

  /// Trust a device
  Future<void> trustDevice(String deviceId, String deviceName) async {
    final trustedDevice = TrustedDevice(
      id: deviceId,
      name: deviceName,
      trustedAt: DateTime.now(),
    );

    _trustedDevices[deviceId] = trustedDevice;
    await _saveTrustedDevices();
  }

  /// Remove trust from a device
  Future<void> untrustDevice(String deviceId) async {
    _trustedDevices.remove(deviceId);
    await _saveTrustedDevices();
  }

  /// Get all trusted devices
  List<TrustedDevice> getTrustedDevices() {
    return _trustedDevices.values.toList()
      ..sort((a, b) => b.trustedAt.compareTo(a.trustedAt));
  }

  /// Get trusted device by ID
  TrustedDevice? getTrustedDevice(String deviceId) {
    return _trustedDevices[deviceId];
  }

  /// Update device name
  Future<void> updateDeviceName(String deviceId, String newName) async {
    final device = _trustedDevices[deviceId];
    if (device != null) {
      _trustedDevices[deviceId] = device.copyWith(name: newName);
      await _saveTrustedDevices();
    }
  }

  /// Clear all trusted devices
  Future<void> clearAllTrustedDevices() async {
    _trustedDevices.clear();
    await _saveTrustedDevices();
  }

  /// Load trusted devices from storage
  Future<void> _loadTrustedDevices() async {
    final devicesJson = _prefs?.getString(_trustedDevicesKey);
    if (devicesJson != null) {
      try {
        final Map<String, dynamic> devicesMap = jsonDecode(devicesJson);
        _trustedDevices = devicesMap.map(
          (key, value) => MapEntry(key, TrustedDevice.fromJson(value)),
        );
      } catch (e) {
        print('Error loading trusted devices: $e');
        _trustedDevices = {};
      }
    }
  }

  /// Save trusted devices to storage
  Future<void> _saveTrustedDevices() async {
    final devicesMap = _trustedDevices.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    final devicesJson = jsonEncode(devicesMap);
    await _prefs?.setString(_trustedDevicesKey, devicesJson);
  }
}

/// Trusted device model
class TrustedDevice {
  final String id;
  final String name;
  final DateTime trustedAt;
  final DateTime? lastSeen;

  const TrustedDevice({
    required this.id,
    required this.name,
    required this.trustedAt,
    this.lastSeen,
  });

  /// Create a copy with updated fields
  TrustedDevice copyWith({
    String? name,
    DateTime? lastSeen,
  }) {
    return TrustedDevice(
      id: id,
      name: name ?? this.name,
      trustedAt: trustedAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'trustedAt': trustedAt.toIso8601String(),
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory TrustedDevice.fromJson(Map<String, dynamic> json) {
    return TrustedDevice(
      id: json['id'],
      name: json['name'],
      trustedAt: DateTime.parse(json['trustedAt']),
      lastSeen:
          json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
    );
  }

  @override
  String toString() {
    return 'TrustedDevice(id: $id, name: $name, trustedAt: $trustedAt)';
  }
}
