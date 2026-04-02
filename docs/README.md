# SwipeControl

A minimal macOS menu bar app that detects hand gestures via the camera and maps them to system actions.

## Gestures

| Gesture | Action | Description |
|---------|--------|-------------|
| Swipe Left | Previous desktop space | Move hand left horizontally |
| Swipe Right | Next desktop space | Move hand right horizontally |
| Finger Gun | Spotify play/pause | Thumb + index extended, other fingers curled, hold still ~0.7s |

## Requirements

- macOS 15.0 (Sequoia) or later
- Camera (built-in or external USB webcam)
- Accessibility permission (for CGEvent key posting)
- Automation permission for System Events (for Spotify control)

## Camera Support

Prefers external cameras (e.g. Logitech C920) over built-in. Works in clamshell mode. Handles fixed-rate cameras that don't support arbitrary frame durations.

## Installation

### Build from source

```bash
cd /Users/josh/home/SwipeControl
swift build -c release
```

### Create app bundle

```bash
APP="/Applications/SwipeControl.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/SwipeControl "$APP/Contents/MacOS/SwipeControl"
chmod +x "$APP/Contents/MacOS/SwipeControl"
# Copy Info.plist (see repo)
codesign --force --deep --sign - "$APP"
```

### Permissions

After first launch, grant:

1. **Camera** — System Settings -> Privacy & Security -> Camera -> SwipeControl on
2. **Accessibility** — System Settings -> Privacy & Security -> Accessibility -> add SwipeControl, toggle on
3. **Automation** — prompted automatically when finger gun first fires ("SwipeControl wants to control Spotify")

**Important**: Re-signing the app (`codesign`) invalidates Accessibility. You must re-add SwipeControl to Accessibility after every re-sign.

## Settings

Adjustable from the menu bar popover or via `defaults` CLI.

### Sensitivity (swipe threshold)

How far the palm must move in normalized camera coordinates (0-1) to trigger a swipe.

| Value | Behavior |
|-------|----------|
| 0.08 | Very sensitive, small hand movements trigger |
| 0.12 | Moderate |
| **0.15** | **Default — good balance** |
| 0.20 | Requires deliberate large swipe |
| 0.25 | Very large swipe needed |

```bash
defaults write com.josh.swipecontrol sensitivity -float 0.15
```

### Cooldown

Seconds between consecutive gesture triggers. Prevents double-firing.

| Value | Behavior |
|-------|----------|
| 0.5 | Very responsive, may double-fire |
| **1.0** | **Default — responsive without double-fire** |
| 1.5 | Conservative |
| 2.0+ | Slow but safe |

```bash
defaults write com.josh.swipecontrol cooldown -float 1.0
```

### Reverse Direction

Flips swipe direction to match natural scroll (trackpad-like) behavior.

```bash
# Natural scroll (default ON)
defaults write com.josh.swipecontrol reverseDirection -bool true

# Direct mapping
defaults write com.josh.swipecontrol reverseDirection -bool false
```

### All defaults

```bash
defaults read com.josh.swipecontrol
```

### Reset to defaults

```bash
defaults delete com.josh.swipecontrol
```

## Architecture

```
Sources/SwipeControl/
  main.swift                 -- NSApplication entry, .accessory policy (no dock icon)
  CameraManager.swift        -- AVCaptureSession, external camera preference, frame rate handling
  SwipeDetector.swift         -- Palm tracking, peak velocity swipe detection, finger gun detection, CGEvent posting
  StatusBarController.swift   -- NSStatusBar menu bar icon, NSPopover settings UI
```

### Swipe Detection

Uses peak velocity algorithm: tracks palm center X across a sliding window of frames, detects the frame with maximum velocity, uses that for direction. Max displacement from origin must exceed sensitivity threshold.

### Finger Gun Detection

Checks specific finger landmark positions: thumb tip vs thumb IP (extended if spread), index tip vs PIP (extended if tip above PIP), middle/ring/little must all be curled. Requires 5 consecutive positive frames while hand is stationary.

### Desktop Switching

Uses CGEvent with Control + Arrow key. Arrow keys require `.maskSecondaryFn` flag in addition to `.maskControl` — without this, macOS does not recognize them as space-switching commands. Posts Control down, Arrow down+up, Control up as four separate events.

## Known Limitations

- Desktop switch only affects the display where the mouse cursor is located
- Re-signing invalidates Accessibility permission (macOS ties permission to code signature)
- Vision framework hand pose detection can be unreliable under poor lighting
- High CPU usage (~5-10%) due to continuous camera frame analysis
