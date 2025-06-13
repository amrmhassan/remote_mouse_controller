import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Handles mouse control operations on Windows using Win32 API
class MouseController {
  /// Moves the mouse cursor by the specified delta values
  Future<void> moveMouse(double deltaX, double deltaY) async {
    print('[MOUSE] moveMouse called - deltaX: $deltaX, deltaY: $deltaY');

    if (!Platform.isWindows) {
      print('[MOUSE] ERROR: Mouse control is only supported on Windows');
      return;
    }

    try {
      print('[MOUSE] Getting current cursor position...');
      // Get current cursor position
      final point = calloc<POINT>();
      GetCursorPos(point);

      final currentX = point.ref.x;
      final currentY = point.ref.y;
      print('[MOUSE] Current position: ($currentX, $currentY)');

      // Calculate new position
      final newX = currentX + deltaX.round();
      final newY = currentY + deltaY.round();
      print('[MOUSE] Moving to new position: ($newX, $newY)');

      // Set new cursor position
      SetCursorPos(newX, newY);
      print('[MOUSE] Mouse move completed successfully');

      calloc.free(point);
    } catch (e) {
      print('[MOUSE] ERROR moving mouse: $e');
      print('[MOUSE] Stack trace: ${StackTrace.current}');
    }
  }

  /// Performs a left mouse button click
  Future<void> leftClick() async {
    print('[MOUSE] leftClick called');

    if (!Platform.isWindows) {
      print('[MOUSE] ERROR: Mouse control is only supported on Windows');
      return;
    }

    try {
      print('[MOUSE] Sending left mouse down event...');
      // Send mouse down and up events using SendInput
      _sendMouseEvent(MOUSEEVENTF_LEFTDOWN);

      print('[MOUSE] Waiting 50ms between down and up...');
      await Future.delayed(const Duration(milliseconds: 50));

      print('[MOUSE] Sending left mouse up event...');
      _sendMouseEvent(MOUSEEVENTF_LEFTUP);

      print('[MOUSE] Left click completed successfully');
    } catch (e) {
      print('[MOUSE] ERROR performing left click: $e');
      print('[MOUSE] Stack trace: ${StackTrace.current}');
    }
  }

  /// Performs a right mouse button click
  Future<void> rightClick() async {
    print('[MOUSE] rightClick called');

    if (!Platform.isWindows) {
      print('[MOUSE] ERROR: Mouse control is only supported on Windows');
      return;
    }

    try {
      print('[MOUSE] Sending right mouse down event...');
      // Send right mouse down and up events
      _sendMouseEvent(MOUSEEVENTF_RIGHTDOWN);

      print('[MOUSE] Waiting 50ms between down and up...');
      await Future.delayed(const Duration(milliseconds: 50));

      print('[MOUSE] Sending right mouse up event...');
      _sendMouseEvent(MOUSEEVENTF_RIGHTUP);

      print('[MOUSE] Right click completed successfully');
    } catch (e) {
      print('[MOUSE] ERROR performing right click: $e');
      print('[MOUSE] Stack trace: ${StackTrace.current}');
    }
  }

  /// Scrolls the mouse wheel
  Future<void> scroll(double deltaY) async {
    print('[MOUSE] scroll called - deltaY: $deltaY');

    if (!Platform.isWindows) {
      print('[MOUSE] ERROR: Mouse control is only supported on Windows');
      return;
    }

    try {
      // Convert delta to wheel units (negative for natural scrolling)
      final wheelDelta = (-deltaY * 120).round();
      print('[MOUSE] Converting deltaY $deltaY to wheelDelta $wheelDelta');

      _sendMouseEvent(MOUSEEVENTF_WHEEL, wheelData: wheelDelta);
      print('[MOUSE] Scroll completed successfully');
    } catch (e) {
      print('[MOUSE] ERROR scrolling: $e');
      print('[MOUSE] Stack trace: ${StackTrace.current}');
    }
  }

  /// Helper method to send mouse events using SendInput API
  void _sendMouseEvent(int eventType, {int wheelData = 0}) {
    print(
        '[MOUSE] _sendMouseEvent called - eventType: $eventType, wheelData: $wheelData');

    try {
      final input = calloc<INPUT>();
      input.ref.type = INPUT_MOUSE;
      input.ref.mi.dwFlags = eventType;
      input.ref.mi.mouseData = wheelData;
      input.ref.mi.dwExtraInfo = 0;
      input.ref.mi.time = 0;
      input.ref.mi.dx = 0;
      input.ref.mi.dy = 0;

      print('[MOUSE] Sending input event...');
      final result = SendInput(1, input, sizeOf<INPUT>());
      print('[MOUSE] SendInput result: $result');

      calloc.free(input);
      print('[MOUSE] _sendMouseEvent completed');
    } catch (e) {
      print('[MOUSE] ERROR in _sendMouseEvent: $e');
      print('[MOUSE] Stack trace: ${StackTrace.current}');
    }
  }
}
