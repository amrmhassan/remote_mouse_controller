import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'settings_service.dart';
import '../utils/debug_logger.dart';

/// WebSocket service for communicating with the PC server
class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  bool _isConnected = false;

  // Settings service instance
  final SettingsService _settingsService = SettingsService();

  // Device info
  String? _cachedDeviceId;
  String? _cachedDeviceModel;

  // Settings properties
  double _mouseSensitivity = 2.0;
  double _scrollSensitivity = 1.0;
  bool _reverseScroll = false;

  /// Stream to listen for connection status changes
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Current connection status
  bool get isConnected => _isConnected;

  /// Mouse sensitivity (1.0 = normal, 2.0 = double speed, 0.5 = half speed)
  double get mouseSensitivity => _mouseSensitivity;
  set mouseSensitivity(double value) {
    _mouseSensitivity = value.clamp(0.1, 10.0);
    _settingsService.setMouseSensitivity(_mouseSensitivity);
  }

  /// Scroll sensitivity (1.0 = normal, 2.0 = double speed, 0.5 = half speed)
  double get scrollSensitivity => _scrollSensitivity;
  set scrollSensitivity(double value) {
    _scrollSensitivity = value.clamp(0.1, 5.0);
    _settingsService.setScrollSensitivity(_scrollSensitivity);
  }

  /// Reverse scroll direction
  bool get reverseScroll => _reverseScroll;
  set reverseScroll(bool value) {
    _reverseScroll = value;
    _settingsService.setReverseScroll(_reverseScroll);
  }

  /// Initialize the service and load settings
  Future<void> initialize() async {
    DebugLogger.log('Initializing WebSocket service...', tag: 'WS_CLIENT');
    await _settingsService.initialize();
    _loadSettings();
    DebugLogger.log('WebSocket service initialized', tag: 'WS_CLIENT');
  }

  /// Load settings from persistent storage
  void _loadSettings() {
    DebugLogger.log('Loading settings...', tag: 'WS_CLIENT');
    _mouseSensitivity = _settingsService.mouseSensitivity;
    _scrollSensitivity = _settingsService.scrollSensitivity;
    _reverseScroll = _settingsService.reverseScroll;
    DebugLogger.log(
      'Settings loaded - mouse: $_mouseSensitivity, scroll: $_scrollSensitivity, reverse: $_reverseScroll',
      tag: 'WS_CLIENT',
    );
  }

  /// Connects to the server at the specified IP and port
  Future<bool> connect(String ip, int port) async {
    print('[WS_CLIENT] === CONNECTING TO SERVER ===');
    print('[WS_CLIENT] Attempting to connect to $ip:$port');

    try {
      print('[WS_CLIENT] Disconnecting any existing connection...');
      disconnect(); // Disconnect any existing connection

      final uri = Uri.parse('ws://$ip:$port');
      print('[WS_CLIENT] Creating WebSocket channel to: $uri');
      _channel = WebSocketChannel.connect(uri);

      print('[WS_CLIENT] Waiting for WebSocket connection to be ready...');
      // Wait for connection to be established
      await _channel!.ready;
      print('[WS_CLIENT] WebSocket connection established successfully');

      _isConnected = true;
      _connectionController.add(true);
      print(
        '[WS_CLIENT] Connection status updated to: connected',
      ); // Send device identification immediately after connection
      print('[WS_CLIENT] Sending device identification...');
      await _sendDeviceIdentification();

      // Listen for disconnection and server messages
      print('[WS_CLIENT] Setting up message listeners...');
      _channel!.stream.listen(
        (message) {
          print('[WS_CLIENT] Received message from server: $message');
          _handleServerMessage(message);
        },
        onDone: () {
          print('[WS_CLIENT] WebSocket stream closed (onDone)');
          _isConnected = false;
          _connectionController.add(false);
        },
        onError: (error) {
          print('[WS_CLIENT] WebSocket error: $error');
          print('[WS_CLIENT] Error type: ${error.runtimeType}');
          _isConnected = false;
          _connectionController.add(false);
        },
      );

      print('[WS_CLIENT] Successfully connected to server at $ip:$port');
      return true;
    } catch (e) {
      print('[WS_CLIENT] ERROR: Failed to connect to server: $e');
      print('[WS_CLIENT] Error type: ${e.runtimeType}');
      print('[WS_CLIENT] Stack trace: ${StackTrace.current}');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Send device identification to server
  Future<void> _sendDeviceIdentification() async {
    print('[WS_CLIENT] _sendDeviceIdentification called');

    if (_isConnected && _channel != null) {
      try {
        // Get unique device ID
        final deviceId = await _getUniqueDeviceId();
        // Create a more descriptive device name
        String displayName = _settingsService.deviceName;
        if (displayName.isEmpty ||
            displayName == 'Mobile Device' ||
            displayName == 'My Mobile Device') {
          // Use device model as the display name if no custom name is set
          displayName = _cachedDeviceModel ?? 'Unknown Mobile Device';
        }

        final deviceInfo = {
          'type': 'device_info',
          'device_name': displayName,
          'device_model': _cachedDeviceModel ?? 'Unknown Device',
          'device_id': deviceId, // Add unique device ID
          'app_version': '1.0.0',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        final message = jsonEncode(deviceInfo);
        print('[WS_CLIENT] Sending device identification: $message');
        _channel!.sink.add(message);
        print('[WS_CLIENT] Device identification sent successfully');
      } catch (e) {
        print('[WS_CLIENT] ERROR sending device identification: $e');
        print('[WS_CLIENT] Stack trace: ${StackTrace.current}');
      }
    } else {
      print(
        '[WS_CLIENT] Cannot send device identification - not connected or channel is null',
      );
      print('[WS_CLIENT] isConnected: $_isConnected, channel: $_channel');
    }
  }

  /// Handle messages from server
  void _handleServerMessage(dynamic message) {
    print('[WS_CLIENT] _handleServerMessage called with: $message');

    try {
      final data = jsonDecode(message);
      final type = data['type'];
      print('[WS_CLIENT] Parsed message type: $type');

      switch (type) {
        case 'server_status':
          print('[WS_CLIENT] Handling server_status message');
          // Handle server status updates
          final isRunning = data['running'] as bool? ?? false;
          print('[WS_CLIENT] Server running status: $isRunning');
          if (!isRunning) {
            // Server stopped, disconnect
            print('[WS_CLIENT] Server stopped, disconnecting...');
            disconnect();
          }
          break;
        case 'ping':
          print('[WS_CLIENT] Handling ping message - sending pong');
          // Respond to ping to keep connection alive
          _sendPong();
          break;
        default:
          // Handle other message types if needed
          print('[WS_CLIENT] Received unhandled server message type: $type');
          print('[WS_CLIENT] Full message data: $data');
      }
    } catch (e) {
      print('[WS_CLIENT] ERROR handling server message: $e');
      print('[WS_CLIENT] Raw message: $message');
      print('[WS_CLIENT] Stack trace: ${StackTrace.current}');
    }
  }

  /// Send pong response to server ping
  void _sendPong() {
    print('[WS_CLIENT] _sendPong called');

    if (_isConnected && _channel != null) {
      try {
        print('[WS_CLIENT] Sending pong response');
        sendTouchInput({
          'type': 'pong',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('[WS_CLIENT] Pong sent successfully');
      } catch (e) {
        print('[WS_CLIENT] ERROR sending pong: $e');
        print('[WS_CLIENT] Stack trace: ${StackTrace.current}');
      }
    } else {
      print('[WS_CLIENT] Cannot send pong - not connected or channel is null');
    }
  }

  /// Disconnects from the server
  void disconnect() {
    print('[WS_CLIENT] === DISCONNECTING FROM SERVER ===');

    if (_channel != null) {
      print('[WS_CLIENT] Closing WebSocket channel...');
      _channel!.sink.close();
      _channel = null;
      print('[WS_CLIENT] WebSocket channel closed');
    } else {
      print('[WS_CLIENT] No channel to close');
    }

    _isConnected = false;
    _connectionController.add(false);
    print('[WS_CLIENT] Connection status updated to: disconnected');
  }

  /// Sends touch input data to the server
  void sendTouchInput(Map<String, dynamic> data) {
    print('[WS_CLIENT] sendTouchInput called with: $data');

    if (_isConnected && _channel != null) {
      try {
        final message = jsonEncode(data);
        print('[WS_CLIENT] Sending message to server: $message');
        _channel!.sink.add(message);
        print('[WS_CLIENT] Message sent successfully');
      } catch (e) {
        print('[WS_CLIENT] ERROR sending touch input: $e');
        print('[WS_CLIENT] Data: $data');
        print('[WS_CLIENT] Stack trace: ${StackTrace.current}');
      }
    } else {
      print(
        '[WS_CLIENT] Cannot send touch input - not connected or channel is null',
      );
      print('[WS_CLIENT] isConnected: $_isConnected, channel: $_channel');
    }
  }

  /// Sends mouse movement data
  void sendMouseMove(double deltaX, double deltaY) {
    print(
      '[WS_CLIENT] sendMouseMove called - deltaX: $deltaX, deltaY: $deltaY, sensitivity: $_mouseSensitivity',
    );

    final adjustedDeltaX = deltaX * _mouseSensitivity;
    final adjustedDeltaY = deltaY * _mouseSensitivity;
    print(
      '[WS_CLIENT] Adjusted deltas - X: $adjustedDeltaX, Y: $adjustedDeltaY',
    );

    sendTouchInput({
      'type': 'move',
      'deltaX': adjustedDeltaX,
      'deltaY': adjustedDeltaY,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Sends left click event
  void sendLeftClick() {
    print('[WS_CLIENT] sendLeftClick called');
    sendTouchInput({
      'type': 'click',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Sends right click event
  void sendRightClick() {
    print('[WS_CLIENT] sendRightClick called');
    sendTouchInput({
      'type': 'rightClick',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Sends scroll event
  void sendScroll(double deltaY) {
    print(
      '[WS_CLIENT] sendScroll called - deltaY: $deltaY, sensitivity: $_scrollSensitivity',
    );

    final adjustedDeltaY = deltaY * _scrollSensitivity;
    print('[WS_CLIENT] Adjusted deltaY: $adjustedDeltaY');

    sendTouchInput({
      'type': 'scroll',
      'deltaY': adjustedDeltaY,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Forces disconnection and notifies the server
  void forceDisconnect() {
    print('[WS_CLIENT] === FORCE DISCONNECT CALLED ===');

    if (_isConnected && _channel != null) {
      try {
        print('[WS_CLIENT] Sending disconnect notification to server...');
        // Send disconnect notification to server
        sendTouchInput({
          'type': 'disconnect',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        print('[WS_CLIENT] Waiting 100ms before disconnecting...');
        // Wait a moment for the message to be sent, then disconnect
        Future.delayed(const Duration(milliseconds: 100), () {
          print('[WS_CLIENT] Proceeding with disconnect...');
          disconnect();
        });
      } catch (e) {
        print('[WS_CLIENT] ERROR during force disconnect: $e');
        print('[WS_CLIENT] Stack trace: ${StackTrace.current}');
        disconnect();
      }
    } else {
      print('[WS_CLIENT] Force disconnect called but not connected');
      disconnect();
    }
  }

  /// Get unique device identifier
  Future<String> _getUniqueDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    print('[WS_CLIENT] Getting unique device identifier...');

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use Android ID which is unique per device and app installation
        _cachedDeviceId = androidInfo.id;
        _cachedDeviceModel = '${androidInfo.brand} ${androidInfo.model}';
        print('[WS_CLIENT] Android device ID: $_cachedDeviceId');
        print('[WS_CLIENT] Android device model: $_cachedDeviceModel');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use identifierForVendor which is unique per vendor per device
        _cachedDeviceId = iosInfo.identifierForVendor ?? 'unknown_ios_device';
        _cachedDeviceModel =
            '${iosInfo.model} ${iosInfo.systemName} ${iosInfo.systemVersion}';
        print('[WS_CLIENT] iOS device ID: $_cachedDeviceId');
        print('[WS_CLIENT] iOS device model: $_cachedDeviceModel');
      } else {
        // Fallback for other platforms
        _cachedDeviceId =
            'unknown_platform_${DateTime.now().millisecondsSinceEpoch}';
        _cachedDeviceModel = 'Unknown Platform';
        print(
          '[WS_CLIENT] Unknown platform, using fallback ID: $_cachedDeviceId',
        );
      }

      return _cachedDeviceId!;
    } catch (e) {
      print('[WS_CLIENT] ERROR getting device ID: $e');
      // Fallback to timestamp-based ID
      _cachedDeviceId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      _cachedDeviceModel = 'Unknown Device';
      return _cachedDeviceId!;
    }
  }

  /// Disposes of the service and closes connections
  void dispose() {
    print('[WS_CLIENT] === DISPOSING WEBSOCKET SERVICE ===');
    disconnect();
    _connectionController.close();
    print('[WS_CLIENT] WebSocket service disposed');
  }
}
