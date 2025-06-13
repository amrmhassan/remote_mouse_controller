import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/main_screen.dart';
import 'services/settings_service.dart';
import 'services/single_instance_service.dart';
import 'services/startup_service.dart';
import 'utils/debug_logger.dart';

/// Main entry point for TouchPad Pro Windows Server
void main(List<String> args) async {
  DebugLogger.log('TouchPad Pro Server starting...', tag: 'MAIN');
  DebugLogger.log('Command line args: $args', tag: 'MAIN');

  WidgetsFlutterBinding.ensureInitialized();

  // Check for single instance before proceeding
  DebugLogger.log('Checking for existing instance...', tag: 'MAIN');

  // We need to delay single instance check until we have a context
  // So we'll check it in the app initialization

  DebugLogger.log('Initializing window manager...', tag: 'MAIN');
  await windowManager.ensureInitialized();

  // Initialize startup service
  DebugLogger.log('Initializing startup service...', tag: 'MAIN');
  await StartupService.initialize();

  DebugLogger.log('Loading settings service...', tag: 'MAIN');
  final settingsService = SettingsService();
  await settingsService.initialize();
  // Determine if started minimized (from startup or command line)
  final startMinimized = args.contains('--minimized') ||
      (settingsService.startMinimized &&
          false); // Temporarily disable auto-start minimized due to system tray issues
  DebugLogger.log(
      'Start minimized: $startMinimized (system tray disabled for now)',
      tag: 'MAIN');

  DebugLogger.log('Configuring window options...', tag: 'MAIN');
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    minimumSize: Size(600, 400),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'TouchPad Pro Server',
  );
  DebugLogger.log('Setting up window display...', tag: 'MAIN');
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    DebugLogger.log('Window ready to show', tag: 'MAIN');

    if (startMinimized) {
      DebugLogger.log(
          'Configured to start minimized - will let MainScreen handle this after system tray setup',
          tag: 'MAIN');
      // Show window first, then let MainScreen decide whether to minimize based on system tray availability
      await windowManager.show();
      await windowManager.focus();
    } else {
      DebugLogger.log('Showing window normally', tag: 'MAIN');
      await windowManager.show();
      await windowManager.focus();
    }
  });
  DebugLogger.log('Starting Flutter app...', tag: 'MAIN');
  runApp(TouchPadProServerApp(startMinimized: startMinimized));
  DebugLogger.log('Flutter app launched', tag: 'MAIN');
}

class TouchPadProServerApp extends StatefulWidget {
  final bool startMinimized;

  const TouchPadProServerApp({super.key, this.startMinimized = false});

  @override
  State<TouchPadProServerApp> createState() => _TouchPadProServerAppState();
}

class _TouchPadProServerAppState extends State<TouchPadProServerApp> {
  bool _singleInstanceChecked = false;
  bool _canProceed = false;

  @override
  void initState() {
    super.initState();
    _checkSingleInstance();
  }

  Future<void> _checkSingleInstance() async {
    DebugLogger.log('Performing single instance check...', tag: 'APP');

    final canProceed = await SingleInstanceService.ensureSingleInstance(
        _singleInstanceChecked ? context : null);

    setState(() {
      _singleInstanceChecked = true;
      _canProceed = canProceed;
    });

    if (!canProceed) {
      DebugLogger.log('Another instance detected, this instance will exit',
          tag: 'APP');
    } else {
      DebugLogger.log('Single instance check passed, proceeding normally',
          tag: 'APP');
    }
  }

  @override
  void dispose() {
    // Release the single instance lock when app is closing
    SingleInstanceService.releaseLock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    DebugLogger.log('Building TouchPadProServerApp widget...', tag: 'APP');

    return MaterialApp(
      title: 'TouchPad Pro Server',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      ),
      home: !_singleInstanceChecked
          ? _buildLoadingScreen()
          : _canProceed
              ? MainScreen(startMinimized: widget.startMinimized)
              : _buildAlreadyRunningScreen(),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.deepPurple),
            SizedBox(height: 16),
            Text(
              'TouchPad Pro Server',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Starting up...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyRunningScreen() {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              size: 64,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text(
              'Already Running',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'TouchPad Pro Server is already running.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check your system tray or taskbar.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => exit(0),
              child: Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
