import AppKit

final class SettingsWindowController: NSWindowController {
    private let pathLabel = NSTextField(labelWithString: "")
    private let autoSaveCheckbox = NSButton(
        checkboxWithTitle: "Guardar y cerrar automáticamente las miniaturas",
        target: nil,
        action: nil
    )
    private let secondsField = NSTextField()
    private let secondsStepper = NSStepper()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 245),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ajustes de ScreenshotShelf"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildInterface()
        loadValues()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildInterface() {
        guard let content = window?.contentView else { return }

        let title = NSTextField(labelWithString: "Ubicación predeterminada")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.textColor = .secondaryLabelColor

        let choose = NSButton(
            title: "Seleccionar…",
            target: self,
            action: #selector(selectDirectory)
        )

        autoSaveCheckbox.target = self
        autoSaveCheckbox.action = #selector(changeAutoSave)

        let secondsTitle = NSTextField(labelWithString: "Cerrar después de:")
        secondsField.alignment = .right
        secondsField.target = self
        secondsField.action = #selector(changeSeconds)
        secondsField.widthAnchor.constraint(equalToConstant: 58).isActive = true

        secondsStepper.minValue = 1
        secondsStepper.maxValue = 3600
        secondsStepper.increment = 1
        secondsStepper.target = self
        secondsStepper.action = #selector(stepSeconds)

        let secondsLabel = NSTextField(labelWithString: "segundos")
        let secondsRow = NSStackView(views: [
            secondsTitle, secondsField, secondsStepper, secondsLabel
        ])
        secondsRow.orientation = .horizontal
        secondsRow.alignment = .centerY
        secondsRow.spacing = 8

        let locationRow = NSStackView(views: [pathLabel, choose])
        locationRow.orientation = .horizontal
        locationRow.alignment = .centerY
        locationRow.spacing = 12

        let note = NSTextField(
            wrappingLabelWithString:
                "Al vencer el tiempo, la captura se guarda en la ubicación predeterminada y la miniatura se cierra."
        )
        note.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            title, locationRow, separator(), autoSaveCheckbox, secondsRow, note
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            pathLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
            locationRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            note.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: 512).isActive = true
        return box
    }

    private func loadValues() {
        pathLabel.stringValue = screenshotDirectory().path
        let enabled = UserDefaults.standard.bool(forKey: autoSaveEnabledKey)
        autoSaveCheckbox.state = enabled ? .on : .off
        let seconds = configuredAutoSaveSeconds()
        secondsField.integerValue = Int(seconds)
        secondsStepper.doubleValue = seconds
        setSecondsEnabled(enabled)
    }

    private func setSecondsEnabled(_ enabled: Bool) {
        secondsField.isEnabled = enabled
        secondsStepper.isEnabled = enabled
    }

    @objc private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Seleccionar ubicación predeterminada"
        panel.prompt = "Seleccionar"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = screenshotDirectory()
        panel.beginSheetModal(for: window!) { response in
            guard response == .OK, let url = panel.url else { return }
            UserDefaults.standard.set(url.path, forKey: defaultScreenshotDirectoryKey)
            configureScreenshotDirectory()
            self.pathLabel.stringValue = url.path
            NotificationCenter.default.post(name: .screenshotShelfSettingsChanged, object: nil)
        }
    }

    @objc private func changeAutoSave() {
        let enabled = autoSaveCheckbox.state == .on
        UserDefaults.standard.set(enabled, forKey: autoSaveEnabledKey)
        setSecondsEnabled(enabled)
        NotificationCenter.default.post(name: .screenshotShelfSettingsChanged, object: nil)
    }

    @objc private func changeSeconds() {
        saveSeconds(Double(secondsField.integerValue))
    }

    @objc private func stepSeconds() {
        saveSeconds(secondsStepper.doubleValue)
    }

    private func saveSeconds(_ requested: Double) {
        let seconds = min(max(requested, 1), 3600)
        secondsField.integerValue = Int(seconds)
        secondsStepper.doubleValue = seconds
        UserDefaults.standard.set(seconds, forKey: autoSaveSecondsKey)
        NotificationCenter.default.post(name: .screenshotShelfSettingsChanged, object: nil)
    }

    func showSettings() {
        loadValues()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
