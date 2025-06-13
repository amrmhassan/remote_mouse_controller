# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Settings Management System** - Complete settings management with persistent storage
  - Mouse sensitivity adjustment (0.1x to 5.0x multiplier)
  - Scroll sensitivity adjustment (0.1x to 5.0x multiplier) 
  - Reverse scroll direction toggle
  - Settings persist across app restarts using SharedPreferences
  - Live settings updates during active connections
  - Modern dark-themed settings screen with intuitive UI
  
- **Connection Control Features**
  - Force disconnect capability from mobile client
  - Clean connection termination handling on PC server
  - Proper WebSocket connection lifecycle management

- **Enhanced User Experience**
  - Settings button in touchpad controls for quick access
  - Loading screen during app initialization
  - Real-time settings preview in settings screen
  - Helpful tips and usage instructions
  - Reset to defaults functionality

### Technical Improvements
- Robust Git workflow with feature branching strategy
- Comprehensive settings service architecture
- Proper state management for real-time updates
- Enhanced error handling and connection management

### Documentation
- Added comprehensive Git workflow documentation
- Detailed commit message conventions
- Branch strategy and collaboration guidelines

## [0.1.0] - Initial Release

### Added
- Basic remote mouse functionality
- Network discovery for PC detection
- WebSocket communication between mobile and PC
- Touchpad input handling
- Cross-platform compatibility (Windows PC, Android/iOS mobile)
