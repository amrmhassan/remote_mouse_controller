import 'dart:async';
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../services/network_discovery_service.dart';

/// Screen for connecting to a PC server
class ConnectionScreen extends StatefulWidget {
  final WebSocketService webSocketService;

  const ConnectionScreen({super.key, required this.webSocketService});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '8080',
  );
  final NetworkDiscoveryService _discoveryService = NetworkDiscoveryService();
  final List<ServerInfo> _discoveredServers = [];
  bool _isConnecting = false;
  String? _connectionError;
  Timer? _cleanupTimer;
  @override
  void initState() {
    super.initState();
    print('[CONNECTION] initState called');
    _startDiscovery();
  }

  @override
  void dispose() {
    print('[CONNECTION] dispose called');
    _cleanupTimer?.cancel();
    _discoveryService.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _startDiscovery() {
    print('[CONNECTION] Starting server discovery...');
    _discoveryService.startDiscovery();

    _discoveryService.serverStream.listen((serverInfo) {
      print(
        '[CONNECTION] Discovered server: ${serverInfo.name} at ${serverInfo.ip}:${serverInfo.port}',
      );
      if (!mounted) return;
      setState(() {
        // Remove any existing entry with the same IP:port
        _discoveredServers.removeWhere(
          (s) => s.ip == serverInfo.ip && s.port == serverInfo.port,
        );
        // Add the new entry
        _discoveredServers.add(serverInfo);
        // Sort by timestamp (newest first)
        _discoveredServers.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
      print(
        '[CONNECTION] Total discovered servers: ${_discoveredServers.length}',
      );
    });

    // Start cleanup timer to remove offline servers
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      setState(() {
        final initialCount = _discoveredServers.length;
        _discoveredServers.removeWhere(
          (server) => NetworkDiscoveryService.isServerOffline(server),
        );
        final removedCount = initialCount - _discoveredServers.length;
        if (removedCount > 0) {
          print(
            '[CONNECTION] Removed $removedCount offline server(s) from discovery list',
          );
        }
      });
    });
  }

  Future<void> _connectToServer(String ip, int port) async {
    print('[CONNECTION] === ATTEMPTING CONNECTION ===');
    print('[CONNECTION] Connecting to server at $ip:$port');

    if (!mounted) return;
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });
    print('[CONNECTION] UI state updated - connecting: true');

    final success = await widget.webSocketService.connect(ip, port);
    print('[CONNECTION] Connection attempt result: $success');

    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      if (!success) {
        _connectionError = 'Failed to connect to $ip:$port';
        print('[CONNECTION] Connection failed, error set: $_connectionError');
      } else {
        print('[CONNECTION] Connection successful!');
      }
    });
  }

  Future<void> _connectManually() async {
    print('[CONNECTION] _connectManually called');

    final ip = _ipController.text.trim();
    final portText = _portController.text.trim();
    print('[CONNECTION] Manual connection - IP: $ip, Port: $portText');

    if (ip.isEmpty) {
      print('[CONNECTION] Error: IP address is empty');
      if (!mounted) return;
      setState(() {
        _connectionError = 'Please enter an IP address';
      });
      return;
    }

    final port = int.tryParse(portText);
    if (port == null || port < 1 || port > 65535) {
      print('[CONNECTION] Error: Invalid port number: $portText');
      if (!mounted) return;
      setState(() {
        _connectionError = 'Please enter a valid port number (1-65535)';
      });
      return;
    }

    print('[CONNECTION] Manual connection validated, proceeding...');
    await _connectToServer(ip, port);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // Title
              const Text(
                'Remote Mouse Controller',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Discovered servers section
              if (_discoveredServers.isNotEmpty) ...[
                const Text(
                  'Discovered Servers:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                ...(_discoveredServers
                    .take(3)
                    .map(
                      (server) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ElevatedButton(
                          onPressed: _isConnecting
                              ? null
                              : () => _connectToServer(server.ip, server.port),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                server.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${server.ip}:${server.port}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),

                const SizedBox(height: 32),

                const Text(
                  'Or connect manually:',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),

                const SizedBox(height: 16),
              ] else ...[
                const Text(
                  'No servers discovered.\nConnect manually:',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),
              ],

              // Manual connection inputs
              TextField(
                controller: _ipController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Server IP Address',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: '192.168.1.100',
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.deepPurple),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _portController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: '8080',
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.deepPurple),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isConnecting ? null : _connectManually,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isConnecting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Connect', style: TextStyle(fontSize: 18)),
              ),

              if (_connectionError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _connectionError!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],

              const Spacer(),

              const Text(
                'Make sure the PC server is running and both devices are on the same network.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
