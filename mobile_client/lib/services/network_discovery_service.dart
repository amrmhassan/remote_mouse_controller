import 'dart:async';
import 'dart:io';
import 'dart:convert';

/// Service for discovering PC servers on the local network
class NetworkDiscoveryService {
  static const int _broadcastPort = 41234;
  RawDatagramSocket? _socket;
  final StreamController<ServerInfo> _serverController =
      StreamController<ServerInfo>.broadcast();

  /// Stream of discovered servers
  Stream<ServerInfo> get serverStream => _serverController.stream;

  /// Starts listening for server broadcasts
  Future<void> startDiscovery() async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _broadcastPort,
      );
      print('Started network discovery on port $_broadcastPort');

      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final packet = _socket!.receive();
          if (packet != null) {
            try {
              final message = utf8.decode(packet.data);
              final data = jsonDecode(message) as Map<String, dynamic>;
              if (data['service'] == 'remote_mouse_server') {
                final serverInfo = ServerInfo(
                  ip: data['ip'] as String,
                  port: data['port'] as int,
                  name: data['name'] as String? ?? 'Unknown Computer',
                  timestamp: data['timestamp'] as int,
                );
                _serverController.add(serverInfo);
              }
            } catch (e) {
              // Ignore invalid packets
            }
          }
        }
      });
    } catch (e) {
      print('Failed to start network discovery: $e');
    }
  }

  /// Stops network discovery
  void stopDiscovery() {
    _socket?.close();
    _socket = null;
  }

  /// Disposes of the service
  void dispose() {
    stopDiscovery();
    _serverController.close();
  }
}

/// Information about a discovered server
class ServerInfo {
  final String ip;
  final int port;
  final String name;
  final int timestamp;

  ServerInfo({
    required this.ip,
    required this.port,
    required this.name,
    required this.timestamp,
  });

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerInfo &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}
