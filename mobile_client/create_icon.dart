import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Simple utility to create a basic PNG icon for the app
void main() async {
  // Create a simple icon programmatically
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(1024, 1024);

  // Background gradient
  final backgroundPaint = Paint()
    ..shader = LinearGradient(
      colors: [Color(0xFF673AB7), Color(0xFF9C27B0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

  // Draw background with rounded corners
  final backgroundRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Radius.circular(160),
  );
  canvas.drawRRect(backgroundRect, backgroundPaint);

  // Draw touchpad device
  final touchpadPaint = Paint()..color = Colors.white.withOpacity(0.95);
  final touchpadRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(192, 256, 640, 512),
    Radius.circular(48),
  );
  canvas.drawRRect(touchpadRect, touchpadPaint);

  // Draw trackpad surface
  final trackpadPaint = Paint()
    ..color = Color(0xFFFAFAFA)
    ..style = PaintingStyle.fill;
  final trackpadRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(224, 288, 576, 320),
    Radius.circular(32),
  );
  canvas.drawRRect(trackpadRect, trackpadPaint);

  // Draw border
  final borderPaint = Paint()
    ..color = Color(0xFFBDBDBD)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;
  canvas.drawRRect(trackpadRect, borderPaint);

  // Draw touch indicator
  final touchPaint = Paint()..color = Color(0xFF673AB7);
  canvas.drawCircle(Offset(512, 448), 32, touchPaint);

  final innerTouchPaint = Paint()..color = Color(0xFF9C27B0);
  canvas.drawCircle(Offset(512, 448), 16, innerTouchPaint);

  // Draw connection indicator
  final connectionPaint = Paint()..color = Color(0xFF4CAF50);
  canvas.drawCircle(Offset(768, 320), 24, connectionPaint);

  final picture = recorder.endRecording();
  final img = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

  if (byteData != null) {
    final file = File('assets/icons/app_icon.png');
    await file.create(recursive: true);
    await file.writeAsBytes(byteData.buffer.asUint8List());
    print('Icon created successfully at: ${file.path}');
  }
}
