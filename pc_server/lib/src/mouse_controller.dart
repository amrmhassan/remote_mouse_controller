import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Handles mouse control operations on Windows using Win32 API
class MouseController {
  /// Moves the mouse cursor by the specified delta values
  Future<void> moveMouse(double deltaX, double deltaY) async {
    if (!Platform.isWindows) {
      print('Mouse control is only supported on Windows');
      return;
    }

    try {
      // Get current cursor position
      final point = calloc<POINT>();
      GetCursorPos(point);

      final currentX = point.ref.x;
      final currentY = point.ref.y;

      // Calculate new position
      final newX = currentX + deltaX.round();
      final newY = currentY + deltaY.round();

      // Set new cursor position
      SetCursorPos(newX, newY);

      calloc.free(point);
    } catch (e) {
      print('Error moving mouse: $e');
    }
  }

  /// Performs a left mouse button click
  Future<void> leftClick() async {
    if (!Platform.isWindows) {
      print('Mouse control is only supported on Windows');
      return;
    }

    try {
      // Send mouse down and up events using SendInput
      _sendMouseEvent(MOUSEEVENTF_LEFTDOWN);
      await Future.delayed(const Duration(milliseconds: 50));
      _sendMouseEvent(MOUSEEVENTF_LEFTUP);
    } catch (e) {
      print('Error performing left click: $e');
    }
  }

  /// Performs a right mouse button click
  Future<void> rightClick() async {
    if (!Platform.isWindows) {
      print('Mouse control is only supported on Windows');
      return;
    }

    try {
      // Send right mouse down and up events
      _sendMouseEvent(MOUSEEVENTF_RIGHTDOWN);
      await Future.delayed(const Duration(milliseconds: 50));
      _sendMouseEvent(MOUSEEVENTF_RIGHTUP);
    } catch (e) {
      print('Error performing right click: $e');
    }
  }

  /// Scrolls the mouse wheel
  Future<void> scroll(double deltaY) async {
    if (!Platform.isWindows) {
      print('Mouse control is only supported on Windows');
      return;
    }

    try {
      // Convert delta to wheel units (negative for natural scrolling)
      final wheelDelta = (-deltaY * 120).round();
      _sendMouseEvent(MOUSEEVENTF_WHEEL, wheelData: wheelDelta);
    } catch (e) {
      print('Error scrolling: $e');
    }
  }

  /// Helper method to send mouse events using SendInput API
  void _sendMouseEvent(int eventType, {int wheelData = 0}) {
    final input = calloc<INPUT>();
    input.ref.type = INPUT_MOUSE;
    input.ref.mi.dwFlags = eventType;
    input.ref.mi.mouseData = wheelData;
    input.ref.mi.dwExtraInfo = 0;
    input.ref.mi.time = 0;
    input.ref.mi.dx = 0;
    input.ref.mi.dy = 0;

    SendInput(1, input, sizeOf<INPUT>());
    calloc.free(input);
  }
}
