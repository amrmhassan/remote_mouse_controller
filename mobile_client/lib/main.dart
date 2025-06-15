import 'package:flutter/material.dart';
import 'screens/connection_screen.dart';
import 'screens/touchpad_screen.dart';
import 'services/websocket_service.dart';
import 'services/background_service.dart';

void main() {
  runApp(const RemoteMouseApp());
}

class RemoteMouseApp extends StatelessWidget {
  const RemoteMouseApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TouchPad Pro',
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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final WebSocketService _webSocketService = WebSocketService();
  bool _isConnected = false;
  bool _isInitialized = false;
  @override
  void initState() {
    super.initState();

    // Add lifecycle observer for background handling
    WidgetsBinding.instance.addObserver(this);

    _initializeApp();

    _webSocketService.connectionStream.listen((isConnected) {
      setState(() {
        _isConnected = isConnected;
      });
    });
  }

  Future<void> _initializeApp() async {
    await _webSocketService.initialize();

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BackgroundConnectionService.stopMonitoring();
    _webSocketService.disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App going to background, start monitoring
        BackgroundConnectionService.startMonitoring(
          onShouldReconnect: () {
            // Attempt reconnection if not already connected
            if (!_isConnected && _webSocketService.shouldAutoReconnect) {
              // The WebSocket service will handle reconnection automatically
            }
          },
        );
        break;
      case AppLifecycleState.resumed:
        // App coming to foreground, stop background monitoring
        BackgroundConnectionService.stopMonitoring();
        break;
      case AppLifecycleState.inactive:
        // App becoming inactive, but not necessarily backgrounded
        break;
      case AppLifecycleState.hidden:
        // App is hidden
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      '[MOBILE_MAIN] Building MainScreen - isInitialized: $_isInitialized, isConnected: $_isConnected',
    );

    if (!_isInitialized) {
      print('[MOBILE_MAIN] Showing loading screen...');
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isConnected) {
      print('[MOBILE_MAIN] Showing TouchpadScreen (connected)');
    } else {
      print('[MOBILE_MAIN] Showing ConnectionScreen (not connected)');
    }

    return Scaffold(
      body: _isConnected
          ? TouchpadScreen(webSocketService: _webSocketService)
          : ConnectionScreen(webSocketService: _webSocketService),
    );
  }
}
