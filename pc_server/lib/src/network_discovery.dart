import 'dart:io';
import 'dart:convert';
import 'package:multicast_dns/multicast_dns.dart';

/// Handles network discovery using mDNS (Bonjour/Zeroconf)
/// Allows the server to advertise its presence on the local network
class NetworkDiscovery {
  MDnsClient? _mdnsClient;
  static const String _serviceName = '_remotemouse._tcp';
  static const String _domain = 'local';

  /// Starts advertising the server on the local network
  Future<void> startAdvertising(int port) async {
    print('[DISCOVERY] startAdvertising called with port: $port');

    // Get local IP address
    print('[DISCOVERY] Getting network interfaces...');
    final interfaces = await NetworkInterface.list();
    String? localIp;

    print('[DISCOVERY] Found ${interfaces.length} network interfaces');
    for (final interface in interfaces) {
      print('[DISCOVERY] Interface: ${interface.name}');

      for (final addr in interface.addresses) {
        print(
            '[DISCOVERY] Address: ${addr.address} (${addr.type}, loopback: ${addr.isLoopback})');

        if (addr.type == InternetAddressType.IPv4 &&
            !addr.isLoopback &&
            !addr.address.startsWith('169.254')) {
          localIp = addr.address;
          print('[DISCOVERY] Selected IP address: $localIp');
          break;
        }
      }
      if (localIp != null) break;
    }

    if (localIp != null) {
      print('[DISCOVERY] Server will be available at: $localIp:$port');
    } else {
      print('[DISCOVERY] WARNING: Could not determine local IP address');
    }

    // Skip mDNS on Windows due to compatibility issues, use UDP broadcast directly
    if (Platform.isWindows) {
      print('[DISCOVERY] Using UDP broadcast for server discovery (Windows)');
      await _startUdpBroadcast(port, localIp ?? 'unknown');
    } else {
      // Try mDNS on other platforms, fallback to UDP broadcast
      try {
        print('[DISCOVERY] Attempting to start mDNS client...');
        _mdnsClient = MDnsClient();
        await _mdnsClient!.start();
        print('[DISCOVERY] mDNS advertising started on port $port');
        print('[DISCOVERY] Service name: $_serviceName.$_domain');
        await _startUdpBroadcast(port, localIp ?? 'unknown');
      } catch (e) {
        print('[DISCOVERY] Failed to start mDNS advertising: $e');
        print('[DISCOVERY] Falling back to UDP broadcast only');
        await _startUdpBroadcast(port, localIp ?? 'unknown');
      }
    }
  }

  /// Starts a simple UDP broadcast for server discovery
  Future<void> _startUdpBroadcast(int port, String ip) async {
    print('[DISCOVERY] _startUdpBroadcast called - port: $port, ip: $ip');

    try {
      print('[DISCOVERY] Binding UDP socket to any IPv4 address...');
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      print('[DISCOVERY] UDP socket bound successfully, broadcast enabled');

      print(
          '[DISCOVERY] UDP broadcast started - advertising ${Platform.localHostname} ($ip:$port) every 5 seconds');

      // Broadcast server info every 5 seconds
      final timer = Stream.periodic(const Duration(seconds: 5));
      timer.listen((_) {
        print('[DISCOVERY] Sending UDP broadcast message...');

        final message = jsonEncode({
          'service': 'remote_mouse_server',
          'ip': ip,
          'port': port,
          'name': Platform.localHostname,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('[DISCOVERY] Broadcast message: $message');

        final data = utf8.encode(message);
        try {
          final result =
              socket.send(data, InternetAddress('255.255.255.255'), 41234);
          print('[DISCOVERY] UDP broadcast sent, bytes: $result');
        } catch (e) {
          print('[DISCOVERY] ERROR sending UDP broadcast: $e');
        }
      });

      print(
          '[DISCOVERY] Mobile devices can now discover this server automatically');
    } catch (e) {
      print('[DISCOVERY] ERROR: Failed to start UDP broadcast: $e');
      print('[DISCOVERY] Stack trace: ${StackTrace.current}');
      print(
          '[DISCOVERY] Auto-discovery will not work, but manual connection is still available');
    }
  }

  /// Stops advertising the server
  Future<void> stopAdvertising() async {
    print('[DISCOVERY] stopAdvertising called');

    try {
      if (_mdnsClient != null) {
        print('[DISCOVERY] Stopping mDNS client...');
        _mdnsClient?.stop();
        _mdnsClient = null;
        print('[DISCOVERY] mDNS advertising stopped');
      } else {
        print('[DISCOVERY] No mDNS client to stop');
      }
    } catch (e) {
      print('[DISCOVERY] ERROR stopping mDNS: $e');
      print('[DISCOVERY] Stack trace: ${StackTrace.current}');
    }
  }
}
