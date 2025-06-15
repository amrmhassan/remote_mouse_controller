import 'dart:async';
import 'dart:io';
import 'dart:convert';

/// Service for discovering PC servers on the local network
class NetworkDiscoveryService {
  static const int _broadcastPort = 41234;
  static const int _serverTimeoutMs = 15000; // 15 seconds timeout

  RawDatagramSocket? _socket;
  final StreamController<ServerInfo> _serverController =
      StreamController<ServerInfo>.broadcast();
  final StreamController<String> _serverRemovedController =
      StreamController<String>.broadcast();

  Timer? _cleanupTimer;

  /// Stream of discovered servers
  Stream<ServerInfo> get serverStream => _serverController.stream;

  /// Stream of servers that have been removed due to timeout
  Stream<String> get serverRemovedStream => _serverRemovedController.stream;

  /// Starts listening for server broadcasts
  Future<void> startDiscovery() async {
    // Starting network discovery...

    try {
      // Binding UDP socket...
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _broadcastPort,
      );
      print(
        '[DISCOVERY_CLIENT] Started network discovery on port $_broadcastPort',
      );

      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final packet = _socket!.receive();
          if (packet != null) {
            try {
              final message = utf8.decode(packet.data);
              // Received UDP packet

              final data = jsonDecode(message) as Map<String, dynamic>;
              if (data['service'] == 'remote_mouse_server') {
                // Valid server broadcast received

                final serverInfo = ServerInfo(
                  ip: data['ip'] as String,
                  port: data['port'] as int,
                  name: data['name'] as String? ?? 'Unknown Computer',
                  timestamp: data['timestamp'] as int,
                );

                print(
                  '[DISCOVERY_CLIENT] Server info parsed: ${serverInfo.name} at ${serverInfo.ip}:${serverInfo.port}',
                );
                _serverController.add(serverInfo);
              } else {
                print(
                  '[DISCOVERY_CLIENT] Non-server packet ignored: ${data['service']}',
                );
              }
            } catch (e) {
              print('[DISCOVERY_CLIENT] Error parsing packet: $e');
              // Ignore invalid packets
            }
          }
        }
      });

      // Start cleanup timer to remove old servers
      print('[DISCOVERY_CLIENT] Starting cleanup timer...');
      _startCleanupTimer();
    } catch (e) {
      print('[DISCOVERY_CLIENT] ERROR: Failed to start network discovery: $e');
      print('[DISCOVERY_CLIENT] Stack trace: ${StackTrace.current}');
    }
  }

  /// Starts the cleanup timer to remove old servers
  void _startCleanupTimer() {
    print('[DISCOVERY_CLIENT] Starting cleanup timer...');
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      print(
        '[DISCOVERY_CLIENT] Cleanup timer tick - checking for offline servers',
      );
      // Note: The actual cleanup logic will be handled in the UI layer
      // since we need to maintain the server list there
    });
  }

  /// Check if a server should be considered offline
  static bool isServerOffline(ServerInfo server) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isOffline = (now - server.timestamp) > _serverTimeoutMs;
    if (isOffline) {
      print(
        '[DISCOVERY_CLIENT] Server ${server.name} at ${server.ip}:${server.port} considered offline (age: ${now - server.timestamp}ms)',
      );
    }
    return isOffline;
  }

  /// Stops network discovery
  void stopDiscovery() {
    print('[DISCOVERY_CLIENT] Stopping network discovery...');
    _cleanupTimer?.cancel();
    _socket?.close();
    _socket = null;
    print('[DISCOVERY_CLIENT] Network discovery stopped');
  }

  /// Disposes of the service
  void dispose() {
    print('[DISCOVERY_CLIENT] Disposing network discovery service...');
    stopDiscovery();
    _serverController.close();
    _serverRemovedController.close();
    print('[DISCOVERY_CLIENT] Network discovery service disposed');
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
