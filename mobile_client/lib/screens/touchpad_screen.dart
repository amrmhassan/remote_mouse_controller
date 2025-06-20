import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/websocket_service.dart';
import 'settings_screen.dart';

/// Fullscreen touchpad screen for mouse control
class TouchpadScreen extends StatefulWidget {
  final WebSocketService webSocketService;

  const TouchpadScreen({super.key, required this.webSocketService});

  @override
  State<TouchpadScreen> createState() => _TouchpadScreenState();
}

class _TouchpadScreenState extends State<TouchpadScreen> {
  bool _showControls = false;
  @override
  void initState() {
    super.initState();
    print('[TOUCHPAD] initState called');

    // Hide system UI for fullscreen experience
    print('[TOUCHPAD] Setting immersive sticky UI mode...');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    print('[TOUCHPAD] UI mode set');
  }

  @override
  void dispose() {
    print('[TOUCHPAD] dispose called');

    // Restore system UI
    print('[TOUCHPAD] Restoring edge-to-edge UI mode...');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    print('[TOUCHPAD] UI mode restored');

    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    print(
      '[TOUCHPAD] _onPanUpdate called - delta: (${details.delta.dx}, ${details.delta.dy})',
    );

    // Use the WebSocket service's sensitivity setting
    final deltaX = details.delta.dx;
    final deltaY = details.delta.dy;

    print(
      '[TOUCHPAD] Sending mouse move with deltaX: $deltaX, deltaY: $deltaY',
    );
    widget.webSocketService.sendMouseMove(deltaX, deltaY);
  }

  void _onTap() {
    print('[TOUCHPAD] _onTap called - sending left click');

    // Single tap = left click
    widget.webSocketService.sendLeftClick();

    // Provide haptic feedback
    print('[TOUCHPAD] Providing light haptic feedback');
    HapticFeedback.lightImpact();
  }

  void _onLongPress() {
    print('[TOUCHPAD] _onLongPress called - sending right click');

    // Long press = right click
    widget.webSocketService.sendRightClick();

    // Provide haptic feedback
    print('[TOUCHPAD] Providing medium haptic feedback');
    HapticFeedback.mediumImpact();
  }

  void _onScroll(double deltaY) {
    print('[TOUCHPAD] _onScroll called - deltaY: $deltaY');
    widget.webSocketService.sendScroll(deltaY);
  }

  void _toggleControls() {
    print('[TOUCHPAD] _toggleControls called - current state: $_showControls');
    setState(() {
      _showControls = !_showControls;
    });
    print('[TOUCHPAD] Controls visibility toggled to: $_showControls');
  }

  void _disconnect() {
    print('[TOUCHPAD] _disconnect called - forcing disconnect');
    widget.webSocketService.forceDisconnect();
  }

  void _openSettings() {
    print('[TOUCHPAD] _openSettings called - navigating to settings screen');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SettingsScreen(webSocketService: widget.webSocketService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main touchpad area
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              onTap: _onTap,
              onLongPress: _onLongPress,
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: Text(
                    'TouchPad Pro\n\n'
                    'Drag to move cursor\n'
                    'Tap to left click\n'
                    'Long press to right click\n'
                    'Right edge for scrolling\n'
                    'Double tap top edge for controls',
                    style: TextStyle(color: Colors.white24, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

          // Top edge for revealing controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 60,
            child: GestureDetector(
              onDoubleTap: _toggleControls,
              child: Container(color: Colors.transparent),
            ),
          ),

          // Scroll area (right edge)
          Positioned(
            top: 100,
            right: 0,
            bottom: 100,
            width: 80,
            child: GestureDetector(
              onPanUpdate: (details) {
                _onScroll(-details.delta.dy);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: Border(
                    left: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: const Center(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      'SCROLL',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Controls overlay
          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Connection status
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: widget.webSocketService.isConnected
                                  ? Colors.green
                                  : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.webSocketService.isConnected
                                ? 'Connected'
                                : 'Disconnected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ), // Control buttons
                      Row(
                        children: [
                          IconButton(
                            onPressed: _openSettings,
                            icon: const Icon(Icons.settings),
                            color: Colors.white,
                            tooltip: 'Settings',
                          ),
                          IconButton(
                            onPressed: _toggleControls,
                            icon: const Icon(Icons.keyboard_arrow_up),
                            color: Colors.white,
                            tooltip: 'Hide Controls',
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _disconnect,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Disconnect'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
