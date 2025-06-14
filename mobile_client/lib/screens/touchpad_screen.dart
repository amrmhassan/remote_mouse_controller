import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
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

  // Gesture smoothing variables
  DateTime? _lastGestureTime;
  final List<Offset> _recentDeltas = [];
  final int _maxDeltaSamples = 5;
  final Duration _gestureDebounceTime = const Duration(milliseconds: 100);
  double _velocityDampingFactor = 0.7;

  // Scroll smoothing variables
  DateTime? _lastScrollTime;
  final List<double> _recentScrollDeltas = [];
  final int _maxScrollSamples = 3;
  // New gesture detection variables
  bool _isDragging = false;
  DateTime? _lastTapTime;
  int _tapCount = 0;
  final Duration _doubleTapWindow = const Duration(milliseconds: 300);
  final Duration _dragHoldThreshold = const Duration(milliseconds: 500);
  Timer? _tapTimer;

  // Multi-finger tracking
  Set<int> _activePointers = <int>{};
  DateTime? _lastMultiTapTime;

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

    // Cancel any active timers
    _tapTimer?.cancel();

    // Restore system UI
    print('[TOUCHPAD] Restoring edge-to-edge UI mode...');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    print('[TOUCHPAD] UI mode restored');

    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final now = DateTime.now();

    // Apply debouncing for initial gesture to prevent velocity spikes
    if (_lastGestureTime == null) {
      _lastGestureTime = now;
      // For the first gesture, apply strong dampening
      final dampedDelta = details.delta * 0.3;
      _recentDeltas.add(dampedDelta);
      _sendSmoothedMouseMove(dampedDelta.dx, dampedDelta.dy);
      return;
    }

    // Check if enough time has passed since last gesture
    final timeSinceLastGesture = now.difference(_lastGestureTime!);

    // Add current delta to recent deltas for averaging
    _recentDeltas.add(details.delta);
    if (_recentDeltas.length > _maxDeltaSamples) {
      _recentDeltas.removeAt(0);
    }

    // Apply velocity dampening based on time since last gesture
    double dampingFactor = _velocityDampingFactor;
    if (timeSinceLastGesture < _gestureDebounceTime) {
      // Recent gesture - apply more dampening
      dampingFactor *= 0.6;
    }

    // Calculate smoothed delta using moving average
    final avgDelta = _calculateAverageOffset(_recentDeltas);
    final smoothedDelta = avgDelta * dampingFactor;

    _lastGestureTime = now;
    _sendSmoothedMouseMove(smoothedDelta.dx, smoothedDelta.dy);
  }

  Offset _calculateAverageOffset(List<Offset> deltas) {
    if (deltas.isEmpty) return Offset.zero;

    double totalDx = 0;
    double totalDy = 0;

    for (final delta in deltas) {
      totalDx += delta.dx;
      totalDy += delta.dy;
    }

    return Offset(totalDx / deltas.length, totalDy / deltas.length);
  }

  void _sendSmoothedMouseMove(double deltaX, double deltaY) {
    print(
      '[TOUCHPAD] Sending smoothed mouse move - deltaX: $deltaX, deltaY: $deltaY',
    );

    try {
      widget.webSocketService.sendMouseMove(deltaX, deltaY);
    } catch (e) {
      print('[TOUCHPAD] Error sending mouse move: $e');
    }
  }

  /// Handle pointer down events for multi-finger detection
  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    print(
      '[TOUCHPAD] Pointer down: ${event.pointer}, active pointers: ${_activePointers.length}',
    );
  }

  /// Handle pointer up events for multi-finger detection
  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    print(
      '[TOUCHPAD] Pointer up: ${event.pointer}, active pointers: ${_activePointers.length}',
    );

    // Check for two-finger tap
    if (_activePointers.isEmpty && _lastMultiTapTime != null) {
      final now = DateTime.now();
      if (now.difference(_lastMultiTapTime!).inMilliseconds < 200) {
        _onTwoFingerTap();
      }
      _lastMultiTapTime = null;
    } else if (_activePointers.length == 1) {
      // Mark time when we go from 2+ fingers to 1 finger
      _lastMultiTapTime = DateTime.now();
    }
  }

  /// Trigger haptic feedback if enabled
  Future<void> _triggerHapticFeedback() async {
    if (widget.webSocketService.hapticFeedback) {
      try {
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 50);
        } else {
          // Fallback to Flutter's haptic feedback
          HapticFeedback.lightImpact();
        }
      } catch (e) {
        print('[TOUCHPAD] Error triggering haptic feedback: $e');
        // Fallback to Flutter's haptic feedback
        HapticFeedback.lightImpact();
      }
    }
  }

  /// Handle single-finger tap (left click)
  void _onTap() {
    print('[TOUCHPAD] Single-finger tap detected - sending left click');

    try {
      widget.webSocketService.sendLeftClick();
      _triggerHapticFeedback();
    } catch (e) {
      print('[TOUCHPAD] Error sending left click: $e');
    }
  }

  /// Handle two-finger tap (right click)
  void _onTwoFingerTap() {
    print('[TOUCHPAD] Two-finger tap detected - sending right click');

    try {
      widget.webSocketService.sendRightClick();
      _triggerHapticFeedback();
    } catch (e) {
      print('[TOUCHPAD] Error sending right click: $e');
    }
  }

  /// Handle pan start for potential drag-and-drop
  void _onPanStart(DragStartDetails details) {
    final now = DateTime.now();

    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds <
            _doubleTapWindow.inMilliseconds) {
      _tapCount++;
      print('[TOUCHPAD] Tap count: $_tapCount');

      if (_tapCount == 2) {
        // Double-tap detected, start drag preparation
        print('[TOUCHPAD] Double-tap detected, preparing for potential drag');
        _tapTimer?.cancel();
        _tapTimer = Timer(_dragHoldThreshold, () {
          if (!_isDragging) {
            // Hold threshold reached, start drag
            print('[TOUCHPAD] Starting drag operation');
            _isDragging = true;
            widget.webSocketService.sendMouseDownLeft();
          }
        });
      }
    } else {
      _tapCount = 1;
    }

    _lastTapTime = now;
  }

  /// Handle pan end for drag-and-drop completion
  void _onPanEnd(DragEndDetails details) {
    _tapTimer?.cancel();

    if (_isDragging) {
      print('[TOUCHPAD] Ending drag operation');
      _isDragging = false;
      widget.webSocketService.sendMouseUpLeft();
    }

    // Reset tap count after a delay
    Timer(const Duration(milliseconds: 400), () {
      _tapCount = 0;
    });
  }

  void _onScroll(double deltaY) {
    final now = DateTime.now();

    // Add scroll dampening and smoothing
    _recentScrollDeltas.add(deltaY);
    if (_recentScrollDeltas.length > _maxScrollSamples) {
      _recentScrollDeltas.removeAt(0);
    }

    // Calculate smoothed scroll delta
    final avgScrollDelta =
        _recentScrollDeltas.reduce((a, b) => a + b) /
        _recentScrollDeltas.length;

    // Apply time-based dampening for scroll
    double scrollDampening = 1.0;
    if (_lastScrollTime != null) {
      final timeSinceLastScroll = now.difference(_lastScrollTime!);
      if (timeSinceLastScroll.inMilliseconds < 50) {
        scrollDampening = 0.7; // Reduce rapid scroll sensitivity
      }
    }

    final smoothedScrollDelta = avgScrollDelta * scrollDampening;
    _lastScrollTime = now;

    print('[TOUCHPAD] Sending smoothed scroll - deltaY: $smoothedScrollDelta');

    try {
      widget.webSocketService.sendScroll(smoothedScrollDelta);
    } catch (e) {
      print('[TOUCHPAD] Error sending scroll: $e');
    }
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
          // Main touchpad area with gesture recognition
          Positioned.fill(
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerUp: _onPointerUp,
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onTap: _onTap,
                child: Container(
                  color: Colors.black,
                  child: const Center(
                    child: Text(
                      'TouchPad Pro\n\n'
                      'Drag to move cursor\n'
                      'Single tap for left click\n'
                      'Two-finger tap for right click\n'
                      'Double-tap and hold to drag\n'
                      'Right edge for scrolling\n'
                      'Double tap top edge for controls',
                      style: TextStyle(color: Colors.white24, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
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
