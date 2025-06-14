import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
import '../services/server_service.dart';
import '../services/settings_service.dart';
import '../services/startup_service.dart';
import '../utils/debug_logger.dart';
import 'settings_screen.dart';
import 'devices_screen.dart';

/// Main screen for TouchPad Pro Server
class MainScreen extends StatefulWidget {
  final bool startMinimized;

  const MainScreen({super.key, this.startMinimized = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  final ServerService _serverService = ServerService();
  final SettingsService _settingsService = SettingsService();
  final SystemTray _systemTray = SystemTray();
  bool _systemTrayAvailable = false;

  final List<String> _logs = [];
  final List<ConnectedDevice> _devices = [];
  int _selectedIndex = 0;
  bool _isServerRunning = false;
  @override
  void initState() {
    DebugLogger.log('Main screen initialization starting...',
        tag: 'MAIN_SCREEN');
    super.initState();
    windowManager.addListener(this);

    DebugLogger.log('Starting services initialization...', tag: 'MAIN_SCREEN');
    _initializeServices();

    DebugLogger.log('Start minimized flag: ${widget.startMinimized}',
        tag: 'MAIN_SCREEN');

    // Don't auto-minimize until we confirm system tray is working
    // The system tray setup will handle minimizing if it succeeds
    DebugLogger.log('Main screen initState completed', tag: 'MAIN_SCREEN');
  }

  @override
  void dispose() {
    DebugLogger.log('===== MAIN SCREEN DISPOSAL =====', tag: 'MAIN_SCREEN');
    DebugLogger.log('Removing window listener...', tag: 'MAIN_SCREEN');
    windowManager.removeListener(this);
    DebugLogger.log('Disposing server service...', tag: 'MAIN_SCREEN');
    _serverService.dispose();
    DebugLogger.log('Main screen disposed', tag: 'MAIN_SCREEN');
    super.dispose();
  }

  /// Initialize services and streams
  Future<void> _initializeServices() async {
    DebugLogger.log('Services initialization starting...', tag: 'MAIN_SCREEN');

    DebugLogger.log('Initializing server service...', tag: 'MAIN_SCREEN');
    await _serverService.initialize();

    DebugLogger.log('Initializing settings service...', tag: 'MAIN_SCREEN');
    await _settingsService.initialize();

    // Sync startup setting with system
    await _syncStartupSetting();

    // Set initial state based on current server status
    setState(() {
      _isServerRunning = _serverService.isRunning;
    });
    DebugLogger.log('Initial server status: ${_serverService.isRunning}',
        tag: 'MAIN_SCREEN');

    DebugLogger.log('Setting up server log stream...', tag: 'MAIN_SCREEN');
    _serverService.logStream.listen((log) {
      DebugLogger.log('Server log: $log', tag: 'SERVER_LOG');
      setState(() {
        _logs.insert(0, log);
        if (_logs.length > 100) _logs.removeLast();
      });
    });

    DebugLogger.log('Setting up device stream...', tag: 'MAIN_SCREEN');
    _serverService.deviceStream.listen((device) {
      DebugLogger.log(
          'Device update: ${device.name} - Status: ${device.status}',
          tag: 'DEVICE_STREAM');
      setState(() {
        final existingIndex = _devices.indexWhere((d) => d.id == device.id);
        if (existingIndex != -1) {
          _devices[existingIndex] = device;
        } else {
          _devices.add(device);
        }
      });

      // Show permission dialog for pending devices
      if (device.status == ConnectionStatus.pending) {
        DebugLogger.log('Showing permission dialog for: ${device.name}',
            tag: 'DEVICE_STREAM');
        _showDevicePermissionDialog(device);
      }
    });

    DebugLogger.log('Setting up server status stream...', tag: 'MAIN_SCREEN');
    _serverService.serverStatusStream.listen((isRunning) {
      DebugLogger.log('Server status changed: $isRunning',
          tag: 'SERVER_STATUS');
      setState(() {
        _isServerRunning = isRunning;
      });
      // Update system tray menu when server status changes
      _updateSystemTrayMenu();
    }); // Setup system tray after services are initialized
    await _setupSystemTray();

    // Only minimize after system tray setup is attempted
    if (widget.startMinimized && _systemTrayAvailable) {
      DebugLogger.log('System tray available - minimizing to tray as requested',
          tag: 'MAIN_SCREEN');
      Future.delayed(const Duration(milliseconds: 500), () {
        _minimizeToTray();
      });
    } else if (widget.startMinimized && !_systemTrayAvailable) {
      DebugLogger.log(
          'System tray not available - keeping window visible for user access',
          tag: 'MAIN_SCREEN');
      _showWindow(); // Ensure window is visible
    }
  }

  /// Sync startup setting with system
  Future<void> _syncStartupSetting() async {
    DebugLogger.log('Syncing startup setting...', tag: 'MAIN_SCREEN');
    try {
      // Read startup preference from settings
      final shouldStartWithWindows = _settingsService.autoStart;
      DebugLogger.log('Auto-start setting: $shouldStartWithWindows',
          tag: 'MAIN_SCREEN');

      // Apply startup setting
      await StartupService.setStartupEnabled(shouldStartWithWindows);
      DebugLogger.log('Startup setting synced successfully',
          tag: 'MAIN_SCREEN');
    } catch (e) {
      DebugLogger.error('Failed to sync startup setting',
          tag: 'MAIN_SCREEN', error: e);
    }
  }

  /// Setup system tray
  Future<void> _setupSystemTray() async {
    try {
      // Initialize system tray
      DebugLogger.log('Initializing system tray...', tag: 'MAIN_SCREEN');

      // Try to initialize system tray with different approaches
      try {
        // Try with absolute path to icon
        final String iconPath = 'assets/icons/app_icon.png';
        await _systemTray.initSystemTray(
          title: "TouchPad Pro Server",
          iconPath: iconPath,
        );
        DebugLogger.log('System tray initialized with icon successfully',
            tag: 'MAIN_SCREEN');
      } catch (iconError) {
        DebugLogger.log(
            'Icon initialization failed, trying without icon: $iconError',
            tag: 'MAIN_SCREEN');

        // Try without icon (some systems might not support custom icons)
        await _systemTray.initSystemTray(
          title: "TouchPad Pro Server",
          iconPath: '', // Try with empty string
        );
        DebugLogger.log('System tray initialized without icon',
            tag: 'MAIN_SCREEN');
      }

      // If we get here, system tray initialization succeeded
      await _updateSystemTrayMenu();
      _systemTrayAvailable = true;

      DebugLogger.log('System tray setup completed successfully',
          tag: 'MAIN_SCREEN');
    } catch (e) {
      // System tray failed to initialize completely
      DebugLogger.error(
          'System tray initialization failed completely - will keep window visible',
          tag: 'MAIN_SCREEN',
          error: e);
      _systemTrayAvailable = false;

      // If system tray fails, ensure the window is visible and accessible
      DebugLogger.log('Ensuring window is visible since system tray failed',
          tag: 'MAIN_SCREEN');
      _showWindow();
    }
  }

  /// Update system tray menu based on server status
  Future<void> _updateSystemTrayMenu() async {
    if (!_systemTrayAvailable) return; // Skip if system tray is not available

    try {
      final connectedDeviceCount =
          _devices.where((d) => d.status == ConnectionStatus.connected).length;

      final Menu menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
            label: 'Show TouchPad Pro Server',
            onClicked: (menuItem) => _showWindow()),
        MenuItemLabel(
            label: _isServerRunning
                ? 'Server: Running (Port ${_serverService.currentPort})'
                : 'Server: Stopped',
            enabled: false,
            onClicked: null),
        MenuItemLabel(
            label: 'Connected Devices: $connectedDeviceCount',
            enabled: false,
            onClicked: null),
        MenuItemLabel(
            label: _isServerRunning ? 'Stop Server' : 'Start Server',
            onClicked: (menuItem) => _toggleServer()),
        MenuItemLabel(
            label: 'Server Settings',
            onClicked: (menuItem) => _openSettingsFromTray()),
        MenuItemLabel(
            label: _isServerRunning ? 'Stop Server & Exit' : 'Exit Application',
            onClicked: (menuItem) => _exitApp()),
      ]);
      await _systemTray.setContextMenu(menu);

      // Update tray tooltip with more information
      String tooltip = 'TouchPad Pro Server';
      if (_isServerRunning) {
        tooltip += ' - Running on port ${_serverService.currentPort}';
        if (connectedDeviceCount > 0) {
          tooltip +=
              ' ($connectedDeviceCount device${connectedDeviceCount == 1 ? '' : 's'} connected)';
        }
      } else {
        tooltip += ' - Stopped';
      }

      await _systemTray.setToolTip(tooltip);
    } catch (e) {
      DebugLogger.error('Failed to update system tray menu',
          tag: 'MAIN_SCREEN', error: e);
    }
  }

  /// Toggle server state
  Future<void> _toggleServer() async {
    DebugLogger.log('Toggle server called, current state: $_isServerRunning',
        tag: 'MAIN_SCREEN');
    if (_isServerRunning) {
      await _serverService.stopServer();
    } else {
      await _serverService.startServer();
    }
    // Force UI refresh (this should happen automatically via stream)
    setState(() {
      _isServerRunning = _serverService.isRunning;
    });
  }

  /// Show device permission dialog
  void _showDevicePermissionDialog(ConnectedDevice device) {
    bool rememberDevice = true; // Default to checked

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.devices_other, color: Colors.orange),
              SizedBox(width: 8),
              Text('New Device Connection'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A device is requesting to connect:'),
              SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Device: ${device.name}',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('ID: ${device.id.replaceFirst('mobile_', '')}'),
                      Text('IP: ${device.ipAddress}'),
                      Text(
                          'Time: ${device.connectedAt.toString().substring(11, 19)}'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),
              CheckboxListTile(
                value: rememberDevice,
                onChanged: (value) {
                  setState(() {
                    rememberDevice = value ?? true;
                  });
                },
                title: Text('Remember this device'),
                subtitle: Text('Skip this dialog for future connections'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _serverService.rejectConnection(device);
              },
              child: Text('Reject'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _serverService.trustDevice(device, remember: rememberDevice);
              },
              child: Text('Allow'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onPanStart: (details) {
            windowManager.startDragging();
          },
          child: Row(
            children: [
              Icon(Icons.computer, size: 28),
              SizedBox(width: 8),
              Text('TouchPad Pro Server'),
              Spacer(),
              _buildStatusIndicator(),
            ],
          ),
        ),
        automaticallyImplyLeading: false, // Remove default back button
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
          IconButton(
            icon: Icon(Icons.minimize),
            onPressed: _minimizeToTray,
            tooltip: 'Minimize to Tray',
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => _showExitConfirmationDialog().then((shouldExit) {
              if (shouldExit) _exitApp();
            }),
            tooltip: 'Exit',
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Badge(
                  label: Text('${_devices.length}'),
                  child: Icon(Icons.devices),
                ),
                label: Text('Devices'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.list_alt),
                label: Text('Logs'),
              ),
            ],
          ),
          VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _buildSelectedView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleServer,
        icon: Icon(_isServerRunning ? Icons.stop : Icons.play_arrow),
        label: Text(_isServerRunning ? 'Stop Server' : 'Start Server'),
        backgroundColor: _isServerRunning ? Colors.red : Colors.green,
      ),
    );
  }

  /// Build status indicator
  Widget _buildStatusIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isServerRunning ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isServerRunning ? Icons.check_circle : Icons.cancel,
            color: Colors.white,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            _isServerRunning ? 'Running' : 'Stopped',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Build selected view based on navigation
  Widget _buildSelectedView() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return DevicesScreen(devices: _devices, serverService: _serverService);
      case 2:
        return _buildLogsView();
      default:
        return _buildDashboard();
    }
  }

  /// Build dashboard view
  Widget _buildDashboard() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Server Dashboard',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDashboardCard(
                  'Server Status',
                  _isServerRunning ? 'Running' : 'Stopped',
                  _isServerRunning ? Icons.check_circle : Icons.cancel,
                  _isServerRunning ? Colors.green : Colors.red,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildDashboardCard(
                  'Connected Devices',
                  '${_devices.where((d) => d.status == ConnectionStatus.connected).length}',
                  Icons.devices,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildDashboardCard(
                  'Server Port',
                  '${_serverService.currentPort}',
                  Icons.router,
                  Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          Expanded(
            child: Card(
              child: ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: _logs.take(10).length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _logs[index],
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build dashboard card
  Widget _buildDashboardCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                SizedBox(width: 8),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build logs view
  Widget _buildLogsView() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Server Logs',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _logs.clear();
                  });
                },
                icon: Icon(Icons.clear),
                label: Text('Clear'),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      _logs[index],
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Window listener methods
  @override
  void onWindowClose() async {
    DebugLogger.log(
        'Window close event - checking server status: $_isServerRunning',
        tag: 'MAIN_SCREEN');

    // If server is running, minimize to tray instead of closing
    if (_isServerRunning) {
      DebugLogger.log(
          'Server is running - minimizing to tray to keep server alive',
          tag: 'MAIN_SCREEN');
      if (_systemTrayAvailable) {
        await _minimizeToTray();
      } else {
        DebugLogger.log(
            'System tray not available - using normal minimize to keep app accessible',
            tag: 'MAIN_SCREEN');
        await windowManager.minimize();
      }
    } else {
      DebugLogger.log('Server is not running - showing exit confirmation',
          tag: 'MAIN_SCREEN');
      // Server is not running, confirm if user wants to exit
      final shouldExit = await _showQuickExitDialog();
      if (shouldExit) {
        DebugLogger.log('User confirmed exit - closing application',
            tag: 'MAIN_SCREEN');
        await _exitApp();
      } else {
        DebugLogger.log('User cancelled exit - keeping window open',
            tag: 'MAIN_SCREEN');
      }
    }
  }

  @override
  void onWindowMinimize() async {
    DebugLogger.log('Window minimize event - minimizing to tray',
        tag: 'MAIN_SCREEN');
    if (_systemTrayAvailable) {
      await _minimizeToTray();
    } else {
      DebugLogger.log('System tray not available - using normal minimize',
          tag: 'MAIN_SCREEN');
      // Allow normal minimize behavior if system tray is not available
    }
  }

  /// Show window
  void _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setSkipTaskbar(false);
  }

  /// Minimize to tray
  Future<void> _minimizeToTray() async {
    if (_systemTrayAvailable) {
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
    } else {
      // If system tray is not available, just minimize normally
      await windowManager.minimize();
    }
  }

  /// Open settings
  void _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(settingsService: _settingsService),
      ),
    );
  }

  /// Open settings from system tray
  void _openSettingsFromTray() async {
    // Show window first to ensure it's visible
    _showWindow();
    // Then open settings
    _openSettings();
  }

  /// Exit application
  Future<void> _exitApp() async {
    // If server is running, ask user to confirm exit
    if (_isServerRunning) {
      final shouldExit = await _showExitConfirmationDialog();
      if (!shouldExit) return;
    }

    await _serverService.stopServer();
    await windowManager.close();
  }

  /// Show quick exit dialog when server is not running
  Future<bool> _showQuickExitDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.blue),
            SizedBox(width: 8),
            Text('Exit TouchPad Pro?'),
          ],
        ),
        content: Text('Are you sure you want to exit TouchPad Pro Server?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Exit'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Show exit confirmation dialog when server is running
  Future<bool> _showExitConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Server is Running'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'The TouchPad Pro Server is currently running and may have connected devices.'),
            SizedBox(height: 12),
            Text(
                'Exiting now will disconnect all clients and stop the server.'),
            SizedBox(height: 12),
            Text('Are you sure you want to exit?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Stop server first, then exit
              await _serverService.stopServer();
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Stop Server & Exit'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
