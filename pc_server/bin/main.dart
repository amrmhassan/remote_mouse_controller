import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:args/args.dart';
import '../lib/src/mouse_controller.dart';
import '../lib/src/network_discovery.dart';

/// Main entry point for the remote mouse server
/// Starts a WebSocket server and advertises its presence on the local network
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8080', help: 'Server port')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  final args = parser.parse(arguments);

  if (args['help']) {
    print('Remote Mouse Server');
    print(parser.usage);
    return;
  }

  final port = int.tryParse(args['port']) ?? 8080;

  print('Starting Remote Mouse Server...');

  // Initialize mouse controller
  final mouseController = MouseController();

  // Start network discovery service
  final discovery = NetworkDiscovery();
  await discovery.startAdvertising(port);

  // Create WebSocket handler
  final handler = webSocketHandler((WebSocketChannel webSocket) {
    print('Client connected');

    webSocket.stream.listen(
      (message) async {
        try {
          final data = jsonDecode(message);
          await _handleTouchInput(data, mouseController);
        } catch (e) {
          print('Error processing message: $e');
        }
      },
      onDone: () => print('Client disconnected'),
      onError: (error) => print('WebSocket error: $error'),
    );
  });
  // Start the server with error handling
  late HttpServer server;
  try {
    server = await serve(handler, InternetAddress.anyIPv4, port);
    print('Server running on ws://${server.address.address}:${server.port}');
    print('Press Ctrl+C to stop the server');
  } catch (e) {
    if (e.toString().contains('errno = 10048') ||
        e.toString().contains('Address already in use')) {
      print('Error: Port $port is already in use.');
      print(
          'Please try a different port using: dart run bin/main.dart --port <other_port>');
      print('Or stop any other service using port $port');
      exit(1);
    } else {
      print('Failed to start server: $e');
      exit(1);
    }
  }

  // Handle shutdown gracefully
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down server...');
    await discovery.stopAdvertising();
    await server.close();
    exit(0);
  });
}

/// Handles incoming touch input data and translates it to mouse actions
Future<void> _handleTouchInput(
    Map<String, dynamic> data, MouseController mouseController) async {
  final type = data['type'] as String?;
  final deltaX = (data['deltaX'] as num?)?.toDouble();
  final deltaY = (data['deltaY'] as num?)?.toDouble();

  switch (type) {
    case 'move':
      if (deltaX != null && deltaY != null) {
        await mouseController.moveMouse(deltaX, deltaY);
      }
      break;
    case 'click':
      await mouseController.leftClick();
      break;
    case 'rightClick':
      await mouseController.rightClick();
      break;
    case 'scroll':
      if (deltaY != null) {
        await mouseController.scroll(deltaY);
      }
      break;
    default:
      print('Unknown input type: $type');
  }
}
