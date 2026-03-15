import SwiftUI
import AppKit
import Carbon
import ServiceManagement
import Mixpanel

@main
struct AnyFloatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About AnyFloat") {
                    appDelegate.openAboutWindow()
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Preferences...") {
                    appDelegate.openPreferencesWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Reopen Closed Panel") {
                    appDelegate.reopenClosedPanel()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
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

private final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let recorder: HotKeyRecorderView
    private let launchAtLoginCheckbox: NSButton
    private let onHotKeyChanged: (HotKeyConfiguration) -> Void
    private let onLaunchAtLoginChanged: (Bool) -> Bool
    private let onWindowClosed: () -> Void

    init(
        hotKeyConfiguration: HotKeyConfiguration,
        launchAtLoginEnabled: Bool,
        onHotKeyChanged: @escaping (HotKeyConfiguration) -> Void,
        onLaunchAtLoginChanged: @escaping (Bool) -> Bool,
        onWindowClosed: @escaping () -> Void
    ) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        recorder = HotKeyRecorderView(
            configuration: hotKeyConfiguration,
            frame: NSRect(x: 0, y: 0, width: 320, height: 32)
        )
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: nil)
        self.onHotKeyChanged = onHotKeyChanged
        self.onLaunchAtLoginChanged = onLaunchAtLoginChanged
        self.onWindowClosed = onWindowClosed
        super.init()
        configureWindow(launchAtLoginEnabled: launchAtLoginEnabled)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func refresh(hotKeyConfiguration: HotKeyConfiguration, launchAtLoginEnabled: Bool) {
        recorder.setRecordedConfiguration(hotKeyConfiguration)
        launchAtLoginCheckbox.state = launchAtLoginEnabled ? .on : .off
    }

    func windowWillClose(_ notification: Notification) {
        onWindowClosed()
    }

    private func configureWindow(launchAtLoginEnabled: Bool) {
        window.title = "Preferences"
        window.isReleasedWhenClosed = false
        window.delegate = self

        let contentView = HotKeyRecorderContainerView(frame: NSRect(x: 0, y: 0, width: 460, height: 220))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        let hotKeyLabel = NSTextField(labelWithString: "Global Hotkey")
        hotKeyLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        hotKeyLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hotKeyLabel)

        let hotKeyHelpLabel = NSTextField(labelWithString: "Click the field and press your shortcut. Changes are saved immediately.")
        hotKeyHelpLabel.textColor = .secondaryLabelColor
        hotKeyHelpLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hotKeyHelpLabel)

        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.target = self
        recorder.action = #selector(handleHotKeyChanged)
        contentView.addSubview(recorder)

        let resetHotKeyButton = NSButton(title: "Reset Default", target: self, action: #selector(handleResetDefaultHotKey))
        resetHotKeyButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(resetHotKeyButton)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separator)

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(handleToggleLaunchAtLogin)
        launchAtLoginCheckbox.state = launchAtLoginEnabled ? .on : .off
        launchAtLoginCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(launchAtLoginCheckbox)

        NSLayoutConstraint.activate([
            hotKeyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            hotKeyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            hotKeyHelpLabel.topAnchor.constraint(equalTo: hotKeyLabel.bottomAnchor, constant: 8),
            hotKeyHelpLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            hotKeyHelpLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            recorder.topAnchor.constraint(equalTo: hotKeyHelpLabel.bottomAnchor, constant: 10),
            recorder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            recorder.widthAnchor.constraint(equalToConstant: 320),
            recorder.heightAnchor.constraint(equalToConstant: 32),

            resetHotKeyButton.centerYAnchor.constraint(equalTo: recorder.centerYAnchor),
            resetHotKeyButton.leadingAnchor.constraint(equalTo: recorder.trailingAnchor, constant: 12),
            resetHotKeyButton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),

            separator.topAnchor.constraint(equalTo: recorder.bottomAnchor, constant: 22),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            launchAtLoginCheckbox.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 16),
            launchAtLoginCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            launchAtLoginCheckbox.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    @objc private func handleHotKeyChanged() {
        onHotKeyChanged(recorder.recordedConfiguration)
    }

    @objc private func handleResetDefaultHotKey() {
        recorder.setRecordedConfiguration(HotKeyConfiguration.defaultValue)
        onHotKeyChanged(HotKeyConfiguration.defaultValue)
        window.makeFirstResponder(recorder)
    }

    @objc private func handleToggleLaunchAtLogin() {
        let nextValue = launchAtLoginCheckbox.state == .on
        let succeeded = onLaunchAtLoginChanged(nextValue)
        if !succeeded {
            launchAtLoginCheckbox.state = nextValue ? .off : .on
        }
    }
}

private struct HotKeyConfiguration: Codable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let defaultsKey = "globalHotKey.configuration"
    static let defaultValue = HotKeyConfiguration(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(shiftKey | optionKey))

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

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerRef: EventHandlerRef?
    private let panelController = FloatingPanelController()
    private var statusItem: NSStatusItem?
    private var reopenClosedPanelMenuItem: NSMenuItem?
    private var stashAllPanelsMenuItem: NSMenuItem?
    private var restoreAllPanelsMenuItem: NSMenuItem?
    private var arrangeWindowsMenuItem: NSMenuItem?
    private var preferencesWindowController: PreferencesWindowController?
    private var lastExternalAppPID: pid_t?
    private var hotKeyConfiguration = HotKeyConfiguration.loadFromDefaults()
    private var isConfiguringHotKey = false
    private let launchAtLoginDefaultsKey = "app.launchAtLoginEnabled"

    func applicationDidFinishLaunching(_ notification: Notification) {
        AnalyticsManager.shared.configure()
        NSApp.setActivationPolicy(.accessory)
        requestAccessibilityIfNeeded()
        seedLastExternalAppPID()
        observeFrontmostAppChanges()
        setupStatusItem()
        panelController.onStateChanged = { [weak self] state in
            self?.updatePanelMenuItems(state: state)
        }
        updatePanelMenuItems(state: panelController.currentState)
        #if !DEBUG
        applyLaunchAtLoginPreferenceOnLaunch()
        #endif
        scheduleHotKeyRegistration()
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotKey()
        AnalyticsManager.shared.track("app_quit", properties: ["axTrusted": AXIsProcessTrusted() ? 1 : 0])
        AnalyticsManager.shared.flush()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let state = panelController.currentState
        guard state.totalCount > 0 else {
            return .terminateNow
        }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Quit AnyFloat?"
        alert.informativeText = quitConfirmationText(for: state)
        alert.addButton(withTitle: "Cancel")
        let quitButton = alert.addButton(withTitle: "Quit")
        quitButton.hasDestructiveAction = true

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            return .terminateNow
        }
        return .terminateCancel
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

        let hotKeyID = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: "ANYF".fourCharCodeValue)), id: 1)
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
        showSelectedTextPanel(source: "hotkey")
    }

    private func showSelectedTextPanel(source: String) {
        refreshLastExternalAppPIDFromCurrentFrontmost()
        let selectedText = SelectedTextReader.readSelectedText(preferredAppPID: lastExternalAppPID)
        let text = selectedText ?? ""
        AnalyticsManager.shared.track(
            "main_window_open",
            properties: [
                "has_text": selectedText == nil ? 0 : 1,
                "source": source
            ]
        )
        panelController.show(text: text, keepUnfocusedOnOpen: selectedText != nil)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            if let image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: "AnyFloat") {
                image.isTemplate = true
                button.image = image
                button.imagePosition = .imageOnly
                button.toolTip = "AnyFloat"
            } else {
                // Keep a readable fallback if symbol loading fails.
                button.title = "AnyFloat"
            }
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Selected Text", action: #selector(handleShowSelectedText), keyEquivalent: ""))
        let reopenMenuItem = NSMenuItem(title: "Reopen Closed Panel", action: #selector(handleReopenClosedPanel), keyEquivalent: "T")
        reopenMenuItem.keyEquivalentModifierMask = [.command, .shift]
        let stashMenuItem = NSMenuItem(title: "Stash All Panels", action: #selector(handleStashAllPanels), keyEquivalent: "")
        let restoreMenuItem = NSMenuItem(title: "Restore All Panels", action: #selector(handleRestoreAllPanels), keyEquivalent: "")
        let arrangeMenuItem = NSMenuItem(title: "Arrange Windows", action: #selector(handleArrangeWindows), keyEquivalent: "")
        menu.addItem(reopenMenuItem)
        menu.addItem(stashMenuItem)
        menu.addItem(restoreMenuItem)
        menu.addItem(arrangeMenuItem)
        reopenClosedPanelMenuItem = reopenMenuItem
        stashAllPanelsMenuItem = stashMenuItem
        restoreAllPanelsMenuItem = restoreMenuItem
        arrangeWindowsMenuItem = arrangeMenuItem
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(handleOpenPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About AnyFloat", action: #selector(handleOpenAbout), keyEquivalent: ""))
        #if DEBUG
        let quitTitle = "Quit AnyFloat Debug"
        #else
        let quitTitle = "Quit AnyFloat"
        #endif
        menu.addItem(NSMenuItem(title: quitTitle, action: #selector(handleQuit), keyEquivalent: "q"))

        menu.delegate = self
        menu.items.forEach { $0.target = self }
        item.menu = menu
        self.statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        AnalyticsManager.shared.track("menu_clicked", properties: [:])
    }

    @objc private func handleShowSelectedText() {
        AnalyticsManager.shared.track("menu_item_clicked", properties: ["type": "show-main-window"])
        showSelectedTextPanel(source: "menuitem")
    }

    @objc private func handleStashAllPanels() {
        let state = panelController.currentState
        guard state.visibleCount > 0 else { return }
        panelController.stashAllPanels(anchorScreen: currentMouseScreen())
    }

    @objc private func handleReopenClosedPanel() {
        reopenClosedPanel()
    }

    @objc private func handleRestoreAllPanels() {
        let state = panelController.currentState
        guard state.stashedCount > 0 else { return }
        panelController.restoreAllPanels()
    }

    @objc private func handleArrangeWindows() {
        let state = panelController.currentState
        guard state.visibleCount > 0 || state.stashedCount > 0 else { return }
        panelController.arrangeVisibleWindows()
    }

    @objc private func handleQuit() {
        AnalyticsManager.shared.track("menu_item_clicked", properties: ["type": "quit"])
        NSApp.terminate(nil)
    }

    func openPreferencesWindow() {
        if let preferencesWindowController {
            preferencesWindowController.refresh(
                hotKeyConfiguration: hotKeyConfiguration,
                launchAtLoginEnabled: launchAtLoginPreference
            )
            isConfiguringHotKey = true
            preferencesWindowController.show()
            return
        }

        let controller = PreferencesWindowController(
            hotKeyConfiguration: hotKeyConfiguration,
            launchAtLoginEnabled: launchAtLoginPreference,
            onHotKeyChanged: { [weak self] configuration in
                self?.applyHotKeyConfiguration(configuration)
            },
            onLaunchAtLoginChanged: { [weak self] enabled in
                self?.applyLaunchAtLoginPreference(enabled) ?? false
            },
            onWindowClosed: { [weak self] in
                guard let self else { return }
                self.isConfiguringHotKey = false
                self.preferencesWindowController = nil
            }
        )
        preferencesWindowController = controller
        isConfiguringHotKey = true
        controller.show()
    }

    func openAboutWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let urlString = "https://github.com/fytriht/anyfloat"
        let creditsText = urlString
        let credits = NSMutableAttributedString(string: creditsText)
        if let url = URL(string: urlString) {
            let urlRange = (creditsText as NSString).range(of: urlString)
            if urlRange.location != NSNotFound {
                credits.addAttribute(.link, value: url, range: urlRange)
                credits.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: urlRange)
            }
        }

        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            NSApplication.AboutPanelOptionKey(rawValue: "Credits"): credits,
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2026 AnyFloat"
        ]
        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    @objc private func handleOpenPreferences() {
        AnalyticsManager.shared.track("menu_item_clicked", properties: ["type": "preferences"])
        openPreferencesWindow()
    }

    @objc private func handleOpenAbout() {
        AnalyticsManager.shared.track("menu_item_clicked", properties: ["type": "about"])
        openAboutWindow()
    }

    func reopenClosedPanel() {
        guard panelController.currentState.closedHistoryCount > 0 else { return }
        panelController.restoreLastClosedPanel()
    }

    private func applyHotKeyConfiguration(_ configuration: HotKeyConfiguration) {
        hotKeyConfiguration = configuration
        hotKeyConfiguration.persistToDefaults()
        AnalyticsManager.shared.track(
            "preferences_updated",
            properties: [
                "type": "hotkey"
            ]
        )
        registerHotKey()
    }

    private func applyLaunchAtLoginPreference(_ enabled: Bool) -> Bool {
        UserDefaults.standard.set(enabled, forKey: launchAtLoginDefaultsKey)
        do {
            try setLaunchAtLoginEnabled(enabled)
            AnalyticsManager.shared.track(
                "preferences_updated",
                properties: [
                    "type": "launch_at_login"
                ]
            )
            return true
        } catch {
            UserDefaults.standard.set(!enabled, forKey: launchAtLoginDefaultsKey)
            presentLaunchAtLoginError(error)
            return false
        }
    }

    private var launchAtLoginPreference: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: launchAtLoginDefaultsKey) == nil {
            defaults.set(true, forKey: launchAtLoginDefaultsKey)
            return true
        }
        return defaults.bool(forKey: launchAtLoginDefaultsKey)
    }

    private func applyLaunchAtLoginPreferenceOnLaunch() {
        do {
            try setLaunchAtLoginEnabled(launchAtLoginPreference)
        } catch {
            NSLog("Failed to apply launch-at-login preference: \(error.localizedDescription)")
        }
    }

    private func setLaunchAtLoginEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    private func presentLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Unable to Update Launch at Login"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func requestAccessibilityIfNeeded() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            NSLog("Accessibility permission not granted yet.")
        }
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

    private func updatePanelMenuItems(state: PanelControllerState) {
        reopenClosedPanelMenuItem?.isEnabled = state.closedHistoryCount > 0
        stashAllPanelsMenuItem?.isEnabled = state.visibleCount > 0
        restoreAllPanelsMenuItem?.isEnabled = state.stashedCount > 0
        arrangeWindowsMenuItem?.isEnabled = state.visibleCount > 0 || state.stashedCount > 0
    }

    private func quitConfirmationText(for state: PanelControllerState) -> String {
        let panelNoun = state.totalCount == 1 ? "floating panel" : "floating panels"
        return "You still have \(state.totalCount) \(panelNoun) open. Quit anyway?"
    }

    private func currentMouseScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
    }
}

private final class AnalyticsManager {
    static let shared = AnalyticsManager()

    private let infoPlistTokenKey = "MIXPANEL_PROJECT_TOKEN"
    private let envTokenKey = "MIXPANEL_PROJECT_TOKEN"
    private var isConfigured = false
    private var isEnabled = false

    private init() {}

    func configure() {
        guard !isConfigured else { return }
        isConfigured = true

        guard let token = resolveProjectToken(), !token.isEmpty else {
            NSLog("Mixpanel disabled: missing MIXPANEL_PROJECT_TOKEN.")
            return
        }

        Mixpanel.initialize(token: token)
        isEnabled = true

        let buildEnv: String
        #if DEBUG
        buildEnv = "debug"
        #else
        buildEnv = "release"
        #endif

        Mixpanel.mainInstance().registerSuperProperties([
            "app_platform": "macOS",
            "app_name": "AnyFloat",
            "env": buildEnv
        ])
        track("app_launch", properties: [:])
    }

    func track(_ event: String, properties: Properties) {
        guard isEnabled else { return }
        Mixpanel.mainInstance().track(event: event, properties: properties)
    }

    func flush() {
        guard isEnabled else { return }
        Mixpanel.mainInstance().flush()
    }

    private func resolveProjectToken() -> String? {
        let env = ProcessInfo.processInfo.environment
        if let token = env[envTokenKey]?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            return token
        }

        if let plistToken = Bundle.main.object(forInfoDictionaryKey: infoPlistTokenKey) as? String {
            let trimmed = plistToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }
}

private final class FloatingBorderlessPanel: NSPanel {
    var onCommandClose: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command,
           event.charactersIgnoringModifiers?.lowercased() == "w" {
            onCommandClose?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

private final class FloatingTextContent: ObservableObject {
    @Published var text: String

    init(text: String) {
        self.text = text
    }
}

private final class ModifierKeyState: ObservableObject {
    @Published var isOptionPressed = false
}

fileprivate struct PanelControllerState {
    let visibleCount: Int
    let stashedCount: Int
    let closedHistoryCount: Int
    let totalCount: Int
}

final class FloatingPanelController: NSObject, NSWindowDelegate {
    private struct ClosedPanelHistoryEntry {
        let text: String
    }

    private struct PanelContext {
        let panel: NSPanel
        let hostingView: NSHostingView<FloatingTextView>
        let textContent: FloatingTextContent
        var fontSize: CGFloat
        var lastContentWidth: CGFloat
        var isAutoHeightEnabled: Bool
    }

    fileprivate var onStateChanged: ((PanelControllerState) -> Void)?
    var hasVisiblePanels: Bool { currentState.visibleCount > 0 }
    var hasStashedPanels: Bool { currentState.stashedCount > 0 }
    fileprivate var currentState: PanelControllerState { makePanelState() }

    private var panelContexts: [ObjectIdentifier: PanelContext] = [:]
    private var stashedPanelIDs: Set<ObjectIdentifier> = []
    private var panelOrder: [ObjectIdentifier] = []
    private var panelDisplayIDs: [ObjectIdentifier: CGDirectDisplayID] = [:]
    private var closedPanelHistory: [ClosedPanelHistoryEntry] = []
    private var stashWidgetController: StashWidgetController?
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var preferredFontSize: CGFloat
    private let modifierKeyState = ModifierKeyState()

    private let maxClosedPanelHistoryCount = 20
    private let defaultFontSize: CGFloat = 12
    private let minFontSize: CGFloat = 8
    private let maxFontSize: CGFloat = 36
    private let fontSizeDefaultsKey = "floatingPanel.fontSize"
    private let minPanelSize = NSSize(width: 300, height: 120)
    private let maxPanelSize = NSSize(width: 600, height: 800)
    private let defaultPanelSize = NSSize(width: 300, height: 400)
    private let textHorizontalPadding: CGFloat = 32
    private let textVerticalPadding: CGFloat = 16
    private let textHeightSafetyInset: CGFloat = 36
    private let layoutEdgeMargin: CGFloat = 12
    private let arrangeGap: CGFloat = 12
    private let widgetToPanelGap: CGFloat = 12

    override init() {
        preferredFontSize = defaultFontSize
        super.init()
        let storedSize = UserDefaults.standard.object(forKey: fontSizeDefaultsKey) as? Double
        let initialSize = CGFloat(storedSize ?? Double(defaultFontSize))
        preferredFontSize = min(max(initialSize, minFontSize), maxFontSize)
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
        }
    }

    func show(text: String, keepUnfocusedOnOpen: Bool) {
        pruneDanglingPanelIDs()
        let context = createPanelContext(text: text, fontSize: preferredFontSize)
        let panel = context.panel
        let panelID = ObjectIdentifier(panel)
        panelContexts[panelID] = context
        panelOrder.removeAll { $0 == panelID }
        panelOrder.insert(panelID, at: 0)
        resetPanelSizeToDefault(panel, text: text, fontSize: preferredFontSize)
        positionNewPanel(panel, panelID: panelID)
        rememberPanelDisplayID(for: panel, panelID: panelID)
        _ = NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        refreshStashWidget(anchorScreen: nil)
        notifyStateChanged()
        guard keepUnfocusedOnOpen else { return }
        DispatchQueue.main.async { [weak panel] in
            panel?.makeFirstResponder(nil)
        }
    }

    func stashAllPanels(anchorScreen: NSScreen?) {
        pruneDanglingPanelIDs()
        let visiblePanelIDs = panelOrder.filter { panelID in
            panelContexts[panelID] != nil && !stashedPanelIDs.contains(panelID)
        }
        guard !visiblePanelIDs.isEmpty else { return }

        for panelID in visiblePanelIDs {
            guard let context = panelContexts[panelID] else { continue }
            rememberPanelDisplayID(for: context.panel, panelID: panelID)
            context.panel.orderOut(nil)
            stashedPanelIDs.insert(panelID)
        }

        refreshStashWidget(anchorScreen: anchorScreen)
        notifyStateChanged()
    }

    func restoreAllPanels() {
        pruneDanglingPanelIDs()
        guard !stashedPanelIDs.isEmpty else { return }

        let stashedOrderedPanelIDs = openingOrderPanelIDs(from: panelOrder.filter { panelID in
            panelContexts[panelID] != nil && stashedPanelIDs.contains(panelID)
        })
        for panelID in stashedOrderedPanelIDs {
            panelContexts[panelID]?.panel.orderFrontRegardless()
        }
        stashedPanelIDs.removeAll()

        let allPanelIDs = openingOrderPanelIDs(from: panelOrder.filter { panelContexts[$0] != nil })
        arrangePanelsAcrossScreens(panelIDs: allPanelIDs)
        refreshStashWidget(anchorScreen: nil)
        notifyStateChanged()
    }

    func arrangeVisibleWindows() {
        pruneDanglingPanelIDs()

        let visiblePanelIDs = openingOrderPanelIDs(from: panelOrder.filter { panelID in
            guard let context = panelContexts[panelID], !stashedPanelIDs.contains(panelID) else { return false }
            return context.panel.isVisible
        })

        let widgetScreen = stashWidgetController?.visibleScreen()
        let hasVisibleWidget = widgetScreen != nil
        guard !visiblePanelIDs.isEmpty || hasVisibleWidget else { return }

        if let widgetScreen {
            refreshStashWidget(anchorScreen: widgetScreen)
        }

        if !visiblePanelIDs.isEmpty {
            arrangeVisiblePanelsAcrossScreens(panelIDs: visiblePanelIDs)
        }

        notifyStateChanged()
    }

    func restoreLastClosedPanel() {
        guard let entry = closedPanelHistory.popLast() else { return }
        show(text: entry.text, keepUnfocusedOnOpen: false)
    }

    private func createPanelContext(text: String, fontSize: CGFloat) -> PanelContext {
        let textContent = FloatingTextContent(text: text)

        let panel = FloatingBorderlessPanel(
            contentRect: NSRect(origin: .zero, size: defaultPanelSize),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // .canJoinAllSpaces and .moveToActiveSpace are mutually exclusive.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.minSize = minPanelSize
        panel.maxSize = maxPanelSize
        panel.contentMinSize = minPanelSize
        panel.contentMaxSize = maxPanelSize
        panel.delegate = self
        panel.onCommandClose = { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.requestClose(for: panel)
        }

        let contentView = makeFloatingTextView(panel: panel, textContent: textContent, fontSize: fontSize)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hostingView
        installKeyMonitorIfNeeded()
        installFlagsMonitorIfNeeded()
        return PanelContext(
            panel: panel,
            hostingView: hostingView,
            textContent: textContent,
            fontSize: fontSize,
            lastContentWidth: defaultPanelSize.width,
            isAutoHeightEnabled: true
        )
    }

    private func resetPanelSizeToDefault(_ panel: NSPanel, text: String, fontSize: CGFloat) {
        let clampedContentHeight = clampedPanelHeight(for: text, fontSize: fontSize, contentWidth: defaultPanelSize.width)
        let targetContentSize = NSSize(width: defaultPanelSize.width, height: clampedContentHeight)
        let targetFrameSize = panel.frameRect(forContentRect: NSRect(origin: .zero, size: targetContentSize)).size
        panel.setFrame(
            NSRect(
                origin: panel.frame.origin,
                size: targetFrameSize
            ),
            display: true
        )
    }

    private func clampedPanelHeight(for text: String, fontSize: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let measuredHeight = measuredPanelHeight(for: text, fontSize: fontSize, contentWidth: contentWidth)
        return min(max(measuredHeight, minPanelSize.height), maxPanelSize.height)
    }

    private func measuredPanelHeight(for text: String, fontSize: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let textWidth = max(contentWidth - textHorizontalPadding, 1)
        let constraintRect = NSRect(
            x: 0,
            y: 0,
            width: textWidth,
            height: .greatestFiniteMagnitude
        )
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textBoundingRect = (text as NSString).boundingRect(
            with: constraintRect.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        let textHeight = ceil(textBoundingRect.height)
        return textHeight + textVerticalPadding + textHeightSafetyInset
    }

    private func resizePanelHeightToFitText(_ panel: NSPanel, text: String, fontSize: CGFloat) {
        let currentContentRect = panel.contentRect(forFrameRect: panel.frame)
        let targetContentHeight = clampedPanelHeight(
            for: text,
            fontSize: fontSize,
            contentWidth: currentContentRect.width
        )
        guard abs(targetContentHeight - currentContentRect.height) > 0.5 else { return }

        let targetContentRect = NSRect(
            x: 0,
            y: 0,
            width: currentContentRect.width,
            height: targetContentHeight
        )
        let targetFrameSize = panel.frameRect(forContentRect: targetContentRect).size
        var targetFrame = panel.frame
        let heightDelta = targetFrameSize.height - targetFrame.height
        targetFrame.size.height = targetFrameSize.height
        targetFrame.origin.y -= heightDelta
        targetFrame = constrainedFrameToVisibleArea(targetFrame, for: panel)
        panel.setFrame(targetFrame, display: true)
    }

    private func constrainedFrameToVisibleArea(_ frame: NSRect, for panel: NSPanel) -> NSRect {
        let visibleFrame = visibleFrameForPanel(panel)
        guard !visibleFrame.isEmpty else { return frame }

        var constrainedFrame = frame
        let maxOriginX = visibleFrame.maxX - constrainedFrame.width
        if maxOriginX >= visibleFrame.minX {
            constrainedFrame.origin.x = min(max(constrainedFrame.origin.x, visibleFrame.minX), maxOriginX)
        } else {
            constrainedFrame.origin.x = visibleFrame.minX
        }

        let maxOriginY = visibleFrame.maxY - constrainedFrame.height
        if maxOriginY >= visibleFrame.minY {
            constrainedFrame.origin.y = min(max(constrainedFrame.origin.y, visibleFrame.minY), maxOriginY)
        } else {
            constrainedFrame.origin.y = visibleFrame.minY
        }

        return constrainedFrame
    }

    private func visibleFrameForPanel(_ panel: NSPanel) -> NSRect {
        if let screen = panel.screen {
            return screen.visibleFrame
        }

        let panelCenter = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        if let screenContainingPanel = NSScreen.screens.first(where: { $0.frame.contains(panelCenter) }) {
            return screenContainingPanel.visibleFrame
        }

        return NSScreen.main?.visibleFrame ?? .zero
    }

    private func makeFloatingTextView(panel: NSPanel, textContent: FloatingTextContent, fontSize: CGFloat) -> FloatingTextView {
        FloatingTextView(
            textContent: textContent,
            modifierKeyState: modifierKeyState,
            fontSize: fontSize,
            onTextChange: { [weak self, weak panel] updatedText in
                guard let self, let panel else { return }
                let panelID = ObjectIdentifier(panel)
                guard let context = self.panelContexts[panelID], context.isAutoHeightEnabled else { return }
                self.resizePanelHeightToFitText(panel, text: updatedText, fontSize: context.fontSize)
            },
            onClosePanel: { [weak self, weak panel] in
                guard let self, let panel else { return }
                self.requestClose(for: panel)
            },
            onStashAllPanels: { [weak self, weak panel] in
                guard let self else { return }
                self.stashAllPanels(anchorScreen: panel?.screen)
            },
            onArrangePanels: { [weak self] in
                self?.arrangeVisibleWindows()
            },
            onCopyTextAndClose: { [weak self, weak panel] in
                guard let self, let panel else { return }
                self.copyTextAndClose(for: panel)
            }
        )
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(
            width: min(max(frameSize.width, minPanelSize.width), maxPanelSize.width),
            height: min(max(frameSize.height, minPanelSize.height), maxPanelSize.height)
        )
    }

    func windowDidResize(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }
        let panelID = ObjectIdentifier(panel)
        rememberPanelDisplayID(for: panel, panelID: panelID)
        guard var context = panelContexts[panelID] else { return }
        guard context.isAutoHeightEnabled else { return }

        let currentContentWidth = panel.contentRect(forFrameRect: panel.frame).width
        guard abs(currentContentWidth - context.lastContentWidth) > 0.5 else { return }

        context.lastContentWidth = currentContentWidth
        panelContexts[panelID] = context
        resizePanelHeightToFitText(panel, text: context.textContent.text, fontSize: context.fontSize)
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }
        let panelID = ObjectIdentifier(panel)
        rememberPanelDisplayID(for: panel, panelID: panelID)
    }

    func windowWillStartLiveResize(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }
        let panelID = ObjectIdentifier(panel)
        guard var context = panelContexts[panelID] else { return }
        guard context.isAutoHeightEnabled else { return }

        context.isAutoHeightEnabled = false
        context.lastContentWidth = panel.contentRect(forFrameRect: panel.frame).width
        panelContexts[panelID] = context
    }

    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }
        let panelID = ObjectIdentifier(panel)
        panelContexts.removeValue(forKey: panelID)
        stashedPanelIDs.remove(panelID)
        panelOrder.removeAll { $0 == panelID }
        panelDisplayIDs.removeValue(forKey: panelID)
        refreshStashWidget(anchorScreen: nil)
        notifyStateChanged()
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                let self,
                let panel = NSApp.keyWindow as? NSPanel,
                self.panelContexts[ObjectIdentifier(panel)] != nil
            else {
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers.contains(.command) else {
                return event
            }

            if modifiers == .command,
               event.charactersIgnoringModifiers?.lowercased() == "w" {
                self.requestClose(for: panel)
                return nil
            }

            switch event.keyCode {
            case UInt16(kVK_ANSI_0), UInt16(kVK_ANSI_Keypad0):
                self.resetFontSize(for: panel)
                return nil
            case UInt16(kVK_ANSI_Minus), UInt16(kVK_ANSI_KeypadMinus):
                self.adjustFontSize(by: -1, for: panel)
                return nil
            case UInt16(kVK_ANSI_Equal), UInt16(kVK_ANSI_KeypadPlus):
                self.adjustFontSize(by: 1, for: panel)
                return nil
            default:
                return event
            }
        }
    }

    private func installFlagsMonitorIfNeeded() {
        guard flagsMonitor == nil else { return }

        modifierKeyState.isOptionPressed = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.option)
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.modifierKeyState.isOptionPressed = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .contains(.option)
            return event
        }
    }

    private func copyTextAndClose(for panel: NSPanel) {
        let panelID = ObjectIdentifier(panel)
        guard let context = panelContexts[panelID] else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(context.textContent.text, forType: .string)
        requestClose(for: panel)
    }

    private func adjustFontSize(by delta: CGFloat, for panel: NSPanel) {
        let panelID = ObjectIdentifier(panel)
        guard var context = panelContexts[panelID] else { return }
        let nextSize = min(max(context.fontSize + delta, minFontSize), maxFontSize)
        guard nextSize != context.fontSize else { return }

        context.fontSize = nextSize
        context.hostingView.rootView = makeFloatingTextView(panel: panel, textContent: context.textContent, fontSize: nextSize)
        panelContexts[panelID] = context
        if context.isAutoHeightEnabled {
            resizePanelHeightToFitText(panel, text: context.textContent.text, fontSize: nextSize)
        }
        preferredFontSize = nextSize
        persistFontSize()
    }

    private func resetFontSize(for panel: NSPanel) {
        let panelID = ObjectIdentifier(panel)
        guard var context = panelContexts[panelID] else { return }
        guard context.fontSize != defaultFontSize else { return }

        context.fontSize = defaultFontSize
        context.hostingView.rootView = makeFloatingTextView(
            panel: panel,
            textContent: context.textContent,
            fontSize: defaultFontSize
        )
        panelContexts[panelID] = context
        if context.isAutoHeightEnabled {
            resizePanelHeightToFitText(panel, text: context.textContent.text, fontSize: defaultFontSize)
        }
        preferredFontSize = defaultFontSize
        persistFontSize()
    }

    private func persistFontSize() {
        UserDefaults.standard.set(Double(preferredFontSize), forKey: fontSizeDefaultsKey)
    }

    private func positionNewPanel(_ panel: NSPanel, panelID: ObjectIdentifier) {
        guard let targetScreen = screenForCurrentMouse() ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visibleFrame = targetScreen.visibleFrame
        guard !visibleFrame.isEmpty else { return }
        let targetDisplayID = displayID(for: targetScreen)

        let visiblePanelIDsOnScreen = panelOrder.filter { existingPanelID in
            guard
                existingPanelID != panelID,
                let context = panelContexts[existingPanelID],
                !stashedPanelIDs.contains(existingPanelID),
                context.panel.isVisible
            else {
                return false
            }

            let panelCenter = NSPoint(x: context.panel.frame.midX, y: context.panel.frame.midY)
            let existingDisplayID = panelDisplayIDs[existingPanelID]
                ?? displayID(for: context.panel.screen)
                ?? displayID(forPoint: panelCenter)
            return existingDisplayID == targetDisplayID
        }

        var existingFrames = visiblePanelIDsOnScreen.compactMap { panelContexts[$0]?.panel.frame }
        let stashWidgetFrame = stashWidgetController?.visibleFrame(on: targetScreen)
        if let stashWidgetFrame {
            existingFrames.append(stashWidgetFrame)
        }
        let existingSizes = visiblePanelIDsOnScreen.compactMap { panelContexts[$0]?.panel.frame.size }
        let panelSize = panel.frame.size

        if let stashWidgetFrame,
           let anchoredFrame = anchoredFrameInWidgetColumn(
                stashWidgetFrame: stashWidgetFrame,
                visiblePanelIDsOnScreen: visiblePanelIDsOnScreen,
                targetScreen: targetScreen,
                panelSize: panelSize,
                in: visibleFrame
           ),
           existingFrames.allSatisfy({ !$0.intersects(anchoredFrame) }) {
            panel.setFrameOrigin(anchoredFrame.origin)
            return
        }

        var extraSlotsNeeded = 1
        var attemptedOriginKeys: Set<String> = []
        while true {
            let candidateSizes = existingSizes + Array(repeating: panelSize, count: extraSlotsNeeded)
            guard let candidateOrigin = panelLayoutOrigins(for: candidateSizes, in: visibleFrame).last else { return }
            let candidateOriginKey = originKey(for: candidateOrigin)
            guard attemptedOriginKeys.insert(candidateOriginKey).inserted else {
                // Once layout generation starts repeating origins, no additional slot can be found.
                panel.setFrameOrigin(candidateOrigin)
                return
            }

            let candidateFrame = NSRect(origin: candidateOrigin, size: panelSize)
            if existingFrames.allSatisfy({ !$0.intersects(candidateFrame) }) {
                panel.setFrameOrigin(candidateOrigin)
                return
            }

            extraSlotsNeeded += 1
        }
    }

    private func arrangePanelsAcrossScreens(panelIDs: [ObjectIdentifier]) {
        guard !panelIDs.isEmpty else { return }

        var groupedPanelIDs: [CGDirectDisplayID: [ObjectIdentifier]] = [:]
        var fallbackPanelIDs: [ObjectIdentifier] = []

        for panelID in panelIDs {
            guard let context = panelContexts[panelID] else { continue }
            let panelCenter = NSPoint(x: context.panel.frame.midX, y: context.panel.frame.midY)
            let displayID = panelDisplayIDs[panelID]
                ?? displayID(for: context.panel.screen)
                ?? displayID(forPoint: panelCenter)

            if let displayID {
                groupedPanelIDs[displayID, default: []].append(panelID)
            } else {
                fallbackPanelIDs.append(panelID)
            }
        }

        if !fallbackPanelIDs.isEmpty {
            if let fallbackDisplayID = displayID(for: NSScreen.main ?? NSScreen.screens.first) {
                groupedPanelIDs[fallbackDisplayID, default: []].append(contentsOf: fallbackPanelIDs)
            } else if let fallbackScreen = NSScreen.main ?? NSScreen.screens.first {
                arrangePanels(panelIDs: fallbackPanelIDs, on: fallbackScreen)
            }
        }

        for screen in NSScreen.screens {
            guard
                let screenDisplayID = displayID(for: screen),
                let ids = groupedPanelIDs.removeValue(forKey: screenDisplayID)
            else { continue }
            arrangePanels(panelIDs: ids, on: screen)
        }

        if !groupedPanelIDs.isEmpty, let fallbackScreen = NSScreen.main ?? NSScreen.screens.first {
            for (_, ids) in groupedPanelIDs {
                arrangePanels(panelIDs: ids, on: fallbackScreen)
            }
        }
    }

    private func arrangeVisiblePanelsAcrossScreens(panelIDs: [ObjectIdentifier]) {
        guard !panelIDs.isEmpty else { return }

        var groupedPanelIDs: [CGDirectDisplayID: [ObjectIdentifier]] = [:]
        var fallbackPanelIDs: [ObjectIdentifier] = []

        for panelID in panelIDs {
            guard let context = panelContexts[panelID] else { continue }
            let panelCenter = NSPoint(x: context.panel.frame.midX, y: context.panel.frame.midY)
            let displayID = panelDisplayIDs[panelID]
                ?? displayID(for: context.panel.screen)
                ?? displayID(forPoint: panelCenter)

            if let displayID {
                groupedPanelIDs[displayID, default: []].append(panelID)
            } else {
                fallbackPanelIDs.append(panelID)
            }
        }

        if !fallbackPanelIDs.isEmpty {
            if let fallbackDisplayID = displayID(for: NSScreen.main ?? NSScreen.screens.first) {
                groupedPanelIDs[fallbackDisplayID, default: []].append(contentsOf: fallbackPanelIDs)
            } else if let fallbackScreen = NSScreen.main ?? NSScreen.screens.first {
                arrangeVisiblePanels(panelIDs: fallbackPanelIDs, on: fallbackScreen)
            }
        }

        for screen in NSScreen.screens {
            guard
                let screenDisplayID = displayID(for: screen),
                let ids = groupedPanelIDs.removeValue(forKey: screenDisplayID)
            else { continue }
            arrangeVisiblePanels(panelIDs: ids, on: screen)
        }

        if !groupedPanelIDs.isEmpty, let fallbackScreen = NSScreen.main ?? NSScreen.screens.first {
            for (_, ids) in groupedPanelIDs {
                arrangeVisiblePanels(panelIDs: ids, on: fallbackScreen)
            }
        }
    }

    private func arrangeVisiblePanels(panelIDs: [ObjectIdentifier], on screen: NSScreen) {
        guard !panelIDs.isEmpty else { return }

        let layoutFrame = screen.visibleFrame
        guard layoutFrame.width > 0, layoutFrame.height > 0 else { return }

        if let stashWidgetFrame = stashWidgetController?.visibleFrame(on: screen) {
            var placedFrames: [NSRect] = [stashWidgetFrame]
            for panelID in panelIDs {
                guard let panel = panelContexts[panelID]?.panel else { continue }
                let panelSize = panel.frame.size

                if let anchoredFrame = anchoredFrameInWidgetColumn(
                    stashWidgetFrame: stashWidgetFrame,
                    panelFrames: placedFrames,
                    targetScreen: screen,
                    panelSize: panelSize,
                    in: layoutFrame
                ) {
                    panel.setFrameOrigin(anchoredFrame.origin)
                    placedFrames.append(anchoredFrame)
                    rememberPanelDisplayID(for: panel, panelID: panelID)
                    continue
                }

                let panelSizes = panelIDs.compactMap { panelContexts[$0]?.panel.frame.size }
                let origins = panelLayoutOrigins(for: panelSizes, in: layoutFrame)
                for (fallbackPanelID, origin) in zip(panelIDs, origins) {
                    guard let fallbackPanel = panelContexts[fallbackPanelID]?.panel else { continue }
                    fallbackPanel.setFrameOrigin(origin)
                    rememberPanelDisplayID(for: fallbackPanel, panelID: fallbackPanelID)
                }
                return
            }
            return
        }

        arrangePanels(panelIDs: panelIDs, on: screen)
    }

    private func arrangePanels(panelIDs: [ObjectIdentifier], on screen: NSScreen) {
        guard !panelIDs.isEmpty else { return }

        let layoutFrame = screen.visibleFrame
        guard layoutFrame.width > 0, layoutFrame.height > 0 else { return }

        let panelSizes = panelIDs.compactMap { panelContexts[$0]?.panel.frame.size }
        let origins = panelLayoutOrigins(for: panelSizes, in: layoutFrame)

        for (panelID, origin) in zip(panelIDs, origins) {
            guard let panel = panelContexts[panelID]?.panel else { continue }
            panel.setFrameOrigin(origin)
            rememberPanelDisplayID(for: panel, panelID: panelID)
        }
    }

    private func panelLayoutOrigins(for panelSizes: [NSSize], in layoutFrame: NSRect) -> [NSPoint] {
        guard !panelSizes.isEmpty else { return [] }
        let insetLayoutFrame = layoutFrame.insetBy(dx: layoutEdgeMargin, dy: layoutEdgeMargin)
        guard insetLayoutFrame.width > 0, insetLayoutFrame.height > 0 else { return [] }

        var origins: [NSPoint] = []
        var currentRightEdgeX = insetLayoutFrame.maxX
        var currentTopY = insetLayoutFrame.maxY
        var currentColumnMaxWidth: CGFloat = 0

        for panelSize in panelSizes {
            var candidateY = currentTopY - panelSize.height
            if candidateY < insetLayoutFrame.minY {
                currentRightEdgeX -= (currentColumnMaxWidth + arrangeGap)
                currentTopY = insetLayoutFrame.maxY
                currentColumnMaxWidth = 0
                candidateY = currentTopY - panelSize.height
            }

            let candidateX = max(insetLayoutFrame.minX, currentRightEdgeX - panelSize.width)
            origins.append(NSPoint(x: candidateX, y: max(insetLayoutFrame.minY, candidateY)))

            currentTopY = candidateY - arrangeGap
            currentColumnMaxWidth = max(currentColumnMaxWidth, panelSize.width)
        }

        return origins
    }

    private func anchoredPanelFrame(below anchorFrame: NSRect, panelSize: NSSize, in visibleFrame: NSRect) -> NSRect? {
        var candidateOrigin = NSPoint(
            x: anchorFrame.maxX - panelSize.width,
            y: anchorFrame.minY - widgetToPanelGap - panelSize.height
        )
        let minX = visibleFrame.minX + layoutEdgeMargin
        let maxX = visibleFrame.maxX - layoutEdgeMargin - panelSize.width
        let minY = visibleFrame.minY + layoutEdgeMargin
        let maxY = visibleFrame.maxY - layoutEdgeMargin - panelSize.height

        guard maxX >= minX, maxY >= minY else { return nil }

        candidateOrigin.x = min(max(candidateOrigin.x, minX), maxX)
        candidateOrigin.y = min(max(candidateOrigin.y, minY), maxY)

        let candidateFrame = NSRect(origin: candidateOrigin, size: panelSize)
        guard candidateFrame.maxY <= anchorFrame.minY - widgetToPanelGap + 0.5 else { return nil }
        return candidateFrame
    }

    private func anchoredFrameInWidgetColumn(
        stashWidgetFrame: NSRect,
        visiblePanelIDsOnScreen: [ObjectIdentifier],
        targetScreen: NSScreen,
        panelSize: NSSize,
        in visibleFrame: NSRect
    ) -> NSRect? {
        let panelFrames = visiblePanelIDsOnScreen.compactMap { panelContexts[$0]?.panel.frame }
        let anchorFrame = widgetColumnAnchorFrame(
            stashWidgetFrame: stashWidgetFrame,
            panelFrames: panelFrames,
            targetScreen: targetScreen
        )
        return anchoredPanelFrame(below: anchorFrame, panelSize: panelSize, in: visibleFrame)
    }

    private func anchoredFrameInWidgetColumn(
        stashWidgetFrame: NSRect,
        panelFrames: [NSRect],
        targetScreen: NSScreen,
        panelSize: NSSize,
        in visibleFrame: NSRect
    ) -> NSRect? {
        let anchorFrame = widgetColumnAnchorFrame(
            stashWidgetFrame: stashWidgetFrame,
            panelFrames: panelFrames,
            targetScreen: targetScreen
        )
        return anchoredPanelFrame(below: anchorFrame, panelSize: panelSize, in: visibleFrame)
    }

    private func widgetColumnAnchorFrame(
        stashWidgetFrame: NSRect,
        panelFrames: [NSRect],
        targetScreen: NSScreen
    ) -> NSRect {
        let alignmentTolerance: CGFloat = 1
        let gapTolerance: CGFloat = 1
        let targetRightEdge = stashWidgetFrame.maxX
        var anchorFrame = stashWidgetFrame

        while true {
            guard let nextFrame = panelFrames
                .filter({
                    abs($0.maxX - targetRightEdge) <= alignmentTolerance &&
                    abs($0.maxY - (anchorFrame.minY - widgetToPanelGap)) <= gapTolerance &&
                    visibleFrameContainsFrame($0, on: targetScreen)
                })
                .min(by: { $0.minY > $1.minY }) else {
                return anchorFrame
            }

            anchorFrame = nextFrame
        }
    }

    private func visibleFrameContainsFrame(_ frame: NSRect, on screen: NSScreen) -> Bool {
        screen.visibleFrame.contains(frame)
    }

    private func openingOrderPanelIDs(from panelIDs: [ObjectIdentifier]) -> [ObjectIdentifier] {
        Array(panelIDs.reversed())
    }

    private func originKey(for point: NSPoint) -> String {
        "\(point.x.rounded())_\(point.y.rounded())"
    }

    private func screenForCurrentMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
    }

    private func ensureStashWidgetController() -> StashWidgetController {
        if let stashWidgetController {
            return stashWidgetController
        }

        let controller = StashWidgetController { [weak self] in
            guard let self else { return }
            self.restoreAllPanels()
        }
        stashWidgetController = controller
        return controller
    }

    private func refreshStashWidget(anchorScreen: NSScreen?) {
        let stashedCount = stashedPanelIDs.count
        guard stashedCount > 0 else {
            stashWidgetController?.hide()
            return
        }
        let controller = ensureStashWidgetController()
        controller.show(hiddenCount: stashedCount, anchorScreen: anchorScreen)
    }

    private func notifyStateChanged() {
        onStateChanged?(makePanelState())
    }

    private func makePanelState() -> PanelControllerState {
        pruneDanglingPanelIDs()
        let visibleCount = panelOrder.filter { panelID in
            guard let context = panelContexts[panelID], !stashedPanelIDs.contains(panelID) else { return false }
            return context.panel.isVisible
        }.count
        return PanelControllerState(
            visibleCount: visibleCount,
            stashedCount: stashedPanelIDs.count,
            closedHistoryCount: closedPanelHistory.count,
            totalCount: panelContexts.count
        )
    }

    private func requestClose(for panel: NSPanel) {
        let panelID = ObjectIdentifier(panel)
        guard let context = panelContexts[panelID] else { return }
        let text = context.textContent.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            closedPanelHistory.append(ClosedPanelHistoryEntry(text: context.textContent.text))
        }
        if closedPanelHistory.count > maxClosedPanelHistoryCount {
            closedPanelHistory.removeFirst(closedPanelHistory.count - maxClosedPanelHistoryCount)
        }
        notifyStateChanged()
        panel.close()
    }

    private func pruneDanglingPanelIDs() {
        let existingIDs = Set(panelContexts.keys)
        stashedPanelIDs.formIntersection(existingIDs)
        panelOrder = panelOrder.filter { existingIDs.contains($0) }
        panelDisplayIDs = panelDisplayIDs.filter { existingIDs.contains($0.key) }
    }

    private func rememberPanelDisplayID(for panel: NSPanel, panelID: ObjectIdentifier) {
        let panelCenter = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        if let id = displayID(for: panel.screen) ?? displayID(forPoint: panelCenter) {
            panelDisplayIDs[panelID] = id
        }
    }

    private func displayID(for screen: NSScreen?) -> CGDirectDisplayID? {
        guard
            let screen,
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func displayID(forPoint point: NSPoint) -> CGDirectDisplayID? {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        return displayID(for: screen)
    }
}

private final class StashWidgetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class StashWidgetController {
    private static let defaultWidgetSize = NSSize(width: 100, height: 44)
    private let widgetSize = StashWidgetController.defaultWidgetSize
    private let edgeMargin: CGFloat = 12
    private let onActivate: () -> Void

    private var panel: StashWidgetPanel?
    private var hostingView: NSHostingView<StashWidgetView>?

    init(onActivate: @escaping () -> Void) {
        self.onActivate = onActivate
    }

    func show(hiddenCount: Int, anchorScreen: NSScreen?) {
        guard hiddenCount > 0 else {
            hide()
            return
        }

        let panel = ensurePanel(hiddenCount: hiddenCount)
        hostingView?.rootView = StashWidgetView(
            hiddenCount: hiddenCount,
            onActivate: onActivate,
            widgetSize: widgetSize
        )
        constrain(panel: panel, anchorScreen: anchorScreen)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func visibleScreen() -> NSScreen? {
        guard let panel, panel.isVisible else { return nil }

        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return screen
        }

        return panel.screen ?? NSScreen.main
    }

    func visibleFrame(on screen: NSScreen) -> NSRect? {
        guard let panel, panel.isVisible else { return nil }

        let targetVisibleFrame = screen.visibleFrame
        let panelCenter = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        guard targetVisibleFrame.contains(panelCenter) else { return nil }

        return panel.frame
    }

    private func ensurePanel(hiddenCount: Int) -> StashWidgetPanel {
        if let panel {
            return panel
        }

        let panel = StashWidgetPanel(
            contentRect: NSRect(origin: .zero, size: widgetSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.setFrame(NSRect(origin: .zero, size: widgetSize), display: true)

        let hostingView = NSHostingView(
            rootView: StashWidgetView(
                hiddenCount: hiddenCount,
                onActivate: onActivate,
                widgetSize: widgetSize
            )
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hostingView

        self.panel = panel
        self.hostingView = hostingView
        return panel
    }

    private func constrain(panel: NSPanel, anchorScreen: NSScreen?) {
        let visibleFrame = targetVisibleFrame(for: panel, anchorScreen: anchorScreen)
        guard !visibleFrame.isEmpty else { return }

        var frame = panel.frame
        frame.size = widgetSize
        frame.origin.x = visibleFrame.maxX - widgetSize.width - edgeMargin
        frame.origin.y = visibleFrame.maxY - widgetSize.height - edgeMargin

        let minX = visibleFrame.minX
        let maxX = visibleFrame.maxX - frame.width
        let minY = visibleFrame.minY
        let maxY = visibleFrame.maxY - frame.height
        frame.origin.x = min(max(frame.origin.x, minX), maxX)
        frame.origin.y = min(max(frame.origin.y, minY), maxY)
        panel.setFrame(frame, display: true)
    }

    private func targetVisibleFrame(for panel: NSPanel, anchorScreen: NSScreen?) -> NSRect {
        if let anchorScreen {
            return anchorScreen.visibleFrame
        }
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return screen.visibleFrame
        }
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return screen.visibleFrame
        }
        return NSScreen.main?.visibleFrame ?? .zero
    }
}

private struct StashWidgetView: View {
    let hiddenCount: Int
    let onActivate: () -> Void
    let widgetSize: NSSize

    var body: some View {
        ZStack {
            WhiteBlurBackground(cornerRadius: 12, whiteOpacity: 0.5, blurOpacity: 0.65)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)

            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                Text("\(hiddenCount) stashed")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(NSColor.labelColor))
            }

            StashWidgetInteractionHandle(onActivate: onActivate)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: widgetSize.width, height: widgetSize.height)
    }
}

private struct WhiteBlurBackground: View {
    let cornerRadius: CGFloat
    let whiteOpacity: CGFloat
    let blurOpacity: CGFloat

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                .opacity(blurOpacity)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(whiteOpacity))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.material = material
        view.blendingMode = blendingMode
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

private struct StashWidgetInteractionHandle: NSViewRepresentable {
    let onActivate: () -> Void

    func makeNSView(context: Context) -> InteractionView {
        InteractionView(onActivate: onActivate)
    }

    func updateNSView(_ nsView: InteractionView, context: Context) {
        nsView.onActivate = onActivate
    }

    final class InteractionView: NSView {
        var onActivate: () -> Void
        private let dragThreshold: CGFloat = 4
        private var mouseDownLocation: NSPoint?
        private var windowOriginAtMouseDown: NSPoint = .zero
        private var didDrag = false

        init(onActivate: @escaping () -> Void) {
            self.onActivate = onActivate
            super.init(frame: .zero)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownLocation = NSEvent.mouseLocation
            windowOriginAtMouseDown = window?.frame.origin ?? .zero
            didDrag = false
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window, let start = mouseDownLocation else { return }
            let current = NSEvent.mouseLocation
            let deltaX = current.x - start.x
            let deltaY = current.y - start.y
            if !didDrag {
                didDrag = hypot(deltaX, deltaY) >= dragThreshold
            }
            guard didDrag else { return }
            let proposedOrigin = NSPoint(
                x: windowOriginAtMouseDown.x + deltaX,
                y: windowOriginAtMouseDown.y + deltaY
            )
            window.setFrameOrigin(clampedOrigin(for: window, proposedOrigin: proposedOrigin))
        }

        override func mouseUp(with event: NSEvent) {
            defer {
                mouseDownLocation = nil
                didDrag = false
            }
            if didDrag {
                if let window {
                    window.setFrameOrigin(clampedOrigin(for: window, proposedOrigin: window.frame.origin))
                }
                return
            }
            if let start = mouseDownLocation {
                let end = NSEvent.mouseLocation
                let distance = hypot(end.x - start.x, end.y - start.y)
                if distance >= dragThreshold {
                    return
                }
            }
            if window != nil {
                onActivate()
            }
        }

        private func clampedOrigin(for window: NSWindow, proposedOrigin: NSPoint) -> NSPoint {
            var proposedFrame = window.frame
            proposedFrame.origin = proposedOrigin

            let visibleFrame = targetVisibleFrame(for: window, proposedFrame: proposedFrame)
            guard !visibleFrame.isEmpty else { return proposedOrigin }

            let minX = visibleFrame.minX
            let maxX = max(minX, visibleFrame.maxX - proposedFrame.width)
            let minY = visibleFrame.minY
            let maxY = max(minY, visibleFrame.maxY - proposedFrame.height)
            return NSPoint(
                x: min(max(proposedOrigin.x, minX), maxX),
                y: min(max(proposedOrigin.y, minY), maxY)
            )
        }

        private func targetVisibleFrame(for window: NSWindow, proposedFrame: NSRect) -> NSRect {
            let proposedCenter = NSPoint(x: proposedFrame.midX, y: proposedFrame.midY)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(proposedCenter) }) {
                return screen.visibleFrame
            }

            let mouseLocation = NSEvent.mouseLocation
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
                return screen.visibleFrame
            }

            return window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        }
    }
}

private struct FloatingTextView: View {
    @ObservedObject var textContent: FloatingTextContent
    @ObservedObject var modifierKeyState: ModifierKeyState
    let fontSize: CGFloat
    let onTextChange: (String) -> Void
    let onClosePanel: () -> Void
    let onStashAllPanels: () -> Void
    let onArrangePanels: () -> Void
    let onCopyTextAndClose: () -> Void
    @State private var isTopBarHovering = false
    private let cornerRadius: CGFloat = 16
    private let topBarHeight: CGFloat = 36
    private let edgeDragThickness: CGFloat = 12
    private let bottomEdgeDragThickness: CGFloat = 16
    private var isAlternateThirdButtonMode: Bool {
        isTopBarHovering && modifierKeyState.isOptionPressed
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            HStack(spacing: 0) {
                WindowDragHandle()
                    .frame(width: edgeDragThickness)
                contentEditor
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            WindowDragHandle()
                .frame(height: bottomEdgeDragThickness)
        }
        .background(
            WhiteBlurBackground(cornerRadius: cornerRadius, whiteOpacity: 0.5, blurOpacity: 0.65)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var contentEditor: some View {
        TextEditor(text: $textContent.text)
            .font(.system(size: fontSize, weight: .regular, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .onChange(of: textContent.text) { updatedText in
                onTextChange(updatedText)
            }
    }

    private var topBar: some View {
        ZStack(alignment: .leading) {
            WindowDragHandle()
            HStack {
                HStack(spacing: 6) {
                    DrawnCloseButton(showsIcon: isTopBarHovering, action: onClosePanel)
                    DrawnStashAllButton(showsIcon: isTopBarHovering, action: onStashAllPanels)
                    DrawnThirdActionButton(
                        showsIcon: isTopBarHovering,
                        isAlternate: isAlternateThirdButtonMode,
                        defaultAction: onArrangePanels,
                        alternateAction: onCopyTextAndClose
                    )
                }
                .onHover { hovering in
                    isTopBarHovering = hovering
                }
                Spacer()
            }
            .padding(.horizontal, 12)
        }
        .frame(height: topBarHeight)
    }
}

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView {
        DragHandleView()
    }

    func updateNSView(_ nsView: DragHandleView, context: Context) {}

    final class DragHandleView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

private struct DrawnCloseButton: View {
    private let size: CGFloat = 14
    private let iconSize: CGFloat = 8.5
    private let buttonWhite: CGFloat = 0.35
    private let defaultAlpha: CGFloat = 0.58
    private let hoverAlpha: CGFloat = 0.78
    @State private var isHovered = false
    let showsIcon: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(buttonColor)
                Image(systemName: "xmark")
                    .font(.system(size: iconSize, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .opacity(showsIcon ? 1 : 0)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .help("Close Panel")
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("Close panel")
    }

    private var buttonColor: Color {
        Color(NSColor(calibratedWhite: buttonWhite, alpha: isHovered ? hoverAlpha : defaultAlpha))
    }
}

private struct DrawnStashAllButton: View {
    private let size: CGFloat = 14
    private let iconSize: CGFloat = 9
    private let buttonWhite: CGFloat = 0.45
    private let defaultAlpha: CGFloat = 0.58
    private let hoverAlpha: CGFloat = 0.78
    @State private var isHovered = false
    let showsIcon: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(buttonColor)
                Image(systemName: "minus")
                    .font(.system(size: iconSize, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .opacity(showsIcon ? 1 : 0)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .help("Stash All Panels")
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("Stash all panels")
    }

    private var buttonColor: Color {
        Color(NSColor(calibratedWhite: buttonWhite, alpha: isHovered ? hoverAlpha : defaultAlpha))
    }
}

private struct DrawnThirdActionButton: View {
    private let size: CGFloat = 14
    private let defaultIconSize: CGFloat = 8.5
    private let alternateIconSize: CGFloat = 7.5
    private let buttonWhite: CGFloat = 0.55
    private let defaultAlpha: CGFloat = 0.58
    private let hoverAlpha: CGFloat = 0.78
    @State private var isHovered = false
    let showsIcon: Bool
    let isAlternate: Bool
    let defaultAction: () -> Void
    let alternateAction: () -> Void

    var body: some View {
        Button(action: isAlternate ? alternateAction : defaultAction) {
            ZStack {
                Circle()
                    .fill(buttonColor)
                Image(systemName: isAlternate ? "square.on.square" : "arrow.up.right")
                    .font(.system(size: isAlternate ? alternateIconSize : defaultIconSize, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .opacity(showsIcon ? 1 : 0)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .help(isAlternate ? "Copy Text and Close" : "Arrange Windows")
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(isAlternate ? "Copy text and close" : "Arrange windows")
    }

    private var buttonColor: Color {
        Color(NSColor(calibratedWhite: buttonWhite, alpha: isHovered ? hoverAlpha : defaultAlpha))
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

        // 1) Then try the latest known non-AnyFloat app PID.
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
