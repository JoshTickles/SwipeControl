import AVFoundation
import Foundation

final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let outputQueue = DispatchQueue(label: "com.swipecontrol.camera", qos: .userInteractive)
    private var _activeCamera: String = "None"
    private let lock = NSLock()

    var activeCamera: String {
        lock.lock()
        defer { lock.unlock() }
        return _activeCamera
    }

    var isRunning: Bool {
        session.isRunning
    }

    func startCapture() {
        guard !session.isRunning else { return }

        session.sessionPreset = .medium

        guard let device = preferredCamera() else {
            print("SwipeControl: No camera found")
            return
        }

        lock.lock()
        _activeCamera = device.localizedName
        lock.unlock()
        print("Using camera: \(device.localizedName)")

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("SwipeControl: Failed to create camera input – \(error)")
            return
        }

        configureFrameRate(device: device, targetFPS: 15)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: outputQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.startRunning()
    }

    func stopCapture() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    // MARK: - Camera Selection

    private func preferredCamera() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
            mediaType: .video,
            position: .unspecified
        )

        let devices = discovery.devices
        if let external = devices.first(where: { $0.deviceType == .external }) {
            return external
        }
        return devices.first
    }

    // MARK: - Frame Rate

    private func configureFrameRate(device: AVCaptureDevice, targetFPS: Int) {
        do {
            try device.lockForConfiguration()

            let ranges = device.activeFormat.videoSupportedFrameRateRanges
            let match = ranges.first {
                $0.minFrameRate <= Double(targetFPS) && Double(targetFPS) <= $0.maxFrameRate
            }

            if let range = match {
                device.activeVideoMinFrameDuration = range.minFrameDuration
                device.activeVideoMaxFrameDuration = range.maxFrameDuration
            } else if let fallback = ranges.first {
                device.activeVideoMinFrameDuration = fallback.minFrameDuration
                device.activeVideoMaxFrameDuration = fallback.maxFrameDuration
            }

            device.unlockForConfiguration()
        } catch {
            print("SwipeControl: Could not configure frame rate – \(error)")
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        SwipeDetector.shared.processFrame(sampleBuffer)
    }
}
