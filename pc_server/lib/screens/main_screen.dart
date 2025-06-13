import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'dart:io';
import '../services/server_service.dart';
import '../services/settings_service.dart';
import 'settings_screen.dart';
import 'devices_screen.dart';

/// Main screen for TouchPad Pro Server
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  final ServerService _serverService = ServerService();
  final SettingsService _settingsService = SettingsService();
  final SystemTray _systemTray = SystemTray();

  final List<String> _logs = [];
  final List<ConnectedDevice> _devices = [];
  int _selectedIndex = 0;
  bool _isServerRunning = false;
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initializeServices();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _serverService.dispose();
    super.dispose();
  }
  /// Initialize services and streams
  Future<void> _initializeServices() async {
    await _serverService.initialize();
    await _settingsService.initialize();    // Set initial state based on current server status
    setState(() {
      _isServerRunning = _serverService.isRunning;
    });
    print('Initial server status: ${_serverService.isRunning}'); // Debug log

    // Listen to server streams
    _serverService.logStream.listen((log) {
      setState(() {
        _logs.insert(0, log);
        if (_logs.length > 100) _logs.removeLast();
      });
    });

    _serverService.deviceStream.listen((device) {
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
        _showDevicePermissionDialog(device);
      }
    });    _serverService.serverStatusStream.listen((isRunning) {
      print('Server status changed: $isRunning'); // Debug log
      setState(() {
        _isServerRunning = isRunning;
      });
      // Update system tray menu when server status changes
      _updateSystemTrayMenu();
    });// Setup auto-startup
    await _setupAutoStartup();
    
    // Setup system tray after services are initialized
    await _setupSystemTray();
  }
  /// Setup system tray
  Future<void> _setupSystemTray() async {
    try {
      await _systemTray.initSystemTray(
        title: "TouchPad Pro Server",
        iconPath: "windows/runner/resources/app_icon.ico",
      );
      
      await _updateSystemTrayMenu();
    } catch (e) {
      // System tray failed to initialize, continue without it
      print('System tray initialization failed: $e');
    }
  }
  /// Update system tray menu based on server status
  Future<void> _updateSystemTrayMenu() async {
    try {
      final Menu menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: 'Show TouchPad Pro Server', 
          onClicked: (menuItem) => _showWindow()
        ),
        MenuItemLabel(
          label: _isServerRunning ? 'Stop Server' : 'Start Server',
          onClicked: (menuItem) => _toggleServer()
        ),
        MenuItemLabel(
          label: 'Server Settings',
          onClicked: (menuItem) => _openSettings()
        ),
        MenuItemLabel(
          label: _isServerRunning ? 'Exit (Stop Server)' : 'Exit Application',
          onClicked: (menuItem) => _exitApp()
        ),
      ]);

      await _systemTray.setContextMenu(menu);
      
      // Update tray tooltip
      await _systemTray.setToolTip(
        _isServerRunning 
          ? 'TouchPad Pro Server - Running'
          : 'TouchPad Pro Server - Stopped'
      );
    } catch (e) {
      print('Failed to update system tray menu: $e');
    }
  }

  /// Setup auto-startup functionality
  Future<void> _setupAutoStartup() async {
    launchAtStartup.setup(
      appName: "TouchPad Pro Server",
      appPath: Platform.resolvedExecutable,
    );

    if (_settingsService.autoStart) {
      await launchAtStartup.enable();
    }
  }

  /// Toggle server state
  Future<void> _toggleServer() async {
    if (_isServerRunning) {
      await _serverService.stopServer();
    } else {
      await _serverService.startServer();
    }
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
        title: Row(
          children: [
            Icon(Icons.computer, size: 28),
            SizedBox(width: 8),
            Text('TouchPad Pro Server'),
            Spacer(),
            _buildStatusIndicator(),
          ],
        ),
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
            onPressed: _exitApp,
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
    // Always minimize to tray when close button is clicked
    // Only allow true exit from system tray menu or when server is stopped
    await _minimizeToTray();
  }

  /// Show window
  void _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }  /// Minimize to tray
  Future<void> _minimizeToTray() async {
    await windowManager.hide();
  }

  /// Open settings
  void _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(settingsService: _settingsService),
      ),
    );
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
            Text('The TouchPad Pro Server is currently running and may have connected devices.'),
            SizedBox(height: 12),
            Text('Exiting now will disconnect all clients and stop the server.'),
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
