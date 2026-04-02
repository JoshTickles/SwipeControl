import AppKit
import Foundation
import ServiceManagement

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cameraManager: CameraManager?

    func setup(cameraManager: CameraManager) {
        self.cameraManager = cameraManager

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "SwipeControl")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let vc = SettingsViewController()
        vc.cameraManager = cameraManager

        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 440)
        popover.behavior = .transient
        popover.contentViewController = vc
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

// MARK: - Settings ViewController

final class SettingsViewController: NSViewController {
    var cameraManager: CameraManager?

    private var cameraLabel: NSTextField!
    private var handLabel: NSTextField!
    private var historyLabels: [NSTextField] = []
    private var cooldownValueLabel: NSTextField!
    private var toggleButton: NSButton!
    private var loginCheckbox: NSButton!
    private var updateTimer: Timer?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 440))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshLoginState()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshStatus()
            }
        }
        RunLoop.main.add(updateTimer!, forMode: .common)
        refreshStatus()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - UI Construction

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let titleLabel = makeLabel("SwipeControl", bold: true, size: 14)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(makeSeparator())

        // --- Status ---
        cameraLabel = makeLabel("Camera: Off", size: 11)
        stack.addArrangedSubview(cameraLabel)

        handLabel = makeLabel("Hand: 🔴 None", size: 11)
        stack.addArrangedSubview(handLabel)

        stack.addArrangedSubview(makeSeparator())

        // --- Gesture Guide ---
        stack.addArrangedSubview(makeLabel("Gestures", bold: true, size: 12))

        let guideRows: [(String, String, String)] = [
            ("✌️ L", "Peace (left hand)", "← Previous space"),
            ("✌️ R", "Peace (right hand)", "→ Next space"),
            ("👉", "Finger gun", "♫ Spotify play/pause"),
        ]
        for (icon, gesture, action) in guideRows {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 6
            let iconLabel = makeLabel(icon, size: 11)
            iconLabel.setContentHuggingPriority(.required, for: .horizontal)
            NSLayoutConstraint.activate([iconLabel.widthAnchor.constraint(equalToConstant: 30)])
            let gestureLabel = makeLabel(gesture, size: 10)
            gestureLabel.textColor = .secondaryLabelColor
            let actionLabel = makeLabel(action, size: 10)
            actionLabel.textColor = .tertiaryLabelColor
            actionLabel.alignment = .right
            actionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(iconLabel)
            row.addArrangedSubview(gestureLabel)
            row.addArrangedSubview(actionLabel)
            row.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([row.widthAnchor.constraint(equalToConstant: 268)])
            stack.addArrangedSubview(row)
        }

        stack.addArrangedSubview(makeSeparator())

        // --- Recent Actions ---
        stack.addArrangedSubview(makeLabel("Recent Actions", bold: true, size: 12))

        historyLabels = []
        for _ in 0..<5 {
            let label = makeLabel("—", size: 10)
            label.textColor = .secondaryLabelColor
            stack.addArrangedSubview(label)
            historyLabels.append(label)
        }

        stack.addArrangedSubview(makeSeparator())

        // --- Settings ---
        stack.addArrangedSubview(makeLabel("Settings", bold: true, size: 12))

        let cooldownRow = buildSliderRow(
            label: "Response delay",
            min: 0.5, max: 3.0,
            value: SwipeDetector.shared.cooldown,
            action: #selector(cooldownChanged(_:)),
            valueLabel: &cooldownValueLabel,
            format: "%.1fs"
        )
        stack.addArrangedSubview(cooldownRow)

        loginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(toggleLogin(_:)))
        loginCheckbox.font = NSFont.systemFont(ofSize: 11)
        stack.addArrangedSubview(loginCheckbox)

        stack.addArrangedSubview(makeSeparator())

        // --- Buttons ---
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10

        toggleButton = NSButton(title: "Stop Camera", target: self, action: #selector(toggleCamera))
        toggleButton.bezelStyle = .rounded
        toggleButton.font = NSFont.systemFont(ofSize: 11)

        let quitButton = NSButton(title: "Quit", target: self, action: #selector(quitApp))
        quitButton.bezelStyle = .rounded
        quitButton.font = NSFont.systemFont(ofSize: 11)

        buttonRow.addArrangedSubview(toggleButton)
        buttonRow.addArrangedSubview(quitButton)
        stack.addArrangedSubview(buttonRow)
    }

    // MARK: - Slider Row

    private func buildSliderRow(
        label: String,
        min: Double, max: Double, value: Double,
        action: Selector,
        valueLabel: inout NSTextField!,
        format: String
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8

        let nameLabel = makeLabel(label, size: 11)
        nameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let slider = NSSlider(value: value, minValue: min, maxValue: max, target: self, action: action)
        slider.isContinuous = true
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let vLabel = makeLabel(String(format: format, value), size: 11)
        vLabel.alignment = .right
        vLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        NSLayoutConstraint.activate([vLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 36)])

        valueLabel = vLabel

        row.addArrangedSubview(nameLabel)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(vLabel)

        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([row.widthAnchor.constraint(equalToConstant: 268)])

        return row
    }

    // MARK: - Actions

    @objc private func cooldownChanged(_ sender: NSSlider) {
        let value = sender.doubleValue
        SwipeDetector.shared.cooldown = value
        cooldownValueLabel.stringValue = String(format: "%.1fs", value)
    }

    @objc private func toggleCamera() {
        guard let cam = cameraManager else { return }
        if cam.isRunning {
            cam.stopCapture()
            toggleButton.title = "Start Camera"
        } else {
            cam.startCapture()
            toggleButton.title = "Stop Camera"
        }
    }

    @objc private func toggleLogin(_ sender: NSButton) {
        let enable = sender.state == .on
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail — user can retry
        }
    }

    @objc private func quitApp() {
        cameraManager?.stopCapture()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Status Refresh

    private func refreshStatus() {
        guard let cam = cameraManager else { return }

        let running = cam.isRunning
        let camName = cam.activeCamera
        cameraLabel.stringValue = "Camera: \(running ? "On" : "Off") — \(camName)"

        let detected = SwipeDetector.shared.handDetected
        handLabel.stringValue = "Hand: \(detected ? "🟢 Detected" : "🔴 None")"

        let actions = SwipeDetector.shared.recentActions
        for (i, label) in historyLabels.enumerated() {
            if i < actions.count {
                let action = actions[i]
                let elapsed = Int(Date().timeIntervalSince(action.timestamp))
                label.stringValue = "\(action.gesture)  \(elapsed)s ago"
            } else {
                label.stringValue = "—"
            }
        }

        toggleButton.title = running ? "Stop Camera" : "Start Camera"
    }

    private func refreshLoginState() {
        let status = SMAppService.mainApp.status
        loginCheckbox.state = (status == .enabled) ? .on : .off
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, bold: Bool = false, size: CGFloat = 11) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.backgroundColor = .clear
        return label
    }

    private func makeSeparator() -> NSView {
        let sep = NSBox()
        sep.boxType = .separator
        return sep
    }
}
