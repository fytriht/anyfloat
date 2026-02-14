import SwiftUI
import AppKit
import Carbon

@main
struct TextFApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // We manage windows manually, so keep an empty Settings scene.
        Settings {
            EmptyView()
        }
    }
}

private struct HotKeyOption {
    let keyCode: UInt32
    let label: String
}

private final class HotKeyRecorderContainerView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }
}

private enum HotKeySettingsResult {
    case save(HotKeyConfiguration)
    case cancel
}

private final class HotKeyRecorderView: NSControl {
    private let textField = NSTextField(labelWithString: "")
    private(set) var recordedConfiguration: HotKeyConfiguration

    override var acceptsFirstResponder: Bool { true }

    init(configuration: HotKeyConfiguration, frame frameRect: NSRect) {
        self.recordedConfiguration = configuration
        super.init(frame: frameRect)
        setupUI()
        updateLabel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifierBits = HotKeyConfiguration.modifierBits(from: modifiers)
        let keyCode = UInt32(event.keyCode)

        guard HotKeyConfiguration.supportedKeys.contains(where: { $0.keyCode == keyCode }) else {
            NSSound.beep()
            return
        }

        let candidate = HotKeyConfiguration(keyCode: keyCode, modifiers: modifierBits)
        guard candidate.isValid else {
            NSSound.beep()
            return
        }

        recordedConfiguration = candidate
        updateLabel()
        sendAction(action, to: target)
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = .systemFont(ofSize: 13, weight: .regular)
        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func updateLabel() {
        textField.stringValue = recordedConfiguration.displayLabel
    }

    func setRecordedConfiguration(_ configuration: HotKeyConfiguration) {
        recordedConfiguration = configuration
        updateLabel()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            let focusRect = bounds.insetBy(dx: 1.5, dy: 1.5)
            let path = NSBezierPath(roundedRect: focusRect, xRadius: 5, yRadius: 5)
            path.lineWidth = 2
            path.stroke()
        }
    }
}

private final class HotKeySettingsPanelController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private let recorder: HotKeyRecorderView

    init(configuration: HotKeyConfiguration) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 170),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        recorder = HotKeyRecorderView(
            configuration: configuration,
            frame: NSRect(x: 20, y: 78, width: 300, height: 32)
        )
        super.init()
        configurePanel()
    }

    func runModal() -> HotKeySettingsResult {
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        let response = NSApp.runModal(for: panel)
        panel.orderOut(nil)

        switch response {
        case .OK:
            return .save(recorder.recordedConfiguration)
        default:
            return .cancel
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard NSApp.modalWindow === panel else { return }
        NSApp.stopModal(withCode: .cancel)
    }

    private func configurePanel() {
        panel.title = "Set Global Hotkey"
        panel.isFloatingPanel = true
        panel.level = .modalPanel
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let contentView = HotKeyRecorderContainerView(frame: NSRect(x: 0, y: 0, width: 430, height: 170))
        contentView.wantsLayer = true
        panel.contentView = contentView

        let helpLabel = NSTextField(labelWithString: "Click the field and press your shortcut.")
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.frame = NSRect(x: 20, y: 126, width: 320, height: 18)
        contentView.addSubview(helpLabel)

        contentView.addSubview(recorder)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(handleSave))
        saveButton.frame = NSRect(x: 330, y: 14, width: 82, height: 30)
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(handleCancel))
        cancelButton.frame = NSRect(x: 240, y: 14, width: 82, height: 30)
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        let resetButton = NSButton(title: "Reset Default", target: self, action: #selector(handleResetDefault))
        resetButton.frame = NSRect(x: 20, y: 14, width: 120, height: 30)
        contentView.addSubview(resetButton)
    }

    @objc private func handleSave() {
        NSApp.stopModal(withCode: .OK)
    }

    @objc private func handleCancel() {
        NSApp.stopModal(withCode: .cancel)
    }

    @objc private func handleResetDefault() {
        recorder.setRecordedConfiguration(HotKeyConfiguration.defaultValue)
        panel.makeFirstResponder(recorder)
    }
}

private struct HotKeyConfiguration: Codable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let defaultsKey = "globalHotKey.configuration"
    static let defaultValue = HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(cmdKey | shiftKey))

    static let supportedKeys: [HotKeyOption] = [
        HotKeyOption(keyCode: UInt32(kVK_ANSI_A), label: "A"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_B), label: "B"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_C), label: "C"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_D), label: "D"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_E), label: "E"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_F), label: "F"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_G), label: "G"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_H), label: "H"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_I), label: "I"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_J), label: "J"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_K), label: "K"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_L), label: "L"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_M), label: "M"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_N), label: "N"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_O), label: "O"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_P), label: "P"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_Q), label: "Q"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_R), label: "R"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_S), label: "S"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_T), label: "T"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_U), label: "U"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_V), label: "V"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_W), label: "W"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_X), label: "X"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_Y), label: "Y"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_Z), label: "Z"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_0), label: "0"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_1), label: "1"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_2), label: "2"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_3), label: "3"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_4), label: "4"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_5), label: "5"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_6), label: "6"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_7), label: "7"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_8), label: "8"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_9), label: "9"),
        HotKeyOption(keyCode: UInt32(kVK_F1), label: "F1"),
        HotKeyOption(keyCode: UInt32(kVK_F2), label: "F2"),
        HotKeyOption(keyCode: UInt32(kVK_F3), label: "F3"),
        HotKeyOption(keyCode: UInt32(kVK_F4), label: "F4"),
        HotKeyOption(keyCode: UInt32(kVK_F5), label: "F5"),
        HotKeyOption(keyCode: UInt32(kVK_F6), label: "F6"),
        HotKeyOption(keyCode: UInt32(kVK_F7), label: "F7"),
        HotKeyOption(keyCode: UInt32(kVK_F8), label: "F8"),
        HotKeyOption(keyCode: UInt32(kVK_F9), label: "F9"),
        HotKeyOption(keyCode: UInt32(kVK_F10), label: "F10"),
        HotKeyOption(keyCode: UInt32(kVK_F11), label: "F11"),
        HotKeyOption(keyCode: UInt32(kVK_F12), label: "F12")
    ]

    private static let allowedModifiers = UInt32(cmdKey | shiftKey | optionKey | controlKey)

    static func modifierBits(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var bits: UInt32 = 0
        if flags.contains(.command) { bits |= UInt32(cmdKey) }
        if flags.contains(.shift) { bits |= UInt32(shiftKey) }
        if flags.contains(.option) { bits |= UInt32(optionKey) }
        if flags.contains(.control) { bits |= UInt32(controlKey) }
        return bits
    }

    static func loadFromDefaults() -> HotKeyConfiguration {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(HotKeyConfiguration.self, from: data),
            decoded.isValid
        else {
            return defaultValue
        }
        return decoded
    }

    func persistToDefaults() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: HotKeyConfiguration.defaultsKey)
    }

    var keyLabel: String {
        HotKeyConfiguration.supportedKeys.first { $0.keyCode == keyCode }?.label ?? "KeyCode \(keyCode)"
    }

    var displayLabel: String {
        let parts = modifierLabels + [keyLabel]
        return parts.joined(separator: " + ")
    }

    var isValid: Bool {
        guard HotKeyConfiguration.supportedKeys.contains(where: { $0.keyCode == keyCode }) else { return false }
        let sanitized = modifiers & HotKeyConfiguration.allowedModifiers
        return sanitized != 0
    }

    private var modifierLabels: [String] {
        var labels: [String] = []
        if modifiers & UInt32(cmdKey) != 0 { labels.append("Command") }
        if modifiers & UInt32(shiftKey) != 0 { labels.append("Shift") }
        if modifiers & UInt32(optionKey) != 0 { labels.append("Option") }
        if modifiers & UInt32(controlKey) != 0 { labels.append("Control") }
        return labels
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerRef: EventHandlerRef?
    private let panelController = FloatingPanelController()
    private var statusItem: NSStatusItem?
    private var configureHotKeyMenuItem: NSMenuItem?
    private var lastExternalAppPID: pid_t?
    private var hotKeyConfiguration = HotKeyConfiguration.loadFromDefaults()
    private var isConfiguringHotKey = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        requestAccessibilityIfNeeded()
        seedLastExternalAppPID()
        observeFrontmostAppChanges()
        setupStatusItem()
        scheduleHotKeyRegistration()
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotKey()
    }

    private func scheduleHotKeyRegistration() {
        // Delay registration by one runloop turn so agent/status-bar setup is complete.
        DispatchQueue.main.async { [weak self] in
            self?.registerHotKey()
        }
    }

    private func registerHotKey() {
        unregisterHotKey()

        let keyCode: UInt32 = hotKeyConfiguration.keyCode
        let modifiers: UInt32 = hotKeyConfiguration.modifiers
        let target = GetEventDispatcherTarget()

        let hotKeyID = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: "TXTF".fourCharCodeValue)), id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, target, 0, &hotKeyRef)
        if status != noErr {
            NSLog("RegisterEventHotKey failed: \(status)")
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(target, { _, _, userData in
            guard let userData else { return noErr }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            // Carbon hotkey callback may not run on the main thread. AX reads are more
            // reliable when executed on the main thread/runloop.
            DispatchQueue.main.async {
                appDelegate.onHotKeyPressed()
            }
            return noErr
        }, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &hotKeyHandlerRef)
        if handlerStatus != noErr {
            NSLog("InstallEventHandler failed: \(handlerStatus)")
        }
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let hotKeyHandlerRef {
            RemoveEventHandler(hotKeyHandlerRef)
        }
        hotKeyRef = nil
        hotKeyHandlerRef = nil
    }

    private func onHotKeyPressed() {
        guard !isConfiguringHotKey else { return }
        refreshLastExternalAppPIDFromCurrentFrontmost()
        let text = SelectedTextReader.readSelectedText(preferredAppPID: lastExternalAppPID) ?? "(No selected text)"
        panelController.show(text: text)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "TextF"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Selected Text", action: #selector(handleShowSelectedText), keyEquivalent: ""))
        let hotKeyItem = NSMenuItem(title: "", action: #selector(handleConfigureHotKey), keyEquivalent: "")
        hotKeyItem.target = self
        configureHotKeyMenuItem = hotKeyItem
        menu.addItem(hotKeyItem)
        menu.addItem(NSMenuItem(title: "Debug Panel", action: #selector(handleDebugPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit TextF", action: #selector(handleQuit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        item.menu = menu
        self.statusItem = item
        refreshConfigureHotKeyMenuItemTitle()
    }

    private func refreshConfigureHotKeyMenuItemTitle() {
        configureHotKeyMenuItem?.title = "Set Hotkey"
    }

    @objc private func handleShowSelectedText() {
        onHotKeyPressed()
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }

    @objc private func handleConfigureHotKey() {
        let panelController = HotKeySettingsPanelController(configuration: hotKeyConfiguration)
        isConfiguringHotKey = true
        defer { isConfiguringHotKey = false }
        switch panelController.runModal() {
        case .save(let configuration):
            applyHotKeyConfiguration(configuration)
        case .cancel:
            break
        }
    }

    private func applyHotKeyConfiguration(_ configuration: HotKeyConfiguration) {
        hotKeyConfiguration = configuration
        hotKeyConfiguration.persistToDefaults()
        refreshConfigureHotKeyMenuItemTitle()
        registerHotKey()
    }

    private func requestAccessibilityIfNeeded() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            NSLog("Accessibility permission not granted yet.")
        }
    }

    @objc private func handleDebugPanel() {
        let trusted = AXIsProcessTrusted()
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let executablePath = Bundle.main.executableURL?.path ?? "unknown"
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let frontmost = NSWorkspace.shared.frontmostApplication
        let frontmostName = frontmost?.localizedName ?? "unknown"
        let frontmostPID = frontmost?.processIdentifier ?? -1
        let frontmostBundleID = frontmost?.bundleIdentifier ?? "unknown"
        let focusedAppPID = SelectedTextReader.debugFocusedApplicationPID()?.description ?? "nil"

        var focusedStatus = "unknown"
        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        let err = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        if err == .success, let focused {
            focusedStatus = "ok (typeId=\(CFGetTypeID(focused)))"
        } else {
            focusedStatus = "error \(err.rawValue)"
        }

        let message = """
        [App]
        Bundle ID: \(bundleID)
        Executable: \(executablePath)
        Self PID: \(selfPID)
        Hotkey: \(hotKeyConfiguration.displayLabel)

        [Permissions / AX]
        AX Trusted: \(trusted)
        Focused Element: \(focusedStatus)
        Focused App PID (AX): \(focusedAppPID)

        [Frontmost App]
        Name: \(frontmostName)
        PID: \(frontmostPID)
        Bundle ID: \(frontmostBundleID)
        Last External PID: \(lastExternalAppPID?.description ?? "nil")

        [SelectedTextReader]
        \(SelectedTextReader.debugSnapshot(preferredAppPID: lastExternalAppPID))
        """

        let alert = NSAlert()
        alert.messageText = "TextF Debug Panel"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func seedLastExternalAppPID() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let selfPID = ProcessInfo.processInfo.processIdentifier
        if app.processIdentifier != selfPID {
            lastExternalAppPID = app.processIdentifier
        }
    }

    private func refreshLastExternalAppPIDFromCurrentFrontmost() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let selfPID = ProcessInfo.processInfo.processIdentifier
        if app.processIdentifier != selfPID {
            lastExternalAppPID = app.processIdentifier
        }
    }

    private func observeFrontmostAppChanges() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }

            let selfPID = ProcessInfo.processInfo.processIdentifier
            if app.processIdentifier != selfPID {
                self.lastExternalAppPID = app.processIdentifier
            }
        }
    }
}

final class FloatingPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingTextView>?
    private var keyMonitor: Any?
    private var currentText = ""
    private var fontSize: CGFloat

    private let defaultFontSize: CGFloat = 12
    private let minFontSize: CGFloat = 8
    private let maxFontSize: CGFloat = 36
    private let fontSizeDefaultsKey = "floatingPanel.fontSize"
    private let mouseOffsetX: CGFloat = 16
    private let mouseOffsetY: CGFloat = 16
    private let minPanelSize = NSSize(width: 300, height: 400)
    private let maxPanelSize = NSSize(width: 600, height: 800)
    private let defaultPanelSize = NSSize(width: 300, height: 400)

    override init() {
        fontSize = defaultFontSize
        super.init()
        let storedSize = UserDefaults.standard.object(forKey: fontSizeDefaultsKey) as? Double
        let initialSize = CGFloat(storedSize ?? Double(defaultFontSize))
        fontSize = min(max(initialSize, minFontSize), maxFontSize)
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }

    func show(text: String) {
        currentText = text
        if panel == nil {
            createPanel()
        }
        guard let panel, let hostingView else { return }

        hostingView.rootView = FloatingTextView(text: currentText, fontSize: fontSize)
        resetPanelSizeToDefault(panel)
        positionPanelNearMouse(panel)
        _ = NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    private func createPanel() {
        let contentView = FloatingTextView(text: "", fontSize: fontSize)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: defaultPanelSize),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        // .canJoinAllSpaces and .moveToActiveSpace are mutually exclusive.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.minSize = minPanelSize
        panel.maxSize = maxPanelSize
        panel.contentMinSize = minPanelSize
        panel.contentMaxSize = maxPanelSize
        panel.delegate = self

        panel.contentView = hostingView
        installKeyMonitorIfNeeded()
        self.panel = panel
        self.hostingView = hostingView
    }

    private func resetPanelSizeToDefault(_ panel: NSPanel) {
        panel.setFrame(
            NSRect(origin: panel.frame.origin, size: defaultPanelSize),
            display: true
        )
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(
            width: min(max(frameSize.width, minPanelSize.width), maxPanelSize.width),
            height: min(max(frameSize.height, minPanelSize.height), maxPanelSize.height)
        )
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, panel.isKeyWindow else {
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers.contains(.command) else {
                return event
            }

            switch event.keyCode {
            case UInt16(kVK_ANSI_0), UInt16(kVK_ANSI_Keypad0):
                self.resetFontSize()
                return nil
            case UInt16(kVK_ANSI_Minus), UInt16(kVK_ANSI_KeypadMinus):
                self.adjustFontSize(by: -1)
                return nil
            case UInt16(kVK_ANSI_Equal), UInt16(kVK_ANSI_KeypadPlus):
                self.adjustFontSize(by: 1)
                return nil
            default:
                return event
            }
        }
    }

    private func adjustFontSize(by delta: CGFloat) {
        guard let hostingView else { return }
        let nextSize = min(max(fontSize + delta, minFontSize), maxFontSize)
        guard nextSize != fontSize else { return }

        fontSize = nextSize
        persistFontSize()
        hostingView.rootView = FloatingTextView(text: currentText, fontSize: fontSize)
    }

    private func resetFontSize() {
        guard let hostingView else { return }
        guard fontSize != defaultFontSize else { return }

        fontSize = defaultFontSize
        persistFontSize()
        hostingView.rootView = FloatingTextView(text: currentText, fontSize: fontSize)
    }

    private func persistFontSize() {
        UserDefaults.standard.set(Double(fontSize), forKey: fontSizeDefaultsKey)
    }

    private func positionPanelNearMouse(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let panelSize = panel.frame.size
        let targetScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        let visibleFrame = targetScreen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect.zero
        guard !visibleFrame.isEmpty else { return }

        var originX = mouseLocation.x + mouseOffsetX
        var originY = mouseLocation.y - panelSize.height - mouseOffsetY

        originX = min(max(originX, visibleFrame.minX), visibleFrame.maxX - panelSize.width)
        originY = min(max(originY, visibleFrame.minY), visibleFrame.maxY - panelSize.height)

        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}

struct FloatingTextView: View {
    let text: String
    let fontSize: CGFloat

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            ScrollView {
                Text(text)
                    .font(.system(size: fontSize, weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .textSelection(.enabled)
            }
        }
    }
}

enum SelectedTextReader {
    private static let axTimeout: Float = 1.5
    private static let maxRetries = 3
    private static let retryDelayMicroseconds: useconds_t = 60_000

    static func readSelectedText(preferredAppPID: pid_t? = nil) -> String? {
        // 0) First try the currently focused app PID from system-wide AX.
        if let focusedPID = focusedApplicationPID(),
           let text = selectedText(fromAppPID: focusedPID) {
            return text
        }

        // 1) Then try the latest known non-TextF app PID.
        if let preferredAppPID,
           let text = selectedText(fromAppPID: preferredAppPID) {
            return text
        }

        // 2) Try system-wide focused element directly.
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, axTimeout)
        for attempt in 0..<maxRetries {
            if let element = focusedElement(from: systemWide),
               let text = selectedText(from: element) {
                return text
            }
            if attempt < maxRetries - 1 {
                usleep(retryDelayMicroseconds)
            }
        }

        // 3) Fallback: query frontmost app.
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            if let text = selectedText(fromAppPID: frontmost.processIdentifier) {
                return text
            }
        }

        // 4) Compatibility fallback: simulate Cmd+C, read pasteboard, restore pasteboard.
        if let copiedText = copySelectionViaPasteboardFallback() {
            return copiedText
        }

        return nil
    }

    static func debugFocusedApplicationPID() -> pid_t? {
        focusedApplicationPID()
    }

    static func debugSnapshot(preferredAppPID: pid_t?) -> String {
        var lines: [String] = []
        lines.append("AX Timeout: \(axTimeout)s")
        lines.append("Max Retries: \(maxRetries)")
        lines.append("Retry Delay: \(retryDelayMicroseconds)us")

        let focusedPID = focusedApplicationPID()
        lines.append("Focused PID Probe: \(focusedPID?.description ?? "nil")")

        let focusedResult = focusedPID.flatMap { selectedText(fromAppPID: $0) }
        lines.append("Focused App Text: \(textSummary(focusedResult))")

        let preferredResult = preferredAppPID.flatMap { selectedText(fromAppPID: $0) }
        lines.append("Preferred App Text: \(textSummary(preferredResult))")

        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, axTimeout)
        let systemWideResult = focusedElement(from: systemWide).flatMap { selectedText(from: $0) }
        lines.append("System-Wide Focused Element Text: \(textSummary(systemWideResult))")

        lines.append("Pasteboard Fallback: enabled (not executed in panel)")
        return lines.joined(separator: "\n")
    }

    private static func selectedText(fromAppPID pid: pid_t) -> String? {
        guard NSRunningApplication(processIdentifier: pid) != nil else { return nil }
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, axTimeout)
        for attempt in 0..<maxRetries {
            if let element = focusedElement(from: appElement),
               let text = selectedText(from: element) {
                return text
            }
            if let window = elementAttributeElement(from: appElement, attribute: kAXFocusedWindowAttribute),
               let element = focusedElement(from: window),
               let text = selectedText(from: element) {
                return text
            }
            if attempt < maxRetries - 1 {
                usleep(retryDelayMicroseconds)
            }
        }
        return nil
    }

    private static func focusedApplicationPID() -> pid_t? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, axTimeout)
        var focusedApp: AnyObject?
        let err = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard err == .success, let appElement = focusedApp else { return nil }
        guard CFGetTypeID(appElement) == AXUIElementGetTypeID() else { return nil }
        let appAX = unsafeBitCast(appElement, to: AXUIElement.self)
        var pid: pid_t = 0
        let pidErr = AXUIElementGetPid(appAX, &pid)
        guard pidErr == .success, pid > 0 else { return nil }
        return pid
    }

    private static func focusedElement(from root: AXUIElement) -> AXUIElement? {
        var focused: AnyObject?
        let err = AXUIElementCopyAttributeValue(root, kAXFocusedUIElementAttribute as CFString, &focused)
        guard err == .success, let element = focused else { return nil }
        guard CFGetTypeID(element) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(element, to: AXUIElement.self)
    }

    private static func elementAttributeElement(from root: AXUIElement, attribute: String) -> AXUIElement? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(root, attribute as CFString, &value)
        guard err == .success, let element = value else { return nil }
        guard CFGetTypeID(element) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(element, to: AXUIElement.self)
    }

    private static func selectedText(from element: AXUIElement) -> String? {
        // Try direct selected text
        var selectedText: AnyObject?
        let selectedTextError = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
        if selectedTextError == .success {
            if let text = selectedText as? String, !text.isEmpty {
                return text
            }
            if let attr = selectedText as? NSAttributedString, !attr.string.isEmpty {
                return attr.string
            }
        }

        // Some controls expose ranges only.
        if let ranged = selectedTextFromRanges(from: element) {
            return ranged
        }

        // Fallback: derive from selected range + full value
        var selectedRangeValue: AnyObject?
        let rangeError = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue)
        if rangeError == .success, let rangeValue = selectedRangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() {
            let axValue = rangeValue as! AXValue
            var range = CFRange()
            if AXValueGetValue(axValue, .cfRange, &range) {
                var value: AnyObject?
                let valueError = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
                if valueError == .success, let fullText = value as? String, let slice = substring(fullText, cfRange: range) {
                    return slice.isEmpty ? nil : slice
                }
            }
        }

        return nil
    }

    private static func selectedTextFromRanges(from element: AXUIElement) -> String? {
        var selectedRanges: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangesAttribute as CFString, &selectedRanges)
        guard err == .success, let ranges = selectedRanges as? [AnyObject], !ranges.isEmpty else { return nil }

        var chunks: [String] = []
        for raw in ranges {
            guard CFGetTypeID(raw) == AXValueGetTypeID() else { continue }
            let rangeValue = raw as! AXValue

            var plain: AnyObject?
            let plainErr = AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXStringForRangeParameterizedAttribute as CFString,
                rangeValue,
                &plain
            )
            if plainErr == .success, let text = plain as? String, !text.isEmpty {
                chunks.append(text)
                continue
            }

            var rich: AnyObject?
            let richErr = AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXAttributedStringForRangeParameterizedAttribute as CFString,
                rangeValue,
                &rich
            )
            if richErr == .success, let attr = rich as? NSAttributedString, !attr.string.isEmpty {
                chunks.append(attr.string)
            }
        }

        guard !chunks.isEmpty else { return nil }
        return chunks.joined()
    }

    private static func substring(_ text: String, cfRange: CFRange) -> String? {
        guard cfRange.location >= 0, cfRange.length >= 0 else { return nil }
        let nsText = text as NSString
        let upperBound = cfRange.location + cfRange.length
        guard cfRange.location <= nsText.length, upperBound <= nsText.length else { return nil }
        let nsRange = NSRange(location: cfRange.location, length: cfRange.length)
        return nsText.substring(with: nsRange)
    }

    private static func textSummary(_ text: String?) -> String {
        guard let text else { return "nil" }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "empty" }
        let preview = String(trimmed.prefix(120))
        let suffix = trimmed.count > 120 ? "..." : ""
        return "len=\(trimmed.count), preview=\"\(preview)\(suffix)\""
    }

    private struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    private static func copySelectionViaPasteboardFallback() -> String? {
        let pasteboard = NSPasteboard.general
        let beforeCount = pasteboard.changeCount
        let snapshot = snapshotPasteboard(pasteboard)

        guard simulateCommandC() else { return nil }

        // Give target app a short moment to update pasteboard.
        usleep(180_000)

        let afterCount = pasteboard.changeCount
        guard afterCount != beforeCount else { return nil }
        let copied = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)

        restorePasteboard(snapshot, to: pasteboard)

        guard let copied, !copied.isEmpty else { return nil }
        return copied
    }

    private static func snapshotPasteboard(_ pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            var typedData: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    typedData[type] = data
                }
            }
            return typedData
        }
        return PasteboardSnapshot(items: items)
    }

    private static func restorePasteboard(_ snapshot: PasteboardSnapshot, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return }
        let restoredItems = snapshot.items.map { typedData -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in typedData {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }

    private static func simulateCommandC() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        source.localEventsSuppressionInterval = 0

        let cKeyCode: CGKeyCode = 8 // ANSI C
        guard
            let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: true),
            let cDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true),
            let cUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false),
            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: false)
        else {
            return false
        }

        cmdDown.flags = .maskCommand
        cDown.flags = .maskCommand
        cUp.flags = .maskCommand
        cmdUp.flags = []

        cmdDown.post(tap: .cghidEventTap)
        cDown.post(tap: .cghidEventTap)
        cUp.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)
        return true
    }
}

private extension String {
    var fourCharCodeValue: UInt32 {
        var result: UInt32 = 0
        for char in utf8.prefix(4) {
            result = (result << 8) + UInt32(char)
        }
        return result
    }
}
