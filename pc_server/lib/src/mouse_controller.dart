import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import '../utils/debug_logger.dart';

/// Handles mouse control operations on Windows using Win32 API
class MouseController {
  /// Moves the mouse cursor by the specified delta values
  Future<void> moveMouse(double deltaX, double deltaY) async {
    DebugLogger.log('moveMouse called - deltaX: $deltaX, deltaY: $deltaY',
        tag: 'MOUSE');

    if (!Platform.isWindows) {
      DebugLogger.error('Mouse control is only supported on Windows',
          tag: 'MOUSE');
      return;
    }

    try {
      DebugLogger.log('Getting current cursor position...', tag: 'MOUSE');
      // Get current cursor position
      final point = calloc<POINT>();
      GetCursorPos(point);

      final currentX = point.ref.x;
      final currentY = point.ref.y;
      DebugLogger.log('Current position: ($currentX, $currentY)', tag: 'MOUSE');

      // Calculate new position
      final newX = currentX + deltaX.round();
      final newY = currentY + deltaY.round();
      DebugLogger.log('Moving to new position: ($newX, $newY)', tag: 'MOUSE');

      // Set new cursor position
      SetCursorPos(newX, newY);
      DebugLogger.log('Mouse move completed successfully', tag: 'MOUSE');

      calloc.free(point);
    } catch (e) {
      DebugLogger.error('Error moving mouse: $e', tag: 'MOUSE');
    }
  }

  /// Performs a left mouse button click
  Future<void> leftClick() async {
    DebugLogger.log('leftClick called', tag: 'MOUSE');

    if (!Platform.isWindows) {
      DebugLogger.error('Mouse control is only supported on Windows',
          tag: 'MOUSE');
      return;
    }
    try {
      DebugLogger.log('Sending left mouse down event...', tag: 'MOUSE');
      // Send mouse down and up events using SendInput
      _sendMouseEvent(MOUSEEVENTF_LEFTDOWN);

      DebugLogger.log('Waiting 50ms between down and up...', tag: 'MOUSE');
      await Future.delayed(const Duration(milliseconds: 50));

      DebugLogger.log('Sending left mouse up event...', tag: 'MOUSE');
      _sendMouseEvent(MOUSEEVENTF_LEFTUP);

      DebugLogger.log('Left click completed successfully', tag: 'MOUSE');
    } catch (e) {
      DebugLogger.error('Error performing left click: $e', tag: 'MOUSE');
    }
  }

  /// Performs a right mouse button click
  Future<void> rightClick() async {
    DebugLogger.log('rightClick called', tag: 'MOUSE');

    if (!Platform.isWindows) {
      DebugLogger.error('Mouse control is only supported on Windows',
          tag: 'MOUSE');
      return;
    }

    try {
      DebugLogger.log('Sending right mouse down event...',
          tag: 'MOUSE'); // Send right mouse down and up events
      _sendMouseEvent(MOUSEEVENTF_RIGHTDOWN);

      DebugLogger.log('Waiting 50ms between down and up...', tag: 'MOUSE');
      await Future.delayed(const Duration(milliseconds: 50));

      DebugLogger.log('Sending right mouse up event...', tag: 'MOUSE');
      _sendMouseEvent(MOUSEEVENTF_RIGHTUP);

      DebugLogger.log('Right click completed successfully', tag: 'MOUSE');
    } catch (e) {
      DebugLogger.error('Error performing right click: $e', tag: 'MOUSE');
    }
  }

  /// Scrolls the mouse wheel
  Future<void> scroll(double deltaY) async {
    DebugLogger.log('scroll called - deltaY: $deltaY', tag: 'MOUSE');

    if (!Platform.isWindows) {
      DebugLogger.error('Mouse control is only supported on Windows',
          tag: 'MOUSE');
      return;
    }

    try {
      // Convert delta to wheel units (negative for natural scrolling)
      final wheelDelta = (-deltaY * 120).round();
      DebugLogger.log('Converting deltaY $deltaY to wheelDelta $wheelDelta',
          tag: 'MOUSE');

      _sendMouseEvent(MOUSEEVENTF_WHEEL, wheelData: wheelDelta);
      DebugLogger.log('Scroll completed successfully', tag: 'MOUSE');
    } catch (e) {
      DebugLogger.error('Error scrolling: $e', tag: 'MOUSE');
    }
  }

  /// Helper method to send mouse events using SendInput API
  void _sendMouseEvent(int eventType, {int wheelData = 0}) {
    DebugLogger.log(
        '_sendMouseEvent called - eventType: $eventType, wheelData: $wheelData',
        tag: 'MOUSE');
    try {
      final input = calloc<INPUT>();
      input.ref.type = INPUT_MOUSE;
      input.ref.mi.dwFlags = eventType;
      input.ref.mi.mouseData = wheelData;
      input.ref.mi.dwExtraInfo = 0;
      input.ref.mi.time = 0;
      input.ref.mi.dx = 0;
      input.ref.mi.dy = 0;

      DebugLogger.log('Sending input event...', tag: 'MOUSE');
      final result = SendInput(1, input, sizeOf<INPUT>());
      DebugLogger.log('SendInput result: $result', tag: 'MOUSE');

      calloc.free(input);
      DebugLogger.log('_sendMouseEvent completed', tag: 'MOUSE');
    } catch (e) {
      DebugLogger.error('Error in _sendMouseEvent: $e', tag: 'MOUSE');
    }
  }
}
