import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../src/mouse_controller.dart';
import '../src/network_discovery.dart';
import 'device_trust_service.dart';
import 'settings_service.dart';

/// Enhanced server service with device trust and beautiful UI integration
class ServerService {
  HttpServer? _server;
  NetworkDiscovery? _discovery;
  final MouseController _mouseController = MouseController();
  final DeviceTrustService _trustService = DeviceTrustService();
  final SettingsService _settingsService = SettingsService();

  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  final StreamController<ConnectedDevice> _deviceController =
      StreamController<ConnectedDevice>.broadcast();
  final StreamController<bool> _serverStatusController =
      StreamController<bool>.broadcast();

  List<ConnectedDevice> _connectedDevices = [];
  bool _isRunning = false;
  int _currentPort = 8080;
  Timer? _pingTimer;

  // Streams for UI updates
  Stream<String> get logStream => _logController.stream;
  Stream<ConnectedDevice> get deviceStream => _deviceController.stream;
  Stream<bool> get serverStatusStream => _serverStatusController.stream;

  // Getters
  bool get isRunning => _isRunning;
  int get currentPort => _currentPort;
  List<ConnectedDevice> get connectedDevices => _connectedDevices;

  /// Initialize the server service
  Future<void> initialize() async {
    await _trustService.initialize();
    await _settingsService.initialize();
    _currentPort = _settingsService.serverPort;

    // Auto-start if enabled
    if (_settingsService.autoStart) {
      await startServer();
    }
  }

  /// Start the server
  Future<bool> startServer([int? port]) async {
    if (_isRunning) {
      _addLog('Server is already running');
      return false;
    }

    _currentPort = port ?? _currentPort;

    try {
      _addLog('Starting TouchPad Pro Server...');

      // Start network discovery service
      _discovery = NetworkDiscovery();
      await _discovery!.startAdvertising(_currentPort);

      // Create WebSocket handler with device trust
      final handler = webSocketHandler((WebSocketChannel webSocket) {
        _handleNewConnection(webSocket);
      });

      // Start the server
      _server = await serve(handler, InternetAddress.anyIPv4, _currentPort);
      _isRunning = true;
      _serverStatusController.add(true);
      _addLog(
          'Server running on ws://${_server!.address.address}:${_server!.port}');
      _addLog('Ready to accept connections from mobile devices');

      // Start periodic ping to keep connections alive
      _startPingTimer();

      return true;
    } catch (e) {
      _addLog('Failed to start server: $e');
      _isRunning = false;
      _serverStatusController.add(false);
      return false;
    }
  }

  /// Stop the server
  Future<void> stopServer() async {
    if (!_isRunning) {
      _addLog('Server is not running');
      return;
    }

    _addLog('Stopping server...');

    // Notify all clients that server is stopping
    _broadcastServerStatus(false);

    // Wait a moment for the message to be sent
    await Future.delayed(Duration(milliseconds: 500)); // Disconnect all clients
    for (var device in _connectedDevices) {
      device.webSocket.sink.close();
    }
    _connectedDevices.clear();

    // Stop server and discovery
    await _discovery?.stopAdvertising();
    await _server?.close();

    // Stop ping timer
    _pingTimer?.cancel();
    _pingTimer = null;

    _isRunning = false;
    _serverStatusController.add(false);
    _addLog('Server stopped');
  }

  /// Broadcast server status to all connected clients
  void _broadcastServerStatus(bool isRunning) {
    final statusMessage = jsonEncode({
      'type': 'server_status',
      'running': isRunning,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    for (var device in _connectedDevices) {
      try {
        device.webSocket.sink.add(statusMessage);
      } catch (e) {
        _addLog('Failed to send status to ${device.name}: $e');
      }
    }
  }

  /// Handle new WebSocket connection
  void _handleNewConnection(WebSocketChannel webSocket) {
    final deviceInfo = _extractDeviceInfo(webSocket);
    final device = ConnectedDevice(
      name: deviceInfo['name'] ?? 'Unknown Device',
      ipAddress: deviceInfo['ip'] ?? 'Unknown IP',
      id: deviceInfo['id'] ??
          'unknown_${DateTime.now().millisecondsSinceEpoch}',
      webSocket: webSocket,
      connectedAt: DateTime.now(),
    );

    // Wait for device identification message
    _waitForDeviceIdentification(device);
  }

  /// Wait for device identification message to get proper device info
  void _waitForDeviceIdentification(ConnectedDevice device) {
    // Set a timeout for device identification
    final identificationTimer = Timer(Duration(seconds: 10), () {
      _addLog('Device identification timeout for ${device.ipAddress}');
      device.webSocket.sink.close();
    });

    // Listen to WebSocket stream once for this device
    late StreamSubscription subscription;
    subscription = device.webSocket.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);

          // Handle device identification
          if (data['type'] == 'device_info') {
            identificationTimer.cancel();
            subscription.cancel(); // Stop listening on this subscription
            _handleDeviceIdentification(device, data);
            return;
          }

          // Handle regular messages for already connected devices
          if (device.status == ConnectionStatus.connected) {
            _handleMessage(message, device);
          }
        } catch (e) {
          _addLog('Error processing message from ${device.ipAddress}: $e');
        }
      },
      onDone: () => _handleDisconnection(device),
      onError: (error) => _handleConnectionError(device, error),
    );
  }

  /// Handle device identification and check trust
  void _handleDeviceIdentification(
      ConnectedDevice device, Map<String, dynamic> data) {
    // Update device info with proper identification
    final deviceName = data['device_name'] ?? 'Unknown Device';
    final deviceModel = data['device_model'] ?? '';

    // Create a consistent device ID based on device characteristics
    final deviceId =
        _generateConsistentDeviceId(device.ipAddress, deviceName, deviceModel);

    // Update device with proper info
    device.name = deviceName.isNotEmpty ? deviceName : 'Mobile Device';
    device.id = deviceId;

    _addLog(
        'Device identified: ${device.name} (${device.ipAddress}) - ID: $deviceId');

    // Check if device is trusted
    final isTrusted = _trustService.isDeviceTrusted(deviceId);

    if (!isTrusted && _settingsService.requirePermission) {
      // Ask for permission (this will be handled by UI)
      _requestDevicePermission(device);
    } else {
      if (isTrusted) {
        _addLog('Auto-connecting trusted device: ${device.name}');
      }
      _acceptConnection(device);
    }
  }

  /// Generate a consistent device ID based on device characteristics
  String _generateConsistentDeviceId(
      String ipAddress, String deviceName, String deviceModel) {
    // Use a combination of IP address and device info to create a consistent ID
    // This is more reliable than timestamp-based IDs
    final combined = '$ipAddress-$deviceName-$deviceModel';
    return 'device_${combined.hashCode.abs()}';
  }

  /// Request permission for device connection
  void _requestDevicePermission(ConnectedDevice device) {
    _addLog(
        'New device requesting connection: ${device.name} (${device.ipAddress})');
    device.status = ConnectionStatus.pending;
    _deviceController.add(device);
  }

  /// Accept device connection
  void _acceptConnection(ConnectedDevice device) {
    device.status = ConnectionStatus.connected;
    _connectedDevices.add(device);
    _deviceController.add(device);

    _addLog('Device connected: ${device.name} (${device.ipAddress})');

    // For already identified devices, start listening to regular messages
    // The stream is already being listened to in _waitForDeviceIdentification
    // So we don't need to add another listener here
  }

  /// Reject device connection
  void rejectConnection(ConnectedDevice device) {
    device.webSocket.sink.close();
    _addLog('Connection rejected: ${device.name} (${device.ipAddress})');
  }

  /// Trust a device
  void trustDevice(ConnectedDevice device, {bool remember = true}) {
    if (remember) {
      _trustService.trustDevice(device.id, device.name);
    }

    if (device.status == ConnectionStatus.pending) {
      _acceptConnection(device);
    } else {
      // Update UI to reflect trust status change
      _deviceController.add(device);
    }

    _addLog('Device trusted: ${device.name}');
  }

  /// Untrust a device
  Future<void> untrustDevice(String deviceId) async {
    await _trustService.untrustDevice(deviceId);

    // Find and update any connected device with this ID
    final device = _connectedDevices.where((d) => d.id == deviceId).firstOrNull;
    if (device != null) {
      _deviceController.add(device);
      _addLog('Device untrusted: ${device.name}');
    }
  }

  /// Check if device is trusted
  bool isDeviceTrusted(String deviceId) {
    return _trustService.isDeviceTrusted(deviceId);
  }

  /// Get all trusted devices
  List<TrustedDevice> getTrustedDevices() {
    return _trustService.getTrustedDevices();
  }

  /// Disconnect a specific device
  void disconnectDevice(ConnectedDevice device) {
    device.webSocket.sink.close();
    _connectedDevices.remove(device);
    device.status = ConnectionStatus.disconnected;
    _deviceController.add(device);
    _addLog('Device disconnected: ${device.name}');
  }

  /// Handle incoming message from device
  void _handleMessage(dynamic message, ConnectedDevice device) {
    try {
      final data = jsonDecode(message);
      final type = data['type'] as String?;

      switch (type) {
        case 'device_info':
          // This should already be handled in device identification
          break;
        case 'pong':
          // Device responded to ping - connection is alive
          device.lastActivity = DateTime.now();
          break;
        case 'move':
        case 'click':
        case 'rightClick':
        case 'scroll':
        case 'disconnect':
          _handleTouchInput(data, device);
          device.lastActivity = DateTime.now();
          break;
        default:
          _addLog('Unknown message type from ${device.name}: $type');
      }
    } catch (e) {
      _addLog('Error processing message from ${device.name}: $e');
    }
  }

  /// Handle device disconnection
  void _handleDisconnection(ConnectedDevice device) {
    _connectedDevices.remove(device);
    device.status = ConnectionStatus.disconnected;
    _deviceController.add(device);
    _addLog('Device disconnected: ${device.name}');
  }

  /// Handle connection error
  void _handleConnectionError(ConnectedDevice device, dynamic error) {
    _addLog('Connection error with ${device.name}: $error');
    _handleDisconnection(device);
  }

  /// Handle touch input with device context
  Future<void> _handleTouchInput(
      Map<String, dynamic> data, ConnectedDevice device) async {
    final type = data['type'] as String?;
    final deltaX = (data['deltaX'] as num?)?.toDouble();
    final deltaY = (data['deltaY'] as num?)?.toDouble();

    switch (type) {
      case 'move':
        if (deltaX != null && deltaY != null) {
          await _mouseController.moveMouse(deltaX, deltaY);
          device.totalActions++;
        }
        break;
      case 'click':
        await _mouseController.leftClick();
        device.totalActions++;
        break;
      case 'rightClick':
        await _mouseController.rightClick();
        device.totalActions++;
        break;
      case 'scroll':
        if (deltaY != null) {
          await _mouseController.scroll(deltaY);
          device.totalActions++;
        }
        break;
      case 'disconnect':
        _addLog('${device.name} requested disconnection');
        disconnectDevice(device);
        break;
      default:
        _addLog('Unknown input type from ${device.name}: $type');
    }
  }

  /// Extract device information from WebSocket connection
  Map<String, String> _extractDeviceInfo(WebSocketChannel webSocket) {
    // In a real implementation, this would extract info from headers or handshake
    return {
      'name': 'Mobile Device',
      'ip': 'Unknown IP',
      'id': 'device_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  /// Add log entry
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logEntry = '[$timestamp] $message';
    print(logEntry);
    _logController.add(logEntry);
  }

  /// Dispose resources
  void dispose() {
    _pingTimer?.cancel();
    stopServer();
    _logController.close();
    _deviceController.close();
    _serverStatusController.close();
  }

  /// Start periodic ping timer to keep connections alive
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _pingAllDevices();
    });
  }

  /// Send ping to all connected devices
  void _pingAllDevices() {
    final pingMessage = jsonEncode({
      'type': 'ping',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final devicesToRemove = <ConnectedDevice>[];

    for (var device in _connectedDevices) {
      try {
        device.webSocket.sink.add(pingMessage);
      } catch (e) {
        _addLog('Failed to ping ${device.name}: $e');
        devicesToRemove.add(device);
      }
    }

    // Remove devices that failed to ping
    for (var device in devicesToRemove) {
      _handleDisconnection(device);
    }
  }
}

/// Connected device information
class ConnectedDevice {
  String name;
  final String ipAddress;
  String id;
  final WebSocketChannel webSocket;
  final DateTime connectedAt;

  DateTime lastActivity;
  ConnectionStatus status;
  int totalActions;

  ConnectedDevice({
    required this.name,
    required this.ipAddress,
    required this.id,
    required this.webSocket,
    required this.connectedAt,
    this.status = ConnectionStatus.pending,
    this.totalActions = 0,
  }) : lastActivity = connectedAt;

  Duration get connectionDuration => DateTime.now().difference(connectedAt);
  Duration get timeSinceLastActivity => DateTime.now().difference(lastActivity);
}

/// Connection status enum
enum ConnectionStatus {
  pending,
  connected,
  disconnected,
}
