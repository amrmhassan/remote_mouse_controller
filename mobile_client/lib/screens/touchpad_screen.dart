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

  // Scroll smoothing variables
  DateTime? _lastScrollTime;
  final List<double> _recentScrollDeltas = [];
  final int _maxScrollSamples = 2; // Reduced for responsiveness
  bool _isDragging = false;
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  int _tapCount = 0;
  final Duration _doubleTapWindow = const Duration(milliseconds: 300);
  final Duration _dragHoldThreshold = const Duration(milliseconds: 500);
  final Duration _singleTapDelay = const Duration(milliseconds: 150);
  Timer? _tapTimer;
  Timer? _singleTapTimer;
  bool _waitingForSecondTap = false;
  bool _hasMovedDuringGesture = false;
  final double _movementThreshold = 10.0; // pixels

  // Multi-finger tracking
  Set<int> _activePointers = <int>{};
  DateTime? _lastMultiTapTime;
  @override
  void initState() {
    super.initState();

    // Hide system UI for fullscreen experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Cancel any active timers
    _tapTimer?.cancel();
    _singleTapTimer?.cancel();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Check if this is significant movement (not just a tap)
    if (!_hasMovedDuringGesture && _lastTapPosition != null) {
      final movementDistance =
          (details.globalPosition - _lastTapPosition!).distance;
      if (movementDistance > _movementThreshold) {
        _hasMovedDuringGesture = true;
      }
    }

    // Direct mouse movement with minimal processing for best responsiveness
    _sendSmoothedMouseMove(details.delta.dx, details.delta.dy);
  }

  void _sendSmoothedMouseMove(double deltaX, double deltaY) {
    // Direct mouse movement for best performance
    try {
      widget.webSocketService.sendMouseMove(deltaX, deltaY);
    } catch (e) {
      print('[TOUCHPAD] Error sending mouse move: $e');
    }
  }

  /// Handle pointer down events for multi-finger detection
  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);

    // Track the initial position for movement detection
    if (_activePointers.length == 1) {
      _lastTapPosition = event.position;
      _hasMovedDuringGesture = false;
    }

    // Minimal logging for performance
  }

  /// Handle pointer up events for multi-finger detection and tap detection
  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);

    // Minimal logging for performance

    // Only handle single-finger tap detection if there was no significant movement
    if (_activePointers.isEmpty && !_hasMovedDuringGesture) {
      final now = DateTime.now();
      _handleTapDetection(event.position, now);
    } else if (_activePointers.isEmpty && _hasMovedDuringGesture) {
      // Reset movement tracking for next gesture
      _hasMovedDuringGesture = false;
    }

    // Check for two-finger tap (right click)
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

  /// Handle tap detection for single finger taps
  void _handleTapDetection(Offset position, DateTime now) {
    // Minimal logging for performance

    if (_lastTapTime != null && _lastTapPosition != null) {
      final timeDifference = now.difference(_lastTapTime!);
      final distanceDifference = (position - _lastTapPosition!).distance;

      // Check if this is a valid double-tap (within time and distance threshold)
      if (timeDifference <= _doubleTapWindow && distanceDifference < 50.0) {
        _tapCount++;

        // Cancel any pending single tap
        _singleTapTimer?.cancel();
        _waitingForSecondTap = false;

        if (_tapCount == 2) {
          // Start waiting for potential drag
          _startDoubleTapHoldTimer();
          return;
        }
      } else {
        // Reset tap count if outside window or too far
        _tapCount = 1;
      }
    } else {
      _tapCount = 1;
    }

    _lastTapTime = now;
    _lastTapPosition = position;

    // If this is the first tap, start timer to check for single tap
    if (_tapCount == 1) {
      _waitingForSecondTap = true;
      _singleTapTimer?.cancel();
      _singleTapTimer = Timer(_singleTapDelay, () {
        if (_waitingForSecondTap && _tapCount == 1) {
          // Single tap confirmed - send left click
          _performSingleTap();
        }
        _waitingForSecondTap = false;
      });
    }
  }

  /// Start the double-tap hold timer for drag detection
  void _startDoubleTapHoldTimer() {
    _tapTimer?.cancel();
    _tapTimer = Timer(_dragHoldThreshold, () {
      if (!_isDragging && _tapCount >= 2) {
        // Hold threshold reached, start drag
        _isDragging = true;
        widget.webSocketService.sendMouseDownLeft();
        _triggerHapticFeedback();
      }
    });
  }

  /// Perform single tap (left click)
  void _performSingleTap() {
    try {
      widget.webSocketService.sendLeftClick();
      _triggerHapticFeedback();
    } catch (e) {
      print('[TOUCHPAD] Error sending left click: $e');
    }

    // Reset tap state
    _resetTapState();
  }

  /// Reset tap detection state
  void _resetTapState() {
    _tapCount = 0;
    _lastTapTime = null;
    _lastTapPosition = null;
    _waitingForSecondTap = false;
    _hasMovedDuringGesture = false;
    _singleTapTimer?.cancel();
    _tapTimer?.cancel();
  }

  /// Trigger haptic feedback if enabled
  Future<void> _triggerHapticFeedback() async {
    if (widget.webSocketService.hapticFeedback) {
      try {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
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

  /// Handle two-finger tap (right click)
  void _onTwoFingerTap() {
    try {
      widget.webSocketService.sendRightClick();
      _triggerHapticFeedback();
    } catch (e) {
      print('[TOUCHPAD] Error sending right click: $e');
    }
  }

  /// Handle pan start for potential drag-and-drop
  void _onPanStart(DragStartDetails details) {
    // Minimal logging for performance

    // If we're already in drag mode from double-tap and hold, continue dragging
    if (_isDragging) {
      return;
    }

    // If user starts dragging after double-tap but before hold threshold, start drag immediately
    if (_tapCount >= 2 && _tapTimer != null && _tapTimer!.isActive) {
      _tapTimer?.cancel();
      _isDragging = true;
      widget.webSocketService.sendMouseDownLeft();
      _triggerHapticFeedback();
      return;
    }

    // For normal mouse movement, clear any pending tap detection
    // This ensures smooth mouse movement without interference
    if (_tapCount > 0 && (_tapTimer?.isActive ?? false)) {
      _tapTimer?.cancel();
    }

    // Cancel single tap timer if user starts moving (movement = not a tap)
    if (_singleTapTimer?.isActive ?? false) {
      _singleTapTimer?.cancel();
      _waitingForSecondTap = false;
    }
  }

  /// Handle pan end for drag-and-drop completion
  void _onPanEnd(DragEndDetails details) {
    // Only handle drag operations
    if (_isDragging) {
      _isDragging = false;
      widget.webSocketService.sendMouseUpLeft();
      _triggerHapticFeedback();

      // Reset tap state after drag operation
      _resetTapState();
    }

    // Reset movement tracking for next gesture
    _hasMovedDuringGesture = false;
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

    try {
      widget.webSocketService.sendScroll(smoothedScrollDelta);
    } catch (e) {
      print('[TOUCHPAD] Error sending scroll: $e');
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _disconnect() {
    widget.webSocketService.forceDisconnect();
  }

  void _openSettings() {
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
