import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket service for communicating with the PC server
class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  bool _isConnected = false;

  /// Stream to listen for connection status changes
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Current connection status
  bool get isConnected => _isConnected;

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
      'deltaX': deltaX,
      'deltaY': deltaY,
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
      'deltaY': deltaY,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Disposes of the service and closes connections
  void dispose() {
    disconnect();
    _connectionController.close();
  }
}
