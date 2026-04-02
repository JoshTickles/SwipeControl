import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    let cameraManager = CameraManager()
    let statusBar = StatusBarController()
    statusBar.setup(cameraManager: cameraManager)
    cameraManager.startCapture()

    withExtendedLifetime((statusBar, cameraManager)) {
        app.run()
    }
}
