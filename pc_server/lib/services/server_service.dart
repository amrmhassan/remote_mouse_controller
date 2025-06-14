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
import '../utils/debug_logger.dart';

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
    DebugLogger.log('Server service initialization starting...',
        tag: 'SERVER_SERVICE');

    DebugLogger.log('Initializing trust service...', tag: 'SERVER_SERVICE');
    await _trustService.initialize();
    DebugLogger.log('Initializing settings service...', tag: 'SERVER_SERVICE');
    await _settingsService.initialize();
    _currentPort = _settingsService.serverPort;
    DebugLogger.log(
        'Settings loaded - Port: $_currentPort, Auto-start: ${_settingsService.autoStart}',
        tag: 'SERVER_SERVICE');

    // Auto-start if enabled
    if (_settingsService.autoStart) {
      DebugLogger.log('Auto-start enabled - starting server...',
          tag: 'SERVER_SERVICE');
      await startServer();
    } else {
      DebugLogger.log('Auto-start disabled', tag: 'SERVER_SERVICE');
    }

    DebugLogger.log('Server service initialization complete',
        tag: 'SERVER_SERVICE');
  }

  /// Start the server
  Future<bool> startServer([int? port]) async {
    DebugLogger.log('===== STARTING SERVER =====', tag: 'SERVER_SERVICE');

    if (_isRunning) {
      DebugLogger.log('Server already running - aborting start',
          tag: 'SERVER_SERVICE');
      _addLog('Server is already running');
      return false;
    }

    _currentPort = port ?? _currentPort;
    DebugLogger.log('Starting server on port: $_currentPort',
        tag: 'SERVER_SERVICE');
    try {
      DebugLogger.log('Adding startup log...', tag: 'SERVER_SERVICE');
      _addLog('Starting TouchPad Pro Server...');

      DebugLogger.log('Starting network discovery service...',
          tag: 'SERVER_SERVICE');
      _discovery = NetworkDiscovery();
      await _discovery!.startAdvertising(_currentPort);
      DebugLogger.log('Network discovery started successfully',
          tag: 'SERVER_SERVICE');

      DebugLogger.log('Creating WebSocket handler...', tag: 'SERVER_SERVICE');
      final handler = webSocketHandler((WebSocketChannel webSocket) {
        DebugLogger.log('New WebSocket connection received',
            tag: 'SERVER_SERVICE');
        _handleNewConnection(webSocket);
      });

      DebugLogger.log('Starting HTTP server...', tag: 'SERVER_SERVICE');
      _server = await serve(handler, InternetAddress.anyIPv4, _currentPort);
      _isRunning = true;
      _serverStatusController.add(true);
      DebugLogger.log('HTTP server started successfully',
          tag: 'SERVER_SERVICE');
      _addLog(
          'Server running on ws://${_server!.address.address}:${_server!.port}');
      _addLog('Ready to accept connections from mobile devices');
      DebugLogger.log('Server logs added', tag: 'SERVER_SERVICE');

      DebugLogger.log('Starting ping timer...', tag: 'SERVER_SERVICE');
      _startPingTimer();
      DebugLogger.log('Ping timer started', tag: 'SERVER_SERVICE');

      DebugLogger.log('Server startup complete!', tag: 'SERVER_SERVICE');
      return true;
    } catch (e) {
      DebugLogger.error('Failed to start server',
          tag: 'SERVER_SERVICE', error: e);
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
    device.subscription = device.webSocket.stream.listen(
      (message) {
        DebugLogger.log(
            'Received WebSocket message from ${device.ipAddress}: $message',
            tag: 'SERVER_SERVICE');
        try {
          final data = jsonDecode(message);
          DebugLogger.log('Parsed message data: $data',
              tag: 'SERVER_SERVICE'); // Handle device identification
          if (data['type'] == 'device_info') {
            DebugLogger.log('Handling device identification',
                tag: 'SERVER_SERVICE');
            identificationTimer.cancel();
            // Don't cancel subscription - continue listening for regular messages
            _handleDeviceIdentification(device, data);
            return;
          }

          // Handle regular messages for already connected devices
          if (device.status == ConnectionStatus.connected) {
            DebugLogger.log('Processing message for connected device',
                tag: 'SERVER_SERVICE');
            _handleMessage(message, device);
          } else {
            DebugLogger.log(
                'Ignoring message from non-connected device (status: ${device.status})',
                tag: 'SERVER_SERVICE');
          }
        } catch (e) {
          DebugLogger.error('Error processing message from ${device.ipAddress}',
              tag: 'SERVER_SERVICE', error: e);
          DebugLogger.log('Stack trace: ${StackTrace.current}',
              tag: 'SERVER_SERVICE');
          _addLog('Error processing message from ${device.ipAddress}: $e');
        }
      },
      onDone: () {
        DebugLogger.log('WebSocket stream onDone for ${device.ipAddress}',
            tag: 'SERVER_SERVICE');
        _handleDisconnection(device);
      },
      onError: (error) {
        DebugLogger.error('WebSocket stream onError for ${device.ipAddress}',
            tag: 'SERVER_SERVICE', error: error);
        _handleConnectionError(device, error);
      },
    );
  }

  /// Handle device identification and check trust
  void _handleDeviceIdentification(
      ConnectedDevice device, Map<String, dynamic> data) {
    DebugLogger.log('Handling device identification...', tag: 'SERVER_SERVICE');

    // Update device info with proper identification
    final deviceName = data['device_name'] ?? 'Unknown Device';
    final deviceModel = data['device_model'] ?? '';
    final deviceId = data['device_id']; // Get the unique device ID from client

    DebugLogger.log('Received device info:', tag: 'SERVER_SERVICE');
    DebugLogger.log('  Name: $deviceName', tag: 'SERVER_SERVICE');
    DebugLogger.log('  Model: $deviceModel', tag: 'SERVER_SERVICE');
    DebugLogger.log('  ID: $deviceId', tag: 'SERVER_SERVICE');

    // Use the device ID from the client if provided, otherwise generate one
    String finalDeviceId;
    if (deviceId != null && deviceId.toString().isNotEmpty) {
      finalDeviceId = 'mobile_$deviceId'; // Prefix to identify mobile devices
      DebugLogger.log('Using client-provided device ID: $finalDeviceId',
          tag: 'SERVER_SERVICE');
    } else {
      // Fallback to generating ID (for compatibility with older clients)
      finalDeviceId = _generateConsistentDeviceId(
          device.ipAddress, deviceName, deviceModel);
      DebugLogger.log('Generated fallback device ID: $finalDeviceId',
          tag: 'SERVER_SERVICE');
    }

    // Check if we already have a device with this ID connected
    final existingDevice = _connectedDevices
        .where((d) => d.id == finalDeviceId && d != device)
        .firstOrNull;
    if (existingDevice != null) {
      DebugLogger.log(
          'Device with ID $finalDeviceId already connected, disconnecting old connection',
          tag: 'SERVER_SERVICE');
      // Disconnect the old connection
      try {
        existingDevice.webSocket.sink.close();
        existingDevice.subscription?.cancel();
        _connectedDevices.remove(existingDevice);
        _addLog(
            'Disconnected duplicate device: ${existingDevice.name} (${existingDevice.ipAddress})');
      } catch (e) {
        DebugLogger.error('Error disconnecting old device',
            tag: 'SERVER_SERVICE', error: e);
      }
    }

    // Update device with proper info
    device.name = deviceName.isNotEmpty
        ? deviceName
        : (deviceModel.isNotEmpty ? deviceModel : 'Unknown Device');
    device.id = finalDeviceId;

    _addLog(
        'Device identified: ${device.name} (ID: ${finalDeviceId.replaceFirst('mobile_', '')}) - IP: ${device.ipAddress}');

    // Check if device is trusted
    final isTrusted = _trustService.isDeviceTrusted(finalDeviceId);
    DebugLogger.log('Device trust status: $isTrusted', tag: 'SERVER_SERVICE');

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
    DebugLogger.log(
        'Device ${device.name} connected and ready to receive messages',
        tag: 'SERVER_SERVICE');
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
    DebugLogger.log('_handleMessage called for device: ${device.name}',
        tag: 'SERVER_SERVICE');
    DebugLogger.log('Message: $message', tag: 'SERVER_SERVICE');

    try {
      final data = jsonDecode(message);
      final type = data['type'] as String?;
      DebugLogger.log('Parsed message type: $type', tag: 'SERVER_SERVICE');

      switch (type) {
        case 'device_info':
          DebugLogger.log('Handling device_info message',
              tag: 'SERVER_SERVICE');
          // This should already be handled in device identification
          break;
        case 'pong':
          DebugLogger.log('Handling pong message', tag: 'SERVER_SERVICE');
          // Device responded to ping - connection is alive
          device.lastActivity = DateTime.now();
          break;
        case 'move':
        case 'click':
        case 'rightClick':
        case 'scroll':
        case 'mouseDownLeft':
        case 'mouseUpLeft':
        case 'disconnect':
          DebugLogger.log('Handling input message: $type',
              tag: 'SERVER_SERVICE');
          // CRITICAL FIX: Handle async function properly to prevent crashes
          _handleTouchInput(data, device).catchError((error) {
            DebugLogger.error('Error in _handleTouchInput',
                tag: 'SERVER_SERVICE', error: error);
            DebugLogger.log('Stack trace: ${StackTrace.current}',
                tag: 'SERVER_SERVICE');
            _addLog('Error handling input from ${device.name}: $error');
          });
          device.lastActivity = DateTime.now();
          break;
        default:
          DebugLogger.log('Unknown message type: $type', tag: 'SERVER_SERVICE');
          _addLog('Unknown message type from ${device.name}: $type');
      }
    } catch (e) {
      DebugLogger.error('Error processing message from ${device.name}',
          tag: 'SERVER_SERVICE', error: e);
      DebugLogger.log('Stack trace: ${StackTrace.current}',
          tag: 'SERVER_SERVICE');
      _addLog('Error processing message from ${device.name}: $e');
    }
  }

  /// Handle device disconnection
  void _handleDisconnection(ConnectedDevice device) {
    DebugLogger.log('Handling disconnection for device: ${device.name}',
        tag: 'SERVER_SERVICE');

    // Cancel subscription if active
    if (device.subscription != null) {
      DebugLogger.log('Cancelling subscription for ${device.name}',
          tag: 'SERVER_SERVICE');
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
    DebugLogger.log('_handleTouchInput called for device: ${device.name}',
        tag: 'SERVER_SERVICE');
    DebugLogger.log('Input data: $data', tag: 'SERVER_SERVICE');

    try {
      final type = data['type'] as String?;
      final deltaX = (data['deltaX'] as num?)?.toDouble();
      final deltaY = (data['deltaY'] as num?)?.toDouble();
      DebugLogger.log('Processing input type: $type', tag: 'SERVER_SERVICE');
      if (deltaX != null)
        DebugLogger.log('deltaX: $deltaX', tag: 'SERVER_SERVICE');
      if (deltaY != null)
        DebugLogger.log('deltaY: $deltaY', tag: 'SERVER_SERVICE');

      switch (type) {
        case 'move':
          if (deltaX != null && deltaY != null) {
            DebugLogger.log('Calling mouse controller moveMouse...',
                tag: 'SERVER_SERVICE');
            await _mouseController.moveMouse(deltaX, deltaY);
            DebugLogger.log('Mouse move completed successfully',
                tag: 'SERVER_SERVICE');
            device.totalActions++;
          } else {
            DebugLogger.log('WARNING: Move command missing deltaX or deltaY',
                tag: 'SERVER_SERVICE');
          }
          break;
        case 'click':
          DebugLogger.log('Calling mouse controller leftClick...',
              tag: 'SERVER_SERVICE');
          await _mouseController.leftClick();
          DebugLogger.log('Left click completed successfully',
              tag: 'SERVER_SERVICE');
          device.totalActions++;
          break;
        case 'rightClick':
          DebugLogger.log('Calling mouse controller rightClick...',
              tag: 'SERVER_SERVICE');
          await _mouseController.rightClick();
          DebugLogger.log('Right click completed successfully',
              tag: 'SERVER_SERVICE');
          device.totalActions++;
          break;
        case 'scroll':
          if (deltaY != null) {
            DebugLogger.log('Calling mouse controller scroll...',
                tag: 'SERVER_SERVICE');
            await _mouseController.scroll(deltaY);
            DebugLogger.log('Scroll completed successfully',
                tag: 'SERVER_SERVICE');
            device.totalActions++;
          } else {
            DebugLogger.log('WARNING: Scroll command missing deltaY',
                tag: 'SERVER_SERVICE');
          }
          break;
        case 'mouseDownLeft':
          DebugLogger.log('Calling mouse controller mouseDownLeft...',
              tag: 'SERVER_SERVICE');
          await _mouseController.mouseDownLeft();
          DebugLogger.log('Mouse down left completed successfully',
              tag: 'SERVER_SERVICE');
          device.totalActions++;
          break;
        case 'mouseUpLeft':
          DebugLogger.log('Calling mouse controller mouseUpLeft...',
              tag: 'SERVER_SERVICE');
          await _mouseController.mouseUpLeft();
          DebugLogger.log('Mouse up left completed successfully',
              tag: 'SERVER_SERVICE');
          device.totalActions++;
          break;
        case 'disconnect':
          DebugLogger.log('Device requested disconnection',
              tag: 'SERVER_SERVICE');
          _addLog('${device.name} requested disconnection');
          disconnectDevice(device);
          break;
        default:
          DebugLogger.log('Unknown input type: $type', tag: 'SERVER_SERVICE');
          _addLog('Unknown input type from ${device.name}: $type');
      }
      DebugLogger.log('_handleTouchInput completed successfully',
          tag: 'SERVER_SERVICE');
    } catch (e) {
      DebugLogger.error('Error in _handleTouchInput',
          tag: 'SERVER_SERVICE', error: e);
      DebugLogger.log('Stack trace: ${StackTrace.current}',
          tag: 'SERVER_SERVICE');
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
    DebugLogger.log(logEntry, tag: 'SERVER_LOG');
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
