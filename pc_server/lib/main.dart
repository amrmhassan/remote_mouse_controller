import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/main_screen.dart';
import 'services/settings_service.dart';

/// Main entry point for TouchPad Pro Windows Server
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager
  await windowManager.ensureInitialized();

  // Check if the app should start minimized
  final settingsService = SettingsService();
  await settingsService.initialize();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    minimumSize: Size(600, 400),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Hide native title bar
    title: 'TouchPad Pro Server',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // For debugging: Always show the window, don't auto-hide
    await windowManager.show();
    await windowManager.focus();

    // Commented out auto-hide behavior for debugging
    // if (settingsService.startMinimized) {
    //   await windowManager.hide();
    //   await windowManager.setSkipTaskbar(true);
    // } else {
    //   await windowManager.show();
    //   await windowManager.focus();
    // }
  });

  runApp(TouchPadProServerApp(startMinimized: settingsService.startMinimized));
}

class TouchPadProServerApp extends StatelessWidget {
  final bool startMinimized;

  const TouchPadProServerApp({super.key, this.startMinimized = false});

  @override
  Widget build(BuildContext context) {
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
