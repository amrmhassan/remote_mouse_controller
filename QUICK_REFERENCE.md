# Remote Mouse Controller - Quick Reference Card

## 🚀 Quick Start Commands

### PC Server
```bash
cd e:\Flutter\test\remote_mouse_controller\pc_server
dart run bin/main.dart                    # Start server on port 8080
dart run bin/main.dart --port 9090        # Start on custom port
dart run bin/main.dart --help             # Show help
```

### Mobile Client
```bash
cd e:\Flutter\test\remote_mouse_controller\mobile_client
flutter run                               # Run on default device
flutter run -d chrome                     # Run in Chrome (web)
flutter devices                           # List available devices
```

## 📁 Key Files & Their Purpose

| File | Purpose |
|------|---------|
| `pc_server/bin/main.dart` | Server entry point, WebSocket setup |
| `pc_server/lib/src/mouse_controller.dart` | Windows mouse control (Win32 API) |
| `pc_server/lib/src/network_discovery.dart` | Server discovery (UDP + mDNS) |
| `mobile_client/lib/main.dart` | Mobile app entry point |
| `mobile_client/lib/screens/connection_screen.dart` | Server discovery UI |
| `mobile_client/lib/screens/touchpad_screen.dart` | Touch control interface |
| `mobile_client/lib/services/websocket_service.dart` | WebSocket client |
| `mobile_client/lib/services/network_discovery_service.dart` | Client discovery |

## 🔌 Network Protocol

### WebSocket Messages (JSON)
```json
// Mouse movement
{"type": "move", "deltaX": 10.5, "deltaY": -5.2, "timestamp": 1703123456789}

// Left click
{"type": "click", "timestamp": 1703123456789}

// Right click  
{"type": "rightClick", "timestamp": 1703123456789}

// Scroll
{"type": "scroll", "deltaY": -120, "timestamp": 1703123456789}
```

### UDP Discovery Broadcast
```json
{
  "service": "remote_mouse_server",
  "ip": "192.168.1.100", 
  "port": 8080,
  "name": "MyComputer",
  "timestamp": 1703123456789
}
```

## 🔧 Development Commands

### Code Quality
```bash
# Analysis
dart analyze                              # PC server
flutter analyze                           # Mobile client

# Formatting
dart format .                             # PC server
dart format .                             # Mobile client

# Dependencies
dart pub get                              # PC server
flutter pub get                           # Mobile client
dart pub outdated                         # Check updates
flutter pub outdated                      # Check updates
```

### Testing
```bash
dart test                                 # PC server tests
flutter test                              # Mobile client tests
flutter test integration_test/            # Integration tests
```

### Building
```bash
# Server executable
dart compile exe bin/main.dart -o remote_mouse_server.exe

# Mobile apps
flutter build apk --release              # Android APK
flutter build ios --release              # iOS app
```

## 🐛 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Port 8080 in use | Use `--port 9090` or stop conflicting service |
| mDNS error on Windows | ✅ Already fixed - uses UDP broadcast |
| Mobile app can't find server | Check firewall, try manual IP entry |
| Mouse movement too sensitive | Modify sensitivity in `touchpad_screen.dart` line 36 |
| Connection drops | Check WiFi stability, restart both apps |

## 📱 Testing Checklist

- [ ] Server starts without errors
- [ ] Mobile app finds server automatically  
- [ ] Manual connection works
- [ ] Mouse movement is smooth
- [ ] Left/right click work
- [ ] Scrolling works
- [ ] Reconnection works
- [ ] Server shutdown is graceful

## 🔥 Critical Code Locations

### Mouse Control Sensitivity
```dart
// File: mobile_client/lib/screens/touchpad_screen.dart
// Line: ~36
const sensitivity = 2.0;  // Adjust this value
```

### Network Ports
```dart
// PC Server default port
final port = int.tryParse(args['port']) ?? 8080;

// UDP discovery port (both client & server)
static const int _broadcastPort = 41234;
```

### WebSocket Connection Timeout
```dart
// File: mobile_client/lib/services/websocket_service.dart
// Add timeout handling in connect() method
```

## 📦 Key Dependencies

### PC Server
- `shelf` + `shelf_web_socket`: WebSocket server
- `win32` + `ffi`: Windows mouse control
- `multicast_dns`: Network discovery
- `args`: Command line parsing

### Mobile Client  
- `web_socket_channel`: WebSocket client
- `network_info_plus`: Network information
- `permission_handler`: Device permissions

## 🎯 Next Development Priorities

1. **Add authentication/security**
2. **Implement sensitivity settings**
3. **Add keyboard support**
4. **Create proper unit tests**
5. **Add connection history**

---
**Status**: ✅ Functional | **Last Updated**: June 13, 2025
