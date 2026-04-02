# Changelog

- Added: SwipeControl app — hand gesture desktop switching via Vision framework + CGEvent (josh, 2026-04-02)
- Added: External camera support (Logitech C920) with fixed-rate frame duration handling (josh, 2026-04-02)
- Added: Peak velocity swipe detection algorithm with majority-vote direction consistency (josh, 2026-04-02)
- Added: Finger gun gesture for Spotify play/pause (thumb + index extended, others curled) (josh, 2026-04-02)
- Added: CGEvent space switching with .maskSecondaryFn flag for arrow keys (josh, 2026-04-02)
- Added: UserDefaults-based settings: sensitivity, cooldown, reverseDirection (josh, 2026-04-02)
- Added: NSPopover settings UI with status display, sliders, camera toggle (josh, 2026-04-02)
- Fixed: Thread safety — all @Published-equivalent state updates dispatch to main thread (josh, 2026-04-02)
- Fixed: Finger gun only fires when hand is stationary, prevents false positives from face/hair touching (josh, 2026-04-02)
