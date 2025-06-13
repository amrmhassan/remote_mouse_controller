import 'package:flutter/material.dart';
import '../services/websocket_service.dart';

/// Settings screen for adjusting mouse and scroll sensitivity
class SettingsScreen extends StatefulWidget {
  final WebSocketService webSocketService;

  const SettingsScreen({
    super.key,
    required this.webSocketService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _mouseSensitivity;
  late double _scrollSensitivity;
  late bool _reverseScroll;

  @override
  void initState() {
    super.initState();
    _mouseSensitivity = widget.webSocketService.mouseSensitivity;
    _scrollSensitivity = widget.webSocketService.scrollSensitivity;
    _reverseScroll = widget.webSocketService.reverseScroll;
  }
  void _resetToDefaults() {
    setState(() {
      _mouseSensitivity = 2.0;
      _scrollSensitivity = 1.0;
      _reverseScroll = false;
    });
    widget.webSocketService.mouseSensitivity = _mouseSensitivity;
    widget.webSocketService.scrollSensitivity = _scrollSensitivity;
    widget.webSocketService.reverseScroll = _reverseScroll;
  }

  void _applySettings() {
    widget.webSocketService.mouseSensitivity = _mouseSensitivity;
    widget.webSocketService.scrollSensitivity = _scrollSensitivity;
    widget.webSocketService.reverseScroll = _reverseScroll;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings applied successfully'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mouse Sensitivity Section
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mouse Sensitivity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current: ${_mouseSensitivity.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.deepPurple,
                        inactiveTrackColor: Colors.grey[700],
                        thumbColor: Colors.deepPurple,
                        overlayColor: Colors.deepPurple.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _mouseSensitivity,
                        min: 0.1,
                        max: 5.0,
                        divisions: 49,
                        onChanged: (value) {
                          setState(() {
                            _mouseSensitivity = value;
                          });
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Slow (0.1x)',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Fast (5.0x)',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Scroll Sensitivity Section
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scroll Sensitivity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current: ${_scrollSensitivity.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.deepPurple,
                        inactiveTrackColor: Colors.grey[700],
                        thumbColor: Colors.deepPurple,
                        overlayColor: Colors.deepPurple.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _scrollSensitivity,
                        min: 0.1,
                        max: 5.0,
                        divisions: 49,
                        onChanged: (value) {
                          setState(() {
                            _scrollSensitivity = value;
                          });
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Slow (0.1x)',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Fast (5.0x)',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),            ),

            const SizedBox(height: 20),

            // Reverse Scroll Section
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scroll Direction',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _reverseScroll ? 'Reversed' : 'Normal',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reverse Scroll Direction',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: _reverseScroll,
                          onChanged: (value) {
                            setState(() {
                              _reverseScroll = value;
                            });
                          },
                          activeColor: Colors.deepPurple,
                          activeTrackColor: Colors.deepPurple.withOpacity(0.5),
                          inactiveThumbColor: Colors.grey[400],
                          inactiveTrackColor: Colors.grey[700],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _reverseScroll 
                        ? 'Scrolling up moves content down' 
                        : 'Scrolling up moves content up',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetToDefaults,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Reset to Defaults'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applySettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Apply Settings'),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Information Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tips:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),                  const Text(
                    '• Mouse sensitivity affects cursor movement speed',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const Text(
                    '• Scroll sensitivity affects wheel scroll speed',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const Text(
                    '• Reverse scroll inverts scroll direction',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const Text(
                    '• Settings are applied immediately when changed',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const Text(
                    '• Use lower values for precise control',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
