# Remote Mouse Controller

A cross-platform remote mouse control solution consisting of a Dart PC server and Flutter mobile client.

## Project Structure

```
remote_mouse_controller/
├── pc_server/          # Dart server application
└── mobile_client/      # Flutter mobile application
```

## PC Server Setup

### Prerequisites
- Dart SDK 3.0 or higher
- Windows OS (for mouse control functionality)

### Installation & Running

1. Navigate to the server directory:
   ```bash
   cd pc_server
   ```

2. Install dependencies:
   ```bash
   dart pub get
   ```

3. Run the server:
   ```bash
   dart run bin/main.dart
   ```

   Optional: Specify a custom port:
   ```bash
   dart run bin/main.dart --port 9090
   ```

### Features
- WebSocket server for real-time communication
- Network discovery via UDP broadcast
- Windows mouse control using Win32 API
- Support for mouse movement, clicking, and scrolling
- CLI interface with graceful shutdown

## Mobile Client Setup

### Prerequisites
- Flutter SDK 3.8.1 or higher
- Android/iOS development environment

### Installation & Running

1. Navigate to the client directory:
   ```bash
   cd mobile_client
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Features
- Automatic server discovery on local network
- Manual server connection option
- Fullscreen touchpad interface
- Gesture support:
  - Drag to move mouse cursor
  - Tap for left click
  - Long press for right click
  - Right edge scrolling
- Connection status indicators
- Haptic feedback

## Usage

1. **Start the PC Server**: Run the Dart server on your Windows PC
2. **Connect Mobile Device**: 
   - Ensure both devices are on the same WiFi network
   - Open the Flutter app
   - Either select a discovered server or enter IP manually
   - Tap "Connect"
3. **Control Mouse**: Use the fullscreen touchpad to control your PC's mouse
4. **Access Controls**: Double-tap the top edge to show/hide controls

## Network Requirements

- Both devices must be on the same local network
- Default server port: 8080 (WebSocket)
- Discovery broadcast port: 41234 (UDP)
- Ensure firewall allows connections on these ports

## Troubleshooting

### Server Issues
- Ensure Windows allows the application through the firewall
- Check that the port is not already in use
- Verify network connectivity

### Mobile App Issues
- Check WiFi connection
- Manually enter server IP if auto-discovery fails
- Restart both server and app if connection issues persist

## Development Notes

- Server uses `win32` package for mouse control (Windows only)
- Mobile app uses `web_socket_channel` for real-time communication
- Network discovery uses UDP broadcasting as fallback to mDNS
- Touch sensitivity can be adjusted in the touchpad screen code

## License

This project is for educational and personal use.
