import 'package:flutter/material.dart';
import '../services/server_service.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    // This would show trusted devices from the trust service
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Trusted Devices',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Coming soon: Manage trusted devices',
            style: TextStyle(color: Colors.grey),
          ),
        ],
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
