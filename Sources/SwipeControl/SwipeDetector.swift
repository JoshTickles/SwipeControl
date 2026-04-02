import AppKit
import Foundation
import Vision
import CoreGraphics

final class SwipeDetector: @unchecked Sendable {
    static let shared = SwipeDetector()

    private let lock = NSLock()
    private var gestureHistory: [(pose: Int, hand: Int)] = []
    private var _handDetected: Bool = false
    private var _lastGesture: String = ""
    private var _lastGestureTime: Date?
    private var _recentActions: [(gesture: String, timestamp: Date)] = []

    var handDetected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _handDetected
    }

    var lastGesture: String {
        lock.lock()
        defer { lock.unlock() }
        return _lastGesture
    }

    var lastGestureTime: Date? {
        lock.lock()
        defer { lock.unlock() }
        return _lastGestureTime
    }

    var recentActions: [(gesture: String, timestamp: Date)] {
        lock.lock()
        defer { lock.unlock() }
        return _recentActions
    }

    var cooldown: Double {
        get {
            let val = UserDefaults.standard.double(forKey: "cooldown")
            return val == 0 ? 1.0 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: "cooldown") }
    }

    private init() {
        if UserDefaults.standard.object(forKey: "cooldown") == nil {
            UserDefaults.standard.set(1.0, forKey: "cooldown")
        }
    }

    // MARK: - Frame Processing

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let results = request.results, !results.isEmpty else {
            lock.lock()
            _handDetected = false
            lock.unlock()
            return
        }

        lock.lock()
        _handDetected = true
        lock.unlock()

        var pose = 0
        var hand = 0
        for obs in results {
            let p = detectPose(obs)
            if p != 0 {
                pose = p
                hand = detectHand(obs)
                break
            }
        }
        if pose == 0 {
            hand = detectHand(results.first!)
        }

        lock.lock()
        gestureHistory.append((pose: pose, hand: hand))
        if gestureHistory.count > 8 {
            gestureHistory.removeFirst(gestureHistory.count - 8)
        }

        let currentCooldown = cooldown

        guard gestureHistory.count >= 5 else {
            lock.unlock()
            return
        }

        let lastFive = Array(gestureHistory.suffix(5))
        let stablePose = lastFive.allSatisfy({ $0.pose == lastFive.first!.pose && $0.hand == lastFive.first!.hand })
        let detectedPose = stablePose ? lastFive.first!.pose : 0
        let detectedHand = stablePose ? lastFive.first!.hand : 0

        let inCooldown: Bool
        if let lst = _lastGestureTime {
            inCooldown = Date().timeIntervalSince(lst) < currentCooldown
        } else {
            inCooldown = false
        }

        if detectedPose != 0 && !inCooldown {
            switch detectedPose {
            case 2:
                let direction = detectedHand == 1 ? "Left" : "Right"
                let label = direction == "Left" ? "✌️L ← Space" : "✌️R → Space"
                _lastGesture = label
                _lastGestureTime = Date()
                recordAction(label)
                gestureHistory.removeAll()
                lock.unlock()
                postDesktopSwitch(direction: direction)
            case 3:
                _lastGesture = "👉 Spotify"
                _lastGestureTime = Date()
                recordAction("👉 Spotify ▶️⏸️")
                gestureHistory.removeAll()
                lock.unlock()
                postSpotifyPlayPause()
            default:
                lock.unlock()
            }
            return
        }

        lock.unlock()
    }

    // MARK: - Pose Detection (0=none, 2=peace, 3=finger gun)

    private func detectPose(_ observation: VNHumanHandPoseObservation) -> Int {
        do {
            let thumbTip = try observation.recognizedPoint(.thumbTip)
            let thumbIP = try observation.recognizedPoint(.thumbIP)
            let indexTip = try observation.recognizedPoint(.indexTip)
            let indexPIP = try observation.recognizedPoint(.indexPIP)
            let middleTip = try observation.recognizedPoint(.middleTip)
            let middlePIP = try observation.recognizedPoint(.middlePIP)
            let ringTip = try observation.recognizedPoint(.ringTip)
            let ringPIP = try observation.recognizedPoint(.ringPIP)
            let littleTip = try observation.recognizedPoint(.littleTip)
            let littlePIP = try observation.recognizedPoint(.littlePIP)

            let thumbOut = abs(thumbTip.location.x - thumbIP.location.x) > 0.02
            let indexOut = indexTip.location.y > indexPIP.location.y + 0.02
            let middleOut = middleTip.location.y > middlePIP.location.y + 0.02
            let ringCurled = ringTip.location.y <= ringPIP.location.y + 0.02
            let littleCurled = littleTip.location.y <= littlePIP.location.y + 0.02

            if thumbOut && indexOut && !middleOut && ringCurled && littleCurled {
                return 3
            }
            if indexOut && middleOut && ringCurled && littleCurled {
                return 2
            }

            return 0
        } catch {
            return 0
        }
    }

    // MARK: - Hand Chirality (0=unknown, 1=left, 2=right)

    private func detectHand(_ observation: VNHumanHandPoseObservation) -> Int {
        switch observation.chirality {
        case .left: return 1
        case .right: return 2
        default: return 0
        }
    }

    // MARK: - Action History

    private func recordAction(_ gesture: String) {
        _recentActions.insert((gesture: gesture, timestamp: Date()), at: 0)
        if _recentActions.count > 5 {
            _recentActions.removeLast()
        }
    }

    // MARK: - Spotify Play/Pause

    private func postSpotifyPlayPause() {
        DispatchQueue.main.async {
            let script = NSAppleScript(source: "tell application \"Spotify\" to playpause")
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
        }
    }

    // MARK: - Desktop Switching

    private func postDesktopSwitch(direction: String) {
        let arrowKey: UInt16 = direction == "Left" ? 0x7B : 0x7C

        let controlDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x3B, keyDown: true)
        controlDown?.flags = .maskControl

        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: arrowKey, keyDown: true)
        keyDown?.flags = [.maskControl, .maskSecondaryFn]

        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: arrowKey, keyDown: false)
        keyUp?.flags = [.maskControl, .maskSecondaryFn]

        let controlUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x3B, keyDown: false)

        controlDown?.post(tap: .cghidEventTap)
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        controlUp?.post(tap: .cghidEventTap)
    }
}
