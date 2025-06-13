import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import '../services/settings_service.dart';

/// Settings screen for TouchPad Pro Server
class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;

  const SettingsScreen({super.key, required this.settingsService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _portController;
  late bool _autoStart;
  late bool _requirePermission;
  late bool _minimizeToTray;
  late bool _showNotifications;
  late bool _startMinimized;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    _portController = TextEditingController(
      text: widget.settingsService.serverPort.toString(),
    );
    _autoStart = widget.settingsService.autoStart;
    _requirePermission = widget.settingsService.requirePermission;
    _minimizeToTray = widget.settingsService.minimizeToTray;
    _showNotifications = widget.settingsService.showNotifications;
    _startMinimized = widget.settingsService.startMinimized;
  }

  Future<void> _saveSettings() async {
    // Validate port
    final port = int.tryParse(_portController.text);
    if (port == null || port < 1024 || port > 65535) {
      _showErrorDialog('Invalid port number. Please enter a port between 1024 and 65535.');
      return;
    }

    // Save all settings
    await widget.settingsService.setServerPort(port);
    await widget.settingsService.setAutoStart(_autoStart);
    await widget.settingsService.setRequirePermission(_requirePermission);
    await widget.settingsService.setMinimizeToTray(_minimizeToTray);
    await widget.settingsService.setShowNotifications(_showNotifications);
    await widget.settingsService.setStartMinimized(_startMinimized);

    // Handle auto-startup
    if (_autoStart) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings to defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.settingsService.resetToDefaults();
      setState(() {
        _loadSettings();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings reset to defaults'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to Defaults',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildServerSection(),
                  const SizedBox(height: 24),
                  _buildSecuritySection(),
                  const SizedBox(height: 24),
                  _buildUISection(),
                  const SizedBox(height: 24),
                  _buildStartupSection(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildServerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Server Port',
                hintText: 'Enter port number (1024-65535)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            const Text(
              'Port used by the server for incoming connections. Restart server after changing.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Require Permission for New Devices'),
              subtitle: const Text('Ask before allowing new devices to connect'),
              value: _requirePermission,
              onChanged: (value) {
                setState(() {
                  _requirePermission = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUISection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Interface',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Minimize to System Tray'),
              subtitle: const Text('Hide window in system tray when closed'),
              value: _minimizeToTray,
              onChanged: (value) {
                setState(() {
                  _minimizeToTray = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Show Notifications'),
              subtitle: const Text('Display notifications for device connections'),
              value: _showNotifications,
              onChanged: (value) {
                setState(() {
                  _showNotifications = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartupSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Startup Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Start with Windows'),
              subtitle: const Text('Automatically start server when Windows starts'),
              value: _autoStart,
              onChanged: (value) {
                setState(() {
                  _autoStart = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Start Minimized'),
              subtitle: const Text('Start in system tray without showing window'),
              value: _startMinimized,
              onChanged: (value) {
                setState(() {
                  _startMinimized = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _saveSettings,
            child: const Text('Save Settings'),
          ),
        ),
      ],
    );
  }
}
