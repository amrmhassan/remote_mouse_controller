import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/connection_screen.dart';
import 'screens/touchpad_screen.dart';
import 'services/websocket_service.dart';

void main() {
  runApp(const RemoteMouseApp());
}

class RemoteMouseApp extends StatelessWidget {
  const RemoteMouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote Mouse Controller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final WebSocketService _webSocketService = WebSocketService();
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _webSocketService.connectionStream.listen((isConnected) {
      setState(() {
        _isConnected = isConnected;
      });
    });
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isConnected
          ? TouchpadScreen(webSocketService: _webSocketService)
          : ConnectionScreen(webSocketService: _webSocketService),
    );
  }
}
