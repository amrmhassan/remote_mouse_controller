# TouchPad Pro

A professional wireless touchpad solution with a beautiful Windows GUI server and modern Flutter mobile client.

## 🌟 Features

### Windows Server App (TouchPad Pro Server)
- **Beautiful Modern UI**: Flutter-powered Windows desktop application
- **System Tray Integration**: Minimize to tray and run in background
- **Device Trust Management**: Remember trusted devices, ask permission for new ones
- **Real-time Device Monitoring**: See connected devices, connection status, and activity
- **Auto-startup**: Launch automatically with Windows (optional)
- **Comprehensive Settings**: Server port, security, UI preferences
- **Activity Logs**: Real-time server logs and device activity tracking
- **Connection Security**: Trust-based permission system for enhanced security

### Mobile Client (TouchPad Pro)
- **Professional Interface**: Clean, modern UI with enhanced usability
- **High-precision Touchpad**: Professional-grade mouse control
- **Gesture Support**: Multi-touch gestures for natural interaction
- **Auto-discovery**: Automatically finds servers on your network
- **Connection Memory**: Remembers previous connections
- **Haptic Feedback**: Enhanced tactile response

## 📁 Project Structure

```
remote_mouse_controller/
├── pc_server/          # Flutter Windows desktop application
│   ├── lib/
│   │   ├── screens/    # UI screens (main, settings, devices)
│   │   ├── services/   # Core services (server, settings, trust)
│   │   └── src/        # Core functionality (mouse, network)
│   ├── assets/         # App icons and resources
│   └── windows/        # Windows-specific build files
└── mobile_client/      # Flutter mobile application
    ├── lib/            # App source code
    ├── assets/         # Icons and resources
    └── android/        # Android-specific files
```

## 🖥️ Windows Server Setup

### Prerequisites
- Windows 10/11
- Flutter SDK 3.0 or higher (for development)
- Visual Studio with "Desktop development with C++" workload (for building)

### Installation Options

#### Option 1: Download Release (Recommended)
1. Download the latest release from GitHub Releases
2. Extract and run `TouchPad Pro Server.exe`
3. Allow through Windows Firewall when prompted

#### Option 2: Build from Source
1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd remote_mouse_controller/pc_server
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Build the Windows app:
   ```bash
   flutter build windows --release
   ```

4. Run the executable:
   ```bash
   build\windows\x64\runner\Release\TouchPad Pro Server.exe
   ```

### First-time Setup
1. **Launch the app** - It will start in windowed mode
2. **Configure settings** - Click the settings icon to:
   - Set server port (default: 8080)
   - Enable auto-startup with Windows
   - Configure security preferences
   - Set system tray behavior
3. **Start the server** - Click the "Start Server" button
4. **Allow firewall access** - Windows will prompt for network access

## 📱 Mobile Client Setup

### Prerequisites
- Android 6.0+ or iOS 12.0+
- Flutter SDK 3.8.1+ (for development)

### Installation Options

#### Option 1: Download APK (Android)
1. Download the latest APK from GitHub Releases
2. Enable "Install from unknown sources" if needed
3. Install the APK

#### Option 2: Build from Source
1. Navigate to mobile client:
   ```bash
   cd mobile_client
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Build and run:
   ```bash
   flutter run  # For development
   flutter build apk --release  # For production APK
   ```

## 🚀 Usage Guide

### Setting Up Connection

1. **Start Windows Server**:
   - Launch TouchPad Pro Server on your Windows PC
   - Click "Start Server" or enable auto-start
   - Note the server IP address shown in the app

2. **Connect Mobile Device**:
   - Ensure both devices are on the same WiFi network
   - Open TouchPad Pro on your mobile device
   - The app will automatically discover nearby servers
   - Tap "Connect" on your server, or enter IP manually

3. **Device Trust (First Time)**:
   - Windows server will show a permission dialog
   - Choose "Allow" and check "Remember this device"
   - Future connections will be automatic

### Using the Touchpad

- **Move Cursor**: Drag finger across the touchpad area
- **Left Click**: Single tap
- **Right Click**: Long press (hold for 0.5 seconds)
- **Scroll**: Use two-finger scroll or right-edge scrolling
- **Controls**: Double-tap top edge to show/hide controls

### Windows Server Features

- **Dashboard**: View server status, connected devices, recent activity
- **Devices Tab**: Manage connected, pending, and trusted devices
- **Logs Tab**: View real-time server activity and debug information
- **Settings**: Configure all aspects of the server
- **System Tray**: Right-click tray icon for quick actions

## ⚙️ Configuration

### Windows Server Settings

**Server Settings**:
- Port: Change server port (default: 8080)
- Auto-start: Launch with Windows
- Require Permission: Ask before allowing new devices

**Security Settings**:
- Device trust management
- Connection permission requirements
- Trusted device list management

**UI Settings**:
- Minimize to tray behavior
- Start minimized option
- Show notifications

### Mobile Client Settings

Access settings through the app menu:
- Connection preferences
- Touchpad sensitivity
- Haptic feedback intensity
- Display preferences

## 🔧 Troubleshooting

### Windows Server Issues

**Server won't start**:
- Check if port is already in use
- Try changing the port in settings
- Ensure Windows Firewall allows the app

**Devices can't connect**:
- Verify both devices are on same WiFi network
- Check Windows Firewall settings
- Try manual IP connection on mobile device

**App crashes or errors**:
- Check logs in the Logs tab
- Try running as Administrator
- Restart the application

### Mobile Client Issues

**Can't find server**:
- Ensure server is running and started
- Check WiFi connection on mobile device
- Try manual IP entry
- Verify both devices on same network

**Connection drops**:
- Check WiFi stability
- Verify server is still running
- Restart both applications

**Poor touchpad responsiveness**:
- Adjust sensitivity in mobile app settings
- Check for interference or network lag
- Ensure good WiFi signal strength

## 🛠️ Development

### Building and Testing

1. **Setup development environment**:
   ```bash
   flutter doctor  # Verify Flutter installation
   ```

2. **Run in development mode**:
   ```bash
   # Windows server
   cd pc_server && flutter run -d windows
   
   # Mobile client
   cd mobile_client && flutter run
   ```

3. **Run tests**:
   ```bash
   flutter test
   ```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📋 System Requirements

### Windows Server
- **OS**: Windows 10/11 (64-bit)
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 100MB for installation
- **Network**: WiFi or Ethernet connection

### Mobile Client
- **Android**: 6.0+ (API level 23+)
- **iOS**: 12.0+
- **Storage**: 50MB for installation
- **Network**: WiFi connection

## 🔒 Privacy & Security

- All communication is local network only
- No data sent to external servers
- Device trust system for secure connections
- Firewall-friendly with configurable ports
- Open-source for full transparency

## 📝 License

This project is for educational and personal use. See LICENSE file for details.

## 🆘 Support

For issues, questions, or contributions:
- Create an issue on GitHub
- Check existing documentation
- Review troubleshooting guide above

---

**TouchPad Pro** - Transform your mobile device into a professional wireless touchpad! ✨
