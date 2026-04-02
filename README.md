# SwipeControl

<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="SwipeControl icon">
</p>

A minimal macOS menu bar app that detects hand gestures via your webcam and maps them to system actions. Built with Swift, Vision framework, and pure AppKit.

## Gestures

| Gesture | How | Action |
|---------|-----|--------|
| ✌️ Peace (left hand) | Hold up index + middle finger with left hand | Switch to previous desktop space |
| ✌️ Peace (right hand) | Hold up index + middle finger with right hand | Switch to next desktop space |
| 👉 Finger gun | Thumb + index extended, others curled | Spotify play/pause |

Gestures require ~0.7 seconds of stable hold to trigger (5 consecutive frames). This prevents accidental activation from casual hand movements.

## Requirements

- macOS 15.0 (Sequoia) or later
- Camera (built-in or external USB webcam)
- Swift 6.1+ (for building from source)

## Installation

### Build from source

```bash
git clone https://github.com/JoshTickles/SwipeControl.git
cd SwipeControl
swift build -c release
```

### Create app bundle

```bash
APP="/Applications/SwipeControl.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/SwipeControl "$APP/Contents/MacOS/SwipeControl"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
```

Create `$APP/Contents/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>SwipeControl</string>
    <key>CFBundleIdentifier</key><string>com.josh.swipecontrol</string>
    <key>CFBundleVersion</key><string>1.0.0</string>
    <key>CFBundleExecutable</key><string>SwipeControl</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>NSCameraUsageDescription</key><string>SwipeControl uses the camera to detect hand gestures.</string>
    <key>NSAppleEventsUsageDescription</key><string>SwipeControl needs automation access for Spotify control.</string>
</dict>
</plist>
```

Then sign and launch:
```bash
codesign --force --deep --sign - "$APP"
open "$APP"
```

### Permissions

On first launch, grant:

1. **Camera** — System Settings → Privacy & Security → Camera → SwipeControl
2. **Accessibility** — System Settings → Privacy & Security → Accessibility → add SwipeControl (required for desktop switching via CGEvent)
3. **Automation** — prompted automatically when finger gun first fires for Spotify

> **Note:** Re-signing the app invalidates Accessibility permission. Re-add SwipeControl after each `codesign`.

## Settings

Accessible from the menu bar popover (click the hand icon).

| Setting | Default | Description |
|---------|---------|-------------|
| Response delay | 1.0s | Cooldown between gesture triggers |
| Launch at login | Off | Start SwipeControl automatically |

Settings can also be adjusted via CLI:

```bash
defaults write com.josh.swipecontrol cooldown -float 1.0
defaults read com.josh.swipecontrol
```

## Camera Support

- Prefers external cameras (e.g. Logitech C920) when connected
- Falls back to built-in FaceTime camera
- Works in clamshell mode
- Handles fixed-rate USB cameras that don't support arbitrary frame durations

## How It Works

- **Hand detection**: Apple Vision framework `VNDetectHumanHandPoseRequest` with chirality (left/right hand identification)
- **Pose detection**: Finger landmark positions (tip vs PIP joint) determine which fingers are extended
- **Desktop switching**: CGEvent key posting with Control + Arrow keys. Requires `.maskSecondaryFn` flag for macOS to recognize arrow keys as space-switching commands
- **Spotify control**: In-process `NSAppleScript` telling Spotify to playpause

## Architecture

```
Sources/SwipeControl/
  main.swift                 — NSApplication entry, .accessory policy (no dock icon)
  CameraManager.swift        — AVCaptureSession, external camera preference, frame rate handling
  SwipeDetector.swift         — Pose detection, hand chirality, CGEvent posting, action history
  StatusBarController.swift   — Menu bar icon, NSPopover with gesture guide and settings
```

## License

MIT
