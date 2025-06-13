import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'settings_service.dart';

/// WebSocket service for communicating with the PC server
class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  bool _isConnected = false;

  // Settings service instance
  final SettingsService _settingsService = SettingsService();

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
    await _settingsService.initialize();
    _loadSettings();
  }

  /// Load settings from persistent storage
  void _loadSettings() {
    _mouseSensitivity = _settingsService.mouseSensitivity;
    _scrollSensitivity = _settingsService.scrollSensitivity;
    _reverseScroll = _settingsService.reverseScroll;
  }

  /// Connects to the server at the specified IP and port
  Future<bool> connect(String ip, int port) async {
    try {
      disconnect(); // Disconnect any existing connection

      final uri = Uri.parse('ws://$ip:$port');
      _channel = WebSocketChannel.connect(uri);

      // Wait for connection to be established
      await _channel!.ready;

      _isConnected = true;
      _connectionController.add(true);

      // Listen for disconnection
      _channel!.stream.listen(
        (message) {
          // Handle incoming messages if needed
        },
        onDone: () {
          _isConnected = false;
          _connectionController.add(false);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
          _connectionController.add(false);
        },
      );

      print('Connected to server at $ip:$port');
      return true;
    } catch (e) {
      print('Failed to connect to server: $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Disconnects from the server
  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    _isConnected = false;
    _connectionController.add(false);
  }

  /// Sends touch input data to the server
  void sendTouchInput(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      try {
        final message = jsonEncode(data);
        _channel!.sink.add(message);
      } catch (e) {
        print('Error sending touch input: $e');
      }
    }
  }

  /// Sends mouse movement data
  void sendMouseMove(double deltaX, double deltaY) {
    sendTouchInput({
      'type': 'move',
      'deltaX': deltaX * _mouseSensitivity,
      'deltaY': deltaY * _mouseSensitivity,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Sends left click event
  void sendLeftClick() {
    sendTouchInput({
      'type': 'click',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Sends right click event
  void sendRightClick() {
    sendTouchInput({
      'type': 'rightClick',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Sends scroll event
  void sendScroll(double deltaY) {
    sendTouchInput({
      'type': 'scroll',
      'deltaY': deltaY * _scrollSensitivity,
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
        print('Error during force disconnect: $e');
        disconnect();
      }
    }
  }

  /// Disposes of the service and closes connections
  void dispose() {
    disconnect();
    _connectionController.close();
  }
}
