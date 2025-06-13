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
  
  final StreamController<String> _logController = StreamController<String>.broadcast();
  final StreamController<ConnectedDevice> _deviceController = StreamController<ConnectedDevice>.broadcast();
  final StreamController<bool> _serverStatusController = StreamController<bool>.broadcast();
  
  List<ConnectedDevice> _connectedDevices = [];
  bool _isRunning = false;
  int _currentPort = 8080;

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
      
      _addLog('Server running on ws://${_server!.address.address}:${_server!.port}');
      _addLog('Ready to accept connections from mobile devices');
      
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
    
    // Disconnect all clients
    for (var device in _connectedDevices) {
      device.webSocket.sink.close();
    }
    _connectedDevices.clear();

    // Stop server and discovery
    await _discovery?.stopAdvertising();
    await _server?.close();
    
    _isRunning = false;
    _serverStatusController.add(false);
    _addLog('Server stopped');
  }

  /// Handle new WebSocket connection
  void _handleNewConnection(WebSocketChannel webSocket) {
    final deviceInfo = _extractDeviceInfo(webSocket);
    final device = ConnectedDevice(
      name: deviceInfo['name'] ?? 'Unknown Device',
      ipAddress: deviceInfo['ip'] ?? 'Unknown IP',
      id: deviceInfo['id'] ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}',
      webSocket: webSocket,
      connectedAt: DateTime.now(),
    );

    // Check if device is trusted
    final isTrusted = _trustService.isDeviceTrusted(device.id);
    
    if (!isTrusted && _settingsService.requirePermission) {
      // Ask for permission (this will be handled by UI)
      _requestDevicePermission(device);
    } else {
      _acceptConnection(device);
    }
  }

  /// Request permission for device connection
  void _requestDevicePermission(ConnectedDevice device) {
    _addLog('New device requesting connection: ${device.name} (${device.ipAddress})');
    device.status = ConnectionStatus.pending;
    _deviceController.add(device);
  }

  /// Accept device connection
  void _acceptConnection(ConnectedDevice device) {
    device.status = ConnectionStatus.connected;
    _connectedDevices.add(device);
    _deviceController.add(device);
    
    _addLog('Device connected: ${device.name} (${device.ipAddress})');

    // Listen for messages
    device.webSocket.stream.listen(
      (message) => _handleMessage(message, device),
      onDone: () => _handleDisconnection(device),
      onError: (error) => _handleConnectionError(device, error),
    );
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
    }
    
    _addLog('Device trusted: ${device.name}');
  }

  /// Disconnect a specific device
  void disconnectDevice(ConnectedDevice device) {
    device.webSocket.sink.close();
    _connectedDevices.remove(device);
    _addLog('Device disconnected: ${device.name}');
  }

  /// Handle incoming message from device
  void _handleMessage(dynamic message, ConnectedDevice device) {
    try {
      final data = jsonDecode(message);
      _handleTouchInput(data, device);
      device.lastActivity = DateTime.now();
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
  Future<void> _handleTouchInput(Map<String, dynamic> data, ConnectedDevice device) async {
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
    stopServer();
    _logController.close();
    _deviceController.close();
    _serverStatusController.close();
  }
}

/// Connected device information
class ConnectedDevice {
  final String name;
  final String ipAddress;
  final String id;
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
