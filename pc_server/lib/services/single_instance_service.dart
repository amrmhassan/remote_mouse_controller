import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/debug_logger.dart';

/// Service to ensure only one instance of the application runs at a time
class SingleInstanceService {
  static const String _lockFileName = 'touchpad_pro_server.lock';
  static File? _lockFile;
  static RandomAccessFile? _lockFileHandle;

  /// Check if another instance is already running and handle accordingly
  static Future<bool> ensureSingleInstance(BuildContext? context) async {
    try {
      DebugLogger.log('Checking for existing instance...',
          tag: 'SINGLE_INSTANCE');

      // Get temp directory for lock file
      final tempDir = await getTemporaryDirectory();
      _lockFile = File('${tempDir.path}/$_lockFileName');

      DebugLogger.log('Lock file path: ${_lockFile!.path}',
          tag: 'SINGLE_INSTANCE');

      // Try to open the lock file exclusively
      try {
        _lockFileHandle = await _lockFile!.open(mode: FileMode.write);
        await _lockFileHandle!.lock(FileLock.exclusive);

        // Write process ID to lock file
        final processId = pid.toString();
        await _lockFileHandle!.writeString(processId);
        await _lockFileHandle!.flush();

        DebugLogger.log('Successfully acquired lock with PID: $processId',
            tag: 'SINGLE_INSTANCE');
        return true; // We are the first instance
      } catch (e) {
        DebugLogger.warning(
            'Failed to acquire lock, another instance is running',
            tag: 'SINGLE_INSTANCE');

        // Another instance is running, show dialog if context is available
        if (context != null) {
          _showAlreadyRunningDialog(context);
        }
        return false; // Another instance is running
      }
    } catch (e) {
      DebugLogger.error('Error in single instance check',
          tag: 'SINGLE_INSTANCE', error: e);
      return true; // If we can't check, allow this instance to run
    }
  }

  /// Show dialog when another instance is already running
  static void _showAlreadyRunningDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Already Running'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TouchPad Pro Server is already running.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Only one instance can run at a time. Please check your system tray or taskbar for the existing application.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Exit the application
                exit(0);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Release the lock when the application is closing
  static Future<void> releaseLock() async {
    try {
      DebugLogger.log('Releasing single instance lock...',
          tag: 'SINGLE_INSTANCE');

      if (_lockFileHandle != null) {
        await _lockFileHandle!.unlock();
        await _lockFileHandle!.close();
        _lockFileHandle = null;
      }

      if (_lockFile != null && await _lockFile!.exists()) {
        await _lockFile!.delete();
        DebugLogger.log('Lock file deleted successfully',
            tag: 'SINGLE_INSTANCE');
      }
    } catch (e) {
      DebugLogger.error('Error releasing lock',
          tag: 'SINGLE_INSTANCE', error: e);
    }
  }
}
