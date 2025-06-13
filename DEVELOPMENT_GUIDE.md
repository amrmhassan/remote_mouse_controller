# Remote Mouse Controller - Development Documentation

## 📋 Project Overview

A cross-platform remote mouse control solution consisting of:
- **PC Server**: Dart application that runs on Windows and controls the mouse
- **Mobile Client**: Flutter application that captures touch gestures and sends commands

## 🏗️ Project Structure

```
e:\Flutter\test\remote_mouse_controller\
├── pc_server/                 # Dart server application
│   ├── bin/
│   │   └── main.dart         # Server entry point
│   ├── lib/src/
│   │   ├── mouse_controller.dart      # Windows mouse control via Win32 API
│   │   └── network_discovery.dart    # Network discovery (UDP broadcast + mDNS)
│   └── pubspec.yaml          # Server dependencies
│
├── mobile_client/            # Flutter mobile application  
│   ├── lib/
│   │   ├── main.dart         # App entry point
│   │   ├── screens/
│   │   │   ├── connection_screen.dart # Server discovery and connection UI
│   │   │   └── touchpad_screen.dart   # Fullscreen touch control interface
│   │   └── services/
│   │       ├── websocket_service.dart     # WebSocket communication service
│   │       └── network_discovery_service.dart # Client-side server discovery
│   └── pubspec.yaml          # Client dependencies
│
├── README.md                 # User setup and usage guide
├── PROJECT_SUMMARY.md        # Implementation details and features
├── ISSUE_RESOLUTION.md       # Windows mDNS compatibility fixes
└── DEVELOPMENT_GUIDE.md      # This file - development continuation guide
```

## 🚀 Getting Started for Development

### Prerequisites

#### For PC Server Development
```bash
# Required
- Dart SDK 3.0 or higher
- Windows OS (for mouse control functionality)
- Git (for version control)

# Recommended
- VS Code with Dart extension
- Windows Firewall exceptions for ports 8080 (WebSocket) and 41234 (UDP)
```

#### For Mobile Client Development
```bash
# Required
- Flutter SDK 3.8.1 or higher
- Android Studio or Xcode (for device deployment)
- Android/iOS development setup

# Recommended
- VS Code with Flutter extension
- Physical device or emulator for testing
```

### Development Setup

1. **Clone/Access Project**
   ```bash
   cd e:\Flutter\test\remote_mouse_controller
   ```

2. **PC Server Setup**
   ```bash
   cd pc_server
   dart pub get
   dart analyze    # Check for issues
   ```

3. **Mobile Client Setup**
   ```bash
   cd mobile_client
   flutter pub get
   flutter analyze # Check for issues
   ```

## 🔧 Development Workflow

### Running in Development Mode

#### PC Server
```bash
cd pc_server

# Standard run
dart run bin/main.dart

# Custom port
dart run bin/main.dart --port 9090

# Debug mode with verbose output
dart run bin/main.dart --port 8080 --verbose
```

#### Mobile Client
```bash
cd mobile_client

# Run on connected device/emulator
flutter run

# Run in debug mode
flutter run --debug

# Run on specific device
flutter devices          # List available devices
flutter run -d <device_id>
```

### Code Analysis & Quality

```bash
# PC Server
cd pc_server
dart analyze
dart format --set-exit-if-changed .

# Mobile Client  
cd mobile_client
flutter analyze
dart format --set-exit-if-changed .
```

## 📦 Dependencies Management

### PC Server Dependencies
```yaml
# Current dependencies in pubspec.yaml
dependencies:
  shelf: ^1.4.1              # HTTP server framework
  shelf_web_socket: ^1.0.4   # WebSocket support
  multicast_dns: ^0.3.2      # Network discovery (mDNS)
  win32: ^5.2.0              # Windows API access
  ffi: ^2.1.0                # Foreign Function Interface
  args: ^2.4.2               # Command line argument parsing

dev_dependencies:
  lints: ^3.0.0              # Dart linting rules
```

### Mobile Client Dependencies
```yaml
# Current dependencies in pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  web_socket_channel: ^2.4.0      # WebSocket client
  multicast_dns: ^0.3.2           # Network discovery
  network_info_plus: ^5.0.0       # Network information
  permission_handler: ^11.3.0     # Device permissions

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0           # Flutter linting rules
```

### Updating Dependencies
```bash
# Check for outdated packages
dart pub outdated              # For PC server
flutter pub outdated           # For mobile client

# Update dependencies
dart pub upgrade               # For PC server
flutter pub upgrade            # For mobile client
```

## 🔌 Communication Protocol

### WebSocket Message Format
```json
{
  "type": "move|click|rightClick|scroll",
  "deltaX": 10.5,           // For move operations
  "deltaY": -5.2,           // For move/scroll operations
  "timestamp": 1703123456789
}
```

### Network Discovery Protocol (UDP Broadcast)
```json
{
  "service": "remote_mouse_server",
  "ip": "192.168.1.100",
  "port": 8080,
  "name": "MyComputer",
  "timestamp": 1703123456789
}
```

### Network Ports
- **8080**: WebSocket server (configurable)
- **41234**: UDP broadcast for server discovery

## 🧪 Testing Strategy

### Unit Testing
```bash
# PC Server
cd pc_server
dart test

# Mobile Client
cd mobile_client
flutter test
```

### Integration Testing
```bash
# Mobile Client UI tests
cd mobile_client
flutter test integration_test/
```

### Manual Testing Checklist
- [ ] PC server starts without errors
- [ ] Mobile app discovers server automatically
- [ ] Manual IP connection works as fallback
- [ ] Mouse movement is smooth and responsive
- [ ] Left click works correctly
- [ ] Right click works correctly
- [ ] Scrolling works in both directions
- [ ] Connection status updates properly
- [ ] Disconnect and reconnect works
- [ ] Server handles client disconnection gracefully

## 🐛 Known Issues & Workarounds

### Windows mDNS Compatibility ✅ RESOLVED
- **Issue**: `reusePort` not supported on Windows
- **Solution**: Platform-specific discovery using UDP broadcast on Windows
- **Code**: `network_discovery.dart` lines 33-52

### Potential Future Issues
1. **Firewall Blocking**: Windows Firewall may block connections
   - **Solution**: Add firewall exceptions for ports 8080 and 41234

2. **Network Discovery Fails**: UDP broadcast may not work on some networks
   - **Solution**: Manual IP entry is always available as fallback

3. **Mouse Control Precision**: Different DPI screens may need sensitivity adjustment
   - **Future Enhancement**: Add sensitivity settings in mobile app

## 🚀 Feature Development Roadmap

### Priority 1 (Core Stability)
- [ ] Add sensitivity settings to mobile app
- [ ] Implement connection timeout handling
- [ ] Add server authentication for security
- [ ] Create proper unit tests for all components

### Priority 2 (User Experience)
- [ ] Add keyboard support (virtual keyboard)
- [ ] Multi-finger gesture support (pinch to zoom)
- [ ] Haptic feedback improvements
- [ ] Dark/light theme support
- [ ] Connection history and favorites

### Priority 3 (Advanced Features)
- [ ] Multi-monitor support
- [ ] File transfer capability
- [ ] Screen mirroring/viewing
- [ ] Multiple client support
- [ ] Cross-platform server (macOS, Linux)

## 🔧 Development Tools & Scripts

### Useful Commands
```bash
# Build server executable
cd pc_server
dart compile exe bin/main.dart -o remote_mouse_server.exe

# Build mobile app for release
cd mobile_client
flutter build apk --release      # Android
flutter build ios --release      # iOS

# Generate app icons
flutter pub run flutter_launcher_icons:main

# Analyze dependencies
flutter pub deps
```

### VS Code Configuration
Create `.vscode/launch.json` for debugging:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "PC Server",
      "type": "dart",
      "request": "launch",
      "program": "pc_server/bin/main.dart",
      "args": ["--port", "8080"]
    },
    {
      "name": "Mobile Client",
      "type": "dart",
      "request": "launch",
      "program": "mobile_client/lib/main.dart"
    }
  ]
}
```

## 📝 Code Style Guidelines

### Dart/Flutter Style
- Follow [official Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `dart format` for consistent formatting
- Maximum line length: 80 characters
- Use meaningful variable and function names
- Add documentation comments for public APIs

### File Organization
- Keep files under 300 lines when possible
- Separate concerns into different files/classes
- Use consistent import ordering (dart: packages, package: imports, relative imports)
- Group related functionality into folders

## 🔒 Security Considerations

### Current Security Level: Development Only
- **No Authentication**: Anyone on network can connect
- **No Encryption**: All communication is plain text
- **No Access Control**: Full mouse control once connected

### Security Enhancements for Production
- [ ] Add token-based authentication
- [ ] Implement TLS/SSL for WebSocket connections
- [ ] Add user consent prompts for mouse control
- [ ] Implement session timeouts
- [ ] Add connection whitelisting

## 📚 Learning Resources

### Technologies Used
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Flutter Documentation](https://docs.flutter.dev/)
- [Shelf Package](https://pub.dev/packages/shelf)
- [Win32 Package](https://pub.dev/packages/win32)
- [WebSocket Protocol](https://tools.ietf.org/html/rfc6455)

### Architecture Patterns
- [Clean Architecture in Flutter](https://resocoder.com/2019/08/27/flutter-tdd-clean-architecture-course-1-explanation-project-structure/)
- [Dart Isolates](https://dart.dev/guides/language/concurrency)
- [WebSocket Best Practices](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers)

## 🤝 Contributing Guidelines

### Branch Strategy
```bash
main/master     # Stable, production-ready code
develop         # Integration branch for features
feature/*       # Individual feature development
bugfix/*        # Bug fixes
hotfix/*        # Critical production fixes
```

### Commit Message Format
```
type(scope): brief description

Detailed explanation of changes

Closes #issue_number
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### Pull Request Process
1. Create feature branch from `develop`
2. Implement changes with tests
3. Run code analysis and formatting
4. Update documentation if needed
5. Create PR with clear description
6. Ensure all checks pass

## 📞 Troubleshooting & Support

### Common Development Issues

1. **Port Already in Use**
   ```
   Error: Port 8080 is already in use
   Solution: dart run bin/main.dart --port 9090
   ```

2. **Flutter Device Not Found**
   ```
   flutter doctor        # Check setup
   flutter devices       # List available devices
   ```

3. **Build Errors on Mobile**
   ```
   flutter clean
   flutter pub get
   flutter run
   ```

### Debug Information
- Server logs: Console output from `dart run bin/main.dart`
- Mobile logs: Use VS Code Flutter Inspector or `flutter logs`
- Network traffic: Use Wireshark to monitor UDP/WebSocket traffic

---

**Last Updated**: June 13, 2025  
**Current Status**: ✅ Functional - Ready for feature development  
**Next Review**: Add after major feature additions
