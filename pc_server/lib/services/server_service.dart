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
    print('[SERVER_SERVICE] ===== SERVER SERVICE INITIALIZATION =====');

    print('[SERVER_SERVICE] Initializing trust service...');
    await _trustService.initialize();
    print('[SERVER_SERVICE] Trust service initialized');

    print('[SERVER_SERVICE] Initializing settings service...');
    await _settingsService.initialize();
    _currentPort = _settingsService.serverPort;
    print(
        '[SERVER_SERVICE] Settings loaded - Port: $_currentPort, Auto-start: ${_settingsService.autoStart}');

    // Auto-start if enabled
    if (_settingsService.autoStart) {
      print('[SERVER_SERVICE] Auto-start enabled - starting server...');
      await startServer();
    } else {
      print('[SERVER_SERVICE] Auto-start disabled');
    }

    print('[SERVER_SERVICE] Server service initialization complete');
  }

  /// Start the server
  Future<bool> startServer([int? port]) async {
    print('[SERVER_SERVICE] ===== STARTING SERVER =====');

    if (_isRunning) {
      print('[SERVER_SERVICE] Server already running - aborting start');
      _addLog('Server is already running');
      return false;
    }

    _currentPort = port ?? _currentPort;
    print('[SERVER_SERVICE] Starting server on port: $_currentPort');

    try {
      print('[SERVER_SERVICE] Adding startup log...');
      _addLog('Starting TouchPad Pro Server...');

      print('[SERVER_SERVICE] Starting network discovery service...');
      _discovery = NetworkDiscovery();
      await _discovery!.startAdvertising(_currentPort);
      print('[SERVER_SERVICE] Network discovery started successfully');

      print('[SERVER_SERVICE] Creating WebSocket handler...');
      final handler = webSocketHandler((WebSocketChannel webSocket) {
        print('[SERVER_SERVICE] New WebSocket connection received');
        _handleNewConnection(webSocket);
      });

      print('[SERVER_SERVICE] Starting HTTP server...');
      _server = await serve(handler, InternetAddress.anyIPv4, _currentPort);
      _isRunning = true;
      _serverStatusController.add(true);
      print('[SERVER_SERVICE] HTTP server started successfully');

      _addLog(
          'Server running on ws://${_server!.address.address}:${_server!.port}');
      _addLog('Ready to accept connections from mobile devices');
      print('[SERVER_SERVICE] Server logs added');

      print('[SERVER_SERVICE] Starting ping timer...');
      _startPingTimer();
      print('[SERVER_SERVICE] Ping timer started');

      print('[SERVER_SERVICE] Server startup complete!');
      return true;
    } catch (e) {
      print('[SERVER_SERVICE] ERROR: Failed to start server: $e');
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
    }); // Listen to WebSocket stream once for this device
    device.subscription = device.webSocket.stream.listen(
      (message) {
        print(
            '[SERVER_SERVICE] Received WebSocket message from ${device.ipAddress}: $message');
        try {
          final data = jsonDecode(message);
          print(
              '[SERVER_SERVICE] Parsed message data: $data'); // Handle device identification
          if (data['type'] == 'device_info') {
            print('[SERVER_SERVICE] Handling device identification');
            identificationTimer.cancel();
            // Don't cancel subscription - continue listening for regular messages
            _handleDeviceIdentification(device, data);
            return;
          }

          // Handle regular messages for already connected devices
          if (device.status == ConnectionStatus.connected) {
            print('[SERVER_SERVICE] Processing message for connected device');
            _handleMessage(message, device);
          } else {
            print(
                '[SERVER_SERVICE] Ignoring message from non-connected device (status: ${device.status})');
          }
        } catch (e) {
          print(
              '[SERVER_SERVICE] ERROR processing message from ${device.ipAddress}: $e');
          print('[SERVER_SERVICE] Stack trace: ${StackTrace.current}');
          _addLog('Error processing message from ${device.ipAddress}: $e');
        }
      },
      onDone: () {
        print(
            '[SERVER_SERVICE] WebSocket stream onDone for ${device.ipAddress}');
        _handleDisconnection(device);
      },
      onError: (error) {
        print(
            '[SERVER_SERVICE] WebSocket stream onError for ${device.ipAddress}: $error');
        _handleConnectionError(device, error);
      },
    );
  }

  /// Handle device identification and check trust
  void _handleDeviceIdentification(
      ConnectedDevice device, Map<String, dynamic> data) {
    print('[SERVER_SERVICE] Handling device identification...');

    // Update device info with proper identification
    final deviceName = data['device_name'] ?? 'Unknown Device';
    final deviceModel = data['device_model'] ?? '';
    final deviceId = data['device_id']; // Get the unique device ID from client

    print('[SERVER_SERVICE] Received device info:');
    print('[SERVER_SERVICE]   Name: $deviceName');
    print('[SERVER_SERVICE]   Model: $deviceModel');
    print('[SERVER_SERVICE]   ID: $deviceId');

    // Use the device ID from the client if provided, otherwise generate one
    String finalDeviceId;
    if (deviceId != null && deviceId.toString().isNotEmpty) {
      finalDeviceId = 'mobile_$deviceId'; // Prefix to identify mobile devices
      print('[SERVER_SERVICE] Using client-provided device ID: $finalDeviceId');
    } else {
      // Fallback to generating ID (for compatibility with older clients)
      finalDeviceId = _generateConsistentDeviceId(
          device.ipAddress, deviceName, deviceModel);
      print('[SERVER_SERVICE] Generated fallback device ID: $finalDeviceId');
    }

    // Check if we already have a device with this ID connected
    final existingDevice = _connectedDevices
        .where((d) => d.id == finalDeviceId && d != device)
        .firstOrNull;
    if (existingDevice != null) {
      print(
          '[SERVER_SERVICE] Device with ID $finalDeviceId already connected, disconnecting old connection');
      // Disconnect the old connection
      try {
        existingDevice.webSocket.sink.close();
        existingDevice.subscription?.cancel();
        _connectedDevices.remove(existingDevice);
        _addLog(
            'Disconnected duplicate device: ${existingDevice.name} (${existingDevice.ipAddress})');
      } catch (e) {
        print('[SERVER_SERVICE] Error disconnecting old device: $e');
      }
    }    // Update device with proper info
    device.name = deviceName.isNotEmpty ? deviceName : (deviceModel.isNotEmpty ? deviceModel : 'Unknown Device');
    device.id = finalDeviceId;

    _addLog(
        'Device identified: ${device.name} (ID: ${finalDeviceId.replaceFirst('mobile_', '')}) - IP: ${device.ipAddress}');

    // Check if device is trusted
    final isTrusted = _trustService.isDeviceTrusted(finalDeviceId);
    print('[SERVER_SERVICE] Device trust status: $isTrusted');

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

    // The stream listener is already set up in _waitForDeviceIdentification
    // We just need to ensure it continues to handle regular messages
    print(
        '[SERVER_SERVICE] Device ${device.name} connected and ready to receive messages');
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
    print('[SERVER_SERVICE] _handleMessage called for device: ${device.name}');
    print('[SERVER_SERVICE] Message: $message');

    try {
      final data = jsonDecode(message);
      final type = data['type'] as String?;
      print('[SERVER_SERVICE] Parsed message type: $type');

      switch (type) {
        case 'device_info':
          print('[SERVER_SERVICE] Handling device_info message');
          // This should already be handled in device identification
          break;
        case 'pong':
          print('[SERVER_SERVICE] Handling pong message');
          // Device responded to ping - connection is alive
          device.lastActivity = DateTime.now();
          break;
        case 'move':
        case 'click':
        case 'rightClick':
        case 'scroll':
        case 'disconnect':
          print('[SERVER_SERVICE] Handling input message: $type');
          // CRITICAL FIX: Handle async function properly to prevent crashes
          _handleTouchInput(data, device).catchError((error) {
            print('[SERVER_SERVICE] ERROR in _handleTouchInput: $error');
            print('[SERVER_SERVICE] Stack trace: ${StackTrace.current}');
            _addLog('Error handling input from ${device.name}: $error');
          });
          device.lastActivity = DateTime.now();
          break;
        default:
          print('[SERVER_SERVICE] Unknown message type: $type');
          _addLog('Unknown message type from ${device.name}: $type');
      }
    } catch (e) {
      print(
          '[SERVER_SERVICE] ERROR processing message from ${device.name}: $e');
      print('[SERVER_SERVICE] Stack trace: ${StackTrace.current}');
      _addLog('Error processing message from ${device.name}: $e');
    }
  }

  /// Handle device disconnection
  void _handleDisconnection(ConnectedDevice device) {
    print('[SERVER_SERVICE] Handling disconnection for device: ${device.name}');

    // Cancel subscription if active
    if (device.subscription != null) {
      print('[SERVER_SERVICE] Cancelling subscription for ${device.name}');
      device.subscription!.cancel();
      device.subscription = null;
    }

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
    print(
        '[SERVER_SERVICE] _handleTouchInput called for device: ${device.name}');
    print('[SERVER_SERVICE] Input data: $data');

    try {
      final type = data['type'] as String?;
      final deltaX = (data['deltaX'] as num?)?.toDouble();
      final deltaY = (data['deltaY'] as num?)?.toDouble();

      print('[SERVER_SERVICE] Processing input type: $type');
      if (deltaX != null) print('[SERVER_SERVICE] deltaX: $deltaX');
      if (deltaY != null) print('[SERVER_SERVICE] deltaY: $deltaY');

      switch (type) {
        case 'move':
          if (deltaX != null && deltaY != null) {
            print('[SERVER_SERVICE] Calling mouse controller moveMouse...');
            await _mouseController.moveMouse(deltaX, deltaY);
            print('[SERVER_SERVICE] Mouse move completed successfully');
            device.totalActions++;
          } else {
            print(
                '[SERVER_SERVICE] WARNING: Move command missing deltaX or deltaY');
          }
          break;
        case 'click':
          print('[SERVER_SERVICE] Calling mouse controller leftClick...');
          await _mouseController.leftClick();
          print('[SERVER_SERVICE] Left click completed successfully');
          device.totalActions++;
          break;
        case 'rightClick':
          print('[SERVER_SERVICE] Calling mouse controller rightClick...');
          await _mouseController.rightClick();
          print('[SERVER_SERVICE] Right click completed successfully');
          device.totalActions++;
          break;
        case 'scroll':
          if (deltaY != null) {
            print('[SERVER_SERVICE] Calling mouse controller scroll...');
            await _mouseController.scroll(deltaY);
            print('[SERVER_SERVICE] Scroll completed successfully');
            device.totalActions++;
          } else {
            print('[SERVER_SERVICE] WARNING: Scroll command missing deltaY');
          }
          break;
        case 'disconnect':
          print('[SERVER_SERVICE] Device requested disconnection');
          _addLog('${device.name} requested disconnection');
          disconnectDevice(device);
          break;
        default:
          print('[SERVER_SERVICE] Unknown input type: $type');
          _addLog('Unknown input type from ${device.name}: $type');
      }
      print('[SERVER_SERVICE] _handleTouchInput completed successfully');
    } catch (e) {
      print('[SERVER_SERVICE] ERROR in _handleTouchInput: $e');
      print('[SERVER_SERVICE] Stack trace: ${StackTrace.current}');
      _addLog('Error handling input from ${device.name}: $e');
      // Don't disconnect on input errors, just log them
    }
  }
  /// Extract device information from WebSocket connection
  Map<String, String> _extractDeviceInfo(WebSocketChannel webSocket) {
    // In a real implementation, this would extract info from headers or handshake
    return {
      'name': 'Unknown Device',
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
  StreamSubscription? subscription; // Add subscription field

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
