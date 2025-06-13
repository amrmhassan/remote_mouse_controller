import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/main_screen.dart';
import 'services/settings_service.dart';

/// Main entry point for TouchPad Pro Windows Server
void main() async {
  print('=== TOUCHPAD PRO SERVER - STARTUP LOG ===');
  print('[MAIN] Initializing Flutter bindings...');
  WidgetsFlutterBinding.ensureInitialized();

  print('[MAIN] Initializing window manager...');
  await windowManager.ensureInitialized();

  print('[MAIN] Loading settings service...');
  final settingsService = SettingsService();
  await settingsService.initialize();
  print(
      '[MAIN] Settings loaded - startMinimized: ${settingsService.startMinimized}');

  print('[MAIN] Configuring window options...');
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    minimumSize: Size(600, 400),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Hide native title bar
    title: 'TouchPad Pro Server',
  );

  print('[MAIN] Setting up window display...');
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    print('[MAIN] Window ready to show - forcing visibility for debugging');
    await windowManager.show();
    await windowManager.focus();
    print('[MAIN] Window shown and focused');

    // Commented out auto-hide behavior for debugging
    // if (settingsService.startMinimized) {
    //   await windowManager.hide();
    //   await windowManager.setSkipTaskbar(true);
    // } else {
    //   await windowManager.show();
    //   await windowManager.focus();
    // }
  });

  print('[MAIN] Starting Flutter app...');
  runApp(TouchPadProServerApp(startMinimized: settingsService.startMinimized));
  print('[MAIN] Flutter app launched');
}

class TouchPadProServerApp extends StatelessWidget {
  final bool startMinimized;

  const TouchPadProServerApp({super.key, this.startMinimized = false});
  @override
  Widget build(BuildContext context) {
    print('[MAIN] Building TouchPadProServerApp widget...');
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
      home: MainScreen(startMinimized: startMinimized),
    );
  }
}
