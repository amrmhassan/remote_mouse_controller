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
    // Get local IP address
    final interfaces = await NetworkInterface.list();
    String? localIp;

    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 &&
            !addr.isLoopback &&
            !addr.address.startsWith('169.254')) {
          localIp = addr.address;
          break;
        }
      }
      if (localIp != null) break;
    }

    if (localIp != null) {
      print('Server available at: $localIp:$port');
    } else {
      print('Warning: Could not determine local IP address');
    }

    // Skip mDNS on Windows due to compatibility issues, use UDP broadcast directly
    if (Platform.isWindows) {
      print('Using UDP broadcast for server discovery (Windows)');
      await _startUdpBroadcast(port, localIp ?? 'unknown');
    } else {
      // Try mDNS on other platforms, fallback to UDP broadcast
      try {
        _mdnsClient = MDnsClient();
        await _mdnsClient!.start();
        print('mDNS advertising started on port $port');
        print('Service name: $_serviceName.$_domain');
        await _startUdpBroadcast(port, localIp ?? 'unknown');
      } catch (e) {
        print('Failed to start mDNS advertising: $e');
        print('Falling back to UDP broadcast only');
        await _startUdpBroadcast(port, localIp ?? 'unknown');
      }
    }
  }

  /// Starts a simple UDP broadcast for server discovery
  Future<void> _startUdpBroadcast(int port, String ip) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      print(
          'UDP broadcast started - advertising ${Platform.localHostname} ($ip:$port) every 5 seconds'); // Broadcast server info every 5 seconds
      final timer = Stream.periodic(const Duration(seconds: 5));
      timer.listen((_) {
        final message = jsonEncode({
          'service': 'remote_mouse_server',
          'ip': ip,
          'port': port,
          'name': Platform.localHostname,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        final data = utf8.encode(message);
        try {
          socket.send(data, InternetAddress('255.255.255.255'), 41234);
        } catch (e) {
          print('Error sending UDP broadcast: $e');
        }
      });

      print('Mobile devices can now discover this server automatically');
    } catch (e) {
      print('Failed to start UDP broadcast: $e');
      print(
          'Auto-discovery will not work, but manual connection is still available');
    }
  }

  /// Stops advertising the server
  Future<void> stopAdvertising() async {
    try {
      _mdnsClient?.stop();
      _mdnsClient = null;
      print('mDNS advertising stopped');
    } catch (e) {
      print('Error stopping mDNS: $e');
    }
  }
}
