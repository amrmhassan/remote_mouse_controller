import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'settings_service.dart';
import '../utils/debug_logger.dart';
import 'background_service.dart';

/// WebSocket service for communicating with the PC server
class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  bool _isConnected = false;

  // Reconnection logic
  Timer? _reconnectionTimer;
  int _reconnectionAttempts = 0;
  final int _maxReconnectionAttempts = 10;
  Duration _reconnectionBaseDelay = const Duration(seconds: 2);
  String? _lastConnectedIp;
  int? _lastConnectedPort;
  bool _shouldAutoReconnect = true;

  // Settings service instance
  final SettingsService _settingsService = SettingsService();

  // Device info
  String? _cachedDeviceId;
  String? _cachedDeviceModel; // Settings properties
  double _mouseSensitivity = 5.0; // Increased from 4.0 for even faster movement
  double _scrollSensitivity = 1.0;
  bool _reverseScroll = false;
  bool _hapticFeedback = true;

  /// Stream to listen for connection status changes
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Current connection status
  bool get isConnected => _isConnected;

  /// Auto-reconnect enabled
  bool get shouldAutoReconnect => _shouldAutoReconnect;
  set shouldAutoReconnect(bool value) {
    _shouldAutoReconnect = value;
    if (!value) {
      _stopReconnectionTimer();
    }
  }

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

  /// Haptic feedback enabled
  bool get hapticFeedback => _hapticFeedback;
  set hapticFeedback(bool value) {
    _hapticFeedback = value;
    _settingsService.setHapticFeedback(_hapticFeedback);
  }

  /// Initialize the service and load settings
  Future<void> initialize() async {
    await _settingsService.initialize();
    _loadSettings();
  }

  /// Load settings from persistent storage
  void _loadSettings() {
    _mouseSensitivity = _settingsService.mouseSensitivity;
    _scrollSensitivity = _settingsService.scrollSensitivity;
    _reverseScroll = _settingsService.reverseScroll;
    _hapticFeedback = _settingsService.hapticFeedback;
    DebugLogger.log(
      'Settings loaded - mouse: $_mouseSensitivity, scroll: $_scrollSensitivity, reverse: $_reverseScroll, haptic: $_hapticFeedback',
      tag: 'WS_CLIENT',
    );
  }

  /// Stop reconnection timer
  void _stopReconnectionTimer() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
  }

  /// Calculate exponential backoff delay
  Duration _calculateReconnectionDelay() {
    final delaySeconds =
        (_reconnectionBaseDelay.inSeconds *
                (1 << _reconnectionAttempts.clamp(0, 6)))
            .clamp(1, 120);
    return Duration(seconds: delaySeconds);
  }

  /// Start automatic reconnection attempts
  void _startReconnectionTimer() {
    if (!_shouldAutoReconnect ||
        _lastConnectedIp == null ||
        _lastConnectedPort == null) {
      return;
    }

    _stopReconnectionTimer();

    if (_reconnectionAttempts >= _maxReconnectionAttempts) {
      DebugLogger.log('Max reconnection attempts reached', tag: 'WS_CLIENT');
      return;
    }

    final delay = _calculateReconnectionDelay();
    DebugLogger.log(
      'Scheduling reconnection attempt ${_reconnectionAttempts + 1}/$_maxReconnectionAttempts in ${delay.inSeconds}s',
      tag: 'WS_CLIENT',
    );

    _reconnectionTimer = Timer(delay, () async {
      if (_shouldAutoReconnect && !_isConnected) {
        _reconnectionAttempts++;
        DebugLogger.log(
          'Attempting reconnection ${_reconnectionAttempts}/$_maxReconnectionAttempts',
          tag: 'WS_CLIENT',
        );

        final success = await connect(_lastConnectedIp!, _lastConnectedPort!);
        if (!success) {
          _startReconnectionTimer(); // Schedule next attempt
        }
      }
    });
  }

  /// Connects to the server at the specified IP and port
  Future<bool> connect(String ip, int port) async {
    // Connecting to server

    try {
      disconnect(
        stopAutoReconnect: false,
      ); // Don't stop auto-reconnect for manual connections

      final uri = Uri.parse('ws://$ip:$port');
      _channel = WebSocketChannel.connect(uri);

      // Add timeout for connection
      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timeout after 10 seconds');
        },
      );

      _updateConnectionStatus(true);
      _lastConnectedIp = ip;
      _lastConnectedPort = port;
      _reconnectionAttempts =
          0; // Reset reconnection attempts on successful connection

      // Send device identification immediately after connection
      await _sendDeviceIdentification();

      // Listen for disconnection and server messages with better error handling
      _channel!.stream.listen(
        (message) {
          try {
            _handleServerMessage(message);
          } catch (e) {
            DebugLogger.log(
              'Error handling server message: $e',
              tag: 'WS_CLIENT',
            );
          }
        },
        onDone: () {
          _handleDisconnection();
        },
        onError: (error) {
          print('[WS_CLIENT] WebSocket error: $error');
          _handleDisconnection();
        },
        cancelOnError: true,
      );

      // Successfully connected
      return true;
    } catch (e) {
      print('[WS_CLIENT] ERROR: Failed to connect to server: $e');
      _handleConnectionFailure();
      return false;
    }
  }

  /// Update connection status and notify background service
  void _updateConnectionStatus(bool connected) {
    _isConnected = connected;
    _connectionController.add(connected);

    // Update persistent storage for background service
    BackgroundConnectionService.updateConnectionStatus(
      connected,
      ip: connected ? _lastConnectedIp : null,
      port: connected ? _lastConnectedPort : null,
    );
  }

  /// Handle disconnection and start reconnection if needed
  void _handleDisconnection() {
    if (_isConnected) {
      _updateConnectionStatus(false);
      DebugLogger.log(
        'Disconnected from server, attempting reconnection...',
        tag: 'WS_CLIENT',
      );
      _startReconnectionTimer();
    }
  }

  /// Handle connection failure
  void _handleConnectionFailure() {
    _updateConnectionStatus(false);
    _startReconnectionTimer();
  }

  /// Send device identification to server
  Future<void> _sendDeviceIdentification() async {
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
        _channel!.sink.add(message);
      } catch (e) {
        print('[WS_CLIENT] ERROR sending device identification: $e');
      }
    }
  }

  /// Handle messages from server
  void _handleServerMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];

      switch (type) {
        case 'server_status':
          // Handle server status updates
          final isRunning = data['running'] as bool? ?? false;
          if (!isRunning) {
            // Server stopped, disconnect
            disconnect();
          }
          break;
        case 'ping':
          // Respond to ping to keep connection alive
          _sendPong();
          break;
        default:
          // Handle other message types if needed
          break;
      }
    } catch (e) {
      print('[WS_CLIENT] ERROR handling server message: $e');
    }
  }

  /// Send pong response to server ping
  void _sendPong() {
    if (_isConnected && _channel != null) {
      try {
        sendTouchInput({
          'type': 'pong',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (e) {
        print('[WS_CLIENT] ERROR sending pong: $e');
      }
    }
  }

  /// Disconnects from the server
  void disconnect({bool stopAutoReconnect = true}) {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }

    _updateConnectionStatus(false);

    if (stopAutoReconnect) {
      _stopReconnectionTimer();
    }
  }

  /// Sends touch input data to the server
  void sendTouchInput(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      try {
        final message = jsonEncode(data);
        _channel!.sink.add(message);
      } catch (e) {
        print('[WS_CLIENT] ERROR sending touch input: $e');
      }
    }
  }

  /// Sends mouse movement data with optimized message creation
  void sendMouseMove(double deltaX, double deltaY) {
    if (_isConnected && _channel != null) {
      try {
        final adjustedDeltaX = deltaX * _mouseSensitivity;
        final adjustedDeltaY = deltaY * _mouseSensitivity;

        // Optimized: directly create JSON string without map overhead
        final message =
            '{"type":"move","deltaX":$adjustedDeltaX,"deltaY":$adjustedDeltaY}';
        _channel!.sink.add(message);
      } catch (e) {
        print('[WS_CLIENT] ERROR sending mouse move: $e');
      }
    }
  }

  /// Sends left click event
  void sendLeftClick() {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add('{"type":"click"}');
      } catch (e) {
        print('[WS_CLIENT] ERROR sending left click: $e');
      }
    }
  }

  /// Sends right click event
  void sendRightClick() {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add('{"type":"rightClick"}');
      } catch (e) {
        print('[WS_CLIENT] ERROR sending right click: $e');
      }
    }
  }

  /// Sends scroll event
  void sendScroll(double deltaY) {
    if (_isConnected && _channel != null) {
      try {
        final adjustedDeltaY = deltaY * _scrollSensitivity;
        final message = '{"type":"scroll","deltaY":$adjustedDeltaY}';
        _channel!.sink.add(message);
      } catch (e) {
        print('[WS_CLIENT] ERROR sending scroll: $e');
      }
    }
  }

  /// Sends mouse down left event (for drag and drop start)
  void sendMouseDownLeft() {
    sendTouchInput({
      'type': 'mouseDownLeft',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Sends mouse up left event (for drag and drop end)
  void sendMouseUpLeft() {
    sendTouchInput({
      'type': 'mouseUpLeft',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Forces disconnection and notifies the server
  void forceDisconnect() {
    if (_isConnected && _channel != null) {
      try {
        // Send disconnect notification to server
        sendTouchInput({
          'type': 'disconnect',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        // Wait a moment for the message to be sent, then disconnect
        Future.delayed(const Duration(milliseconds: 100), () {
          disconnect();
        });
      } catch (e) {
        print('[WS_CLIENT] ERROR during force disconnect: $e');
        disconnect();
      }
    } else {
      disconnect();
    }
  }

  /// Get unique device identifier
  Future<String> _getUniqueDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use Android ID which is unique per device and app installation
        _cachedDeviceId = androidInfo.id;
        _cachedDeviceModel = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use identifierForVendor which is unique per vendor per device
        _cachedDeviceId = iosInfo.identifierForVendor ?? 'unknown_ios_device';
        _cachedDeviceModel =
            '${iosInfo.model} ${iosInfo.systemName} ${iosInfo.systemVersion}';
      } else {
        // Fallback for other platforms
        _cachedDeviceId =
            'unknown_platform_${DateTime.now().millisecondsSinceEpoch}';
        _cachedDeviceModel = 'Unknown Platform';
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
    disconnect();
    _connectionController.close();
  }
}
