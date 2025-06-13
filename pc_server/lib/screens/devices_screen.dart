import 'package:flutter/material.dart';
import '../services/server_service.dart';
import '../services/device_trust_service.dart';

/// Screen showing connected and trusted devices
class DevicesScreen extends StatefulWidget {
  final List<ConnectedDevice> devices;
  final ServerService serverService;

  const DevicesScreen({
    super.key,
    required this.devices,
    required this.serverService,
  });

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen>
    with TickerProviderStateMixin {
  int _selectedTabIndex = 0;
  late TabController _tabController;
  List<TrustedDevice> _trustedDevices = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTrustedDevices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Load trusted devices from service
  void _loadTrustedDevices() {
    setState(() {
      _trustedDevices = widget.serverService.getTrustedDevices();
    });
  }

  /// Refresh trusted devices when tab changes or actions occur
  void _refreshTrustedDevices() {
    _loadTrustedDevices();
  }

  @override
  Widget build(BuildContext context) {
    final connectedDevices = widget.devices
        .where((d) => d.status == ConnectionStatus.connected)
        .toList();
    final pendingDevices = widget.devices
        .where((d) => d.status == ConnectionStatus.pending)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device Management',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            onTap: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
              // Refresh trusted devices when that tab is selected
              if (index == 2) {
                _refreshTrustedDevices();
              }
            },
            tabs: [
              Tab(
                icon: Badge(
                  label: Text('${connectedDevices.length}'),
                  child: const Icon(Icons.devices),
                ),
                text: 'Connected',
              ),
              Tab(
                icon: Badge(
                  label: Text('${pendingDevices.length}'),
                  child: const Icon(Icons.pending),
                ),
                text: 'Pending',
              ),
              Tab(
                icon: const Icon(Icons.verified_user),
                text: 'Trusted',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildSelectedTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildConnectedDevices();
      case 1:
        return _buildPendingDevices();
      case 2:
        return _buildTrustedDevices();
      default:
        return _buildConnectedDevices();
    }
  }

  Widget _buildConnectedDevices() {
    final connectedDevices = widget.devices
        .where((d) => d.status == ConnectionStatus.connected)
        .toList();

    if (connectedDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No Connected Devices',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Start the server and connect from your mobile device',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: connectedDevices.length,
      itemBuilder: (context, index) {
        final device = connectedDevices[index];
        return _buildDeviceCard(device);
      },
    );
  }

  Widget _buildPendingDevices() {
    final pendingDevices = widget.devices
        .where((d) => d.status == ConnectionStatus.pending)
        .toList();

    if (pendingDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pending_actions, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No Pending Connections',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'New device connection requests will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: pendingDevices.length,
      itemBuilder: (context, index) {
        final device = pendingDevices[index];
        return _buildPendingDeviceCard(device);
      },
    );
  }

  Widget _buildTrustedDevices() {
    if (_trustedDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No Trusted Devices',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Devices you trust will appear here and connect automatically',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _trustedDevices.length,
      itemBuilder: (context, index) {
        final trustedDevice = _trustedDevices[index];
        return _buildTrustedDeviceCard(trustedDevice);
      },
    );
  }

  Widget _buildTrustedDeviceCard(TrustedDevice trustedDevice) {
    final isCurrentlyConnected = widget.devices.any((d) =>
        d.id == trustedDevice.id && d.status == ConnectionStatus.connected);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      isCurrentlyConnected ? Colors.green : Colors.grey,
                  child: Icon(
                    isCurrentlyConnected
                        ? Icons.smartphone
                        : Icons.smartphone_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trustedDevice.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Trusted on ${trustedDevice.trustedAt.toString().substring(0, 19)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (isCurrentlyConnected)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Currently Connected',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      _handleTrustedDeviceAction(trustedDevice, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'untrust',
                      child: ListTile(
                        leading: Icon(Icons.remove_circle_outline,
                            color: Colors.red),
                        title: Text('Remove Trust'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (isCurrentlyConnected)
                      const PopupMenuItem(
                        value: 'disconnect',
                        child: ListTile(
                          leading: Icon(Icons.link_off, color: Colors.orange),
                          title: Text('Disconnect'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(ConnectedDevice device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.smartphone, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        device.ipAddress,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleDeviceAction(device, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'disconnect',
                      child: ListTile(
                        leading: Icon(Icons.close),
                        title: Text('Disconnect'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'info',
                      child: ListTile(
                        leading: Icon(Icons.info),
                        title: Text('Device Info'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                    'Connected', '${device.connectionDuration.inMinutes}m ago'),
                const SizedBox(width: 8),
                _buildInfoChip('Actions', '${device.totalActions}'),
                const SizedBox(width: 8),
                _buildInfoChip('Last Activity',
                    _formatDuration(device.timeSinceLastActivity)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingDeviceCard(ConnectedDevice device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.smartphone, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        device.ipAddress,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Waiting for permission',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        widget.serverService.rejectConnection(device),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.serverService
                        .trustDevice(device, remember: true),
                    child: const Text('Allow'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inHours}h';
    }
  }

  void _handleDeviceAction(ConnectedDevice device, String action) {
    switch (action) {
      case 'disconnect':
        widget.serverService.disconnectDevice(device);
        break;
      case 'info':
        _showDeviceInfo(device);
        break;
    }
  }

  void _handleTrustedDeviceAction(TrustedDevice trustedDevice, String action) {
    switch (action) {
      case 'untrust':
        _showUntrustConfirmation(trustedDevice);
        break;
      case 'disconnect':
        // Find the connected device and disconnect it
        final connectedDevice = widget.devices
            .where((d) =>
                d.id == trustedDevice.id &&
                d.status == ConnectionStatus.connected)
            .firstOrNull;
        if (connectedDevice != null) {
          widget.serverService.disconnectDevice(connectedDevice);
        }
        break;
    }
  }

  void _showUntrustConfirmation(TrustedDevice trustedDevice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Remove Trust'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to remove trust from this device?'),
            SizedBox(height: 8),
            Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device: ${trustedDevice.name}',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'Trusted: ${trustedDevice.trustedAt.toString().substring(0, 19)}'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'This device will need permission to connect again in the future.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _untrustDevice(trustedDevice);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Remove Trust', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _untrustDevice(TrustedDevice trustedDevice) async {
    await widget.serverService.untrustDevice(trustedDevice.id);
    _refreshTrustedDevices();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trust removed from ${trustedDevice.name}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showDeviceInfo(ConnectedDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Device Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', device.name),
            _buildInfoRow('IP Address', device.ipAddress),
            _buildInfoRow('Device ID', device.id),
            _buildInfoRow('Connected At', device.connectedAt.toString()),
            _buildInfoRow(
                'Connection Duration', device.connectionDuration.toString()),
            _buildInfoRow('Total Actions', device.totalActions.toString()),
            _buildInfoRow('Last Activity', device.lastActivity.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
