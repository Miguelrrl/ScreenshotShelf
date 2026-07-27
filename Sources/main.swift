import AppKit
import Sparkle
import UniformTypeIdentifiers

private let appName = "ScreenshotShelf"
private let panelSize = NSSize(width: 192, height: 147)
private let edgeMargin: CGFloat = 64
private let panelGap: CGFloat = 12

@discardableResult
private func run(_ executable: String, _ arguments: [String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    try? process.run()
    process.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

private func screenshotDirectory() -> URL {
    let configured = run("/usr/bin/defaults", ["read", "com.apple.screencapture", "location"])
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if !configured.isEmpty {
        return URL(fileURLWithPath: NSString(string: configured).expandingTildeInPath, isDirectory: true)
    }
    return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
}

private func setNativeThumbnail(enabled: Bool) {
    _ = run("/usr/bin/defaults", [
        "write", "com.apple.screencapture", "show-thumbnail", "-bool", enabled ? "true" : "false"
    ])
    // Screenshot.app may keep the preference cached between captures.
    _ = run("/usr/bin/killall", ["Screenshot"])
    _ = run("/usr/bin/killall", ["SystemUIServer"])
}

private func uniqueDestination(_ requested: URL) -> URL {
    guard FileManager.default.fileExists(atPath: requested.path) else { return requested }
    let directory = requested.deletingLastPathComponent()
    let stem = requested.deletingPathExtension().lastPathComponent
    let ext = requested.pathExtension
    var counter = 2
    while true {
        let name = ext.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(ext)"
        let candidate = directory.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        counter += 1
    }
}

final class HoverContainerView: NSView {
    var controls: [NSView] = []
    var onMouseEntered: (() -> Void)?
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            controls.forEach { $0.animator().alphaValue = 1 }
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            controls.forEach { $0.animator().alphaValue = 0 }
        }
    }
}

final class DragImageView: NSImageView {
    var beginDrag: ((NSEvent) -> Void)?
    private var dragOrigin: NSPoint?

    override func mouseDown(with event: NSEvent) {
        guard event.buttonNumber == 0 else {
            dragOrigin = nil
            return
        }
        dragOrigin = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard event.buttonNumber == 0,
              NSEvent.pressedMouseButtons & 1 == 1,
              let origin = dragOrigin else { return }
        let current = convert(event.locationInWindow, from: nil)
        guard hypot(current.x - origin.x, current.y - origin.y) >= 5 else { return }
        dragOrigin = nil
        beginDrag?(event)
    }

    override func mouseUp(with event: NSEvent) {
        dragOrigin = nil
    }
}

final class ThumbnailController: NSWindowController, NSDraggingSource {
    let stagedURL: URL
    let originalURL: URL
    var onFinished: ((ThumbnailController) -> Void)?
    private var dragStarted = false
    private weak var previewImageView: NSImageView?
    private var lastImageModificationDate: Date?

    init(stagedURL: URL, originalURL: URL) {
        self.stagedURL = stagedURL
        self.originalURL = originalURL

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false

        super.init(window: panel)
        buildInterface()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makePill(title: String, action: Selector, blue: Bool = false) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.contentTintColor = .white
        button.wantsLayer = true
        button.layer?.cornerRadius = 16
        button.layer?.borderWidth = 1
        button.layer?.borderColor = NSColor.white.withAlphaComponent(blue ? 0.42 : 0.25).cgColor
        button.layer?.backgroundColor = (
            blue
                ? NSColor(calibratedRed: 0.08, green: 0.36, blue: 0.78, alpha: 0.76)
                : NSColor.black.withAlphaComponent(0.68)
        ).cgColor
        return button
    }

    private func makeIconButton(
        symbolName: String,
        accessibilityDescription: String,
        action: Selector
    ) -> NSButton {
        let button = makePill(title: "", action: action)
        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityDescription
        )
        button.imagePosition = .imageOnly
        button.contentTintColor = .white
        button.layer?.cornerRadius = 15
        return button
    }

    private func buildInterface() {
        guard let panel = window as? NSPanel else { return }
        let root = HoverContainerView(frame: NSRect(origin: .zero, size: panelSize))
        root.wantsLayer = true
        root.layer?.cornerRadius = 12
        root.layer?.masksToBounds = true
        root.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.92).cgColor

        let imageView = DragImageView(frame: root.bounds.insetBy(dx: 6, dy: 6))
        imageView.image = NSImage(contentsOf: stagedURL)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 9
        imageView.layer?.masksToBounds = true
        imageView.beginDrag = { [weak self] event in self?.startDragging(event) }
        previewImageView = imageView
        lastImageModificationDate = modificationDate()
        root.onMouseEntered = { [weak self] in self?.refreshPreviewIfNeeded() }
        root.addSubview(imageView)

        let copy = makePill(title: "⧉  Copiar", action: #selector(copyCapture))
        copy.frame = NSRect(x: 48, y: 83, width: 96, height: 32)
        root.addSubview(copy)

        let save = makePill(title: "↓  Guardar", action: #selector(saveCapture), blue: true)
        save.frame = NSRect(x: 48, y: 43, width: 96, height: 32)
        root.addSubview(save)

        let close = makePill(title: "✕", action: #selector(discardCapture))
        close.font = .systemFont(ofSize: 15, weight: .semibold)
        close.frame = NSRect(x: 7, y: 112, width: 30, height: 30)
        close.layer?.cornerRadius = 15
        root.addSubview(close)

        let edit = makeIconButton(
            symbolName: "pencil",
            accessibilityDescription: "Editar captura",
            action: #selector(editCapture)
        )
        edit.frame = NSRect(x: 155, y: 112, width: 30, height: 30)
        root.addSubview(edit)

        let saveAs = makeIconButton(
            symbolName: "externaldrive.fill",
            accessibilityDescription: "Guardar como",
            action: #selector(saveCaptureAs)
        )
        saveAs.frame = NSRect(x: 7, y: 7, width: 30, height: 30)
        root.addSubview(saveAs)

        root.controls = [copy, save, close, edit, saveAs]
        root.controls.forEach { $0.alphaValue = 0 }
        panel.contentView = root
    }

    func show(at origin: NSPoint) {
        window?.setFrameOrigin(origin)
        window?.orderFrontRegardless()
    }

    @objc private func copyCapture() {
        guard let image = NSImage(contentsOf: stagedURL) else {
            NSSound.beep()
            return
        }
        let board = NSPasteboard.general
        board.clearContents()
        guard board.writeObjects([image]) else {
            NSSound.beep()
            return
        }
        finish(deletePending: true)
    }

    @objc private func saveCapture() {
        do {
            try FileManager.default.moveItem(at: stagedURL, to: uniqueDestination(originalURL))
            finish(deletePending: false)
        } catch {
            NSSound.beep()
        }
    }

    @objc private func saveCaptureAs() {
        guard FileManager.default.fileExists(atPath: stagedURL.path) else {
            NSSound.beep()
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Guardar captura"
        savePanel.prompt = "Guardar"
        savePanel.nameFieldStringValue = originalURL.lastPathComponent
        savePanel.directoryURL = originalURL.deletingLastPathComponent()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false

        NSApp.activate(ignoringOtherApps: true)
        savePanel.begin { [weak self] response in
            guard response == .OK, let self, let destination = savePanel.url else {
                return
            }

            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    _ = try FileManager.default.replaceItemAt(
                        destination,
                        withItemAt: self.stagedURL
                    )
                } else {
                    try FileManager.default.moveItem(
                        at: self.stagedURL,
                        to: destination
                    )
                }
                self.finish(deletePending: false)
            } catch {
                NSSound.beep()
            }
        }
    }

    @objc private func discardCapture() {
        finish(deletePending: true)
    }

    @objc private func editCapture() {
        guard FileManager.default.fileExists(atPath: stagedURL.path) else {
            NSSound.beep()
            return
        }

        guard let previewURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.Preview"
        ) else {
            NSWorkspace.shared.open(stagedURL)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(
            [stagedURL],
            withApplicationAt: previewURL,
            configuration: configuration
        ) { _, error in
            if error != nil {
                DispatchQueue.main.async { NSSound.beep() }
            }
        }
    }

    private func modificationDate() -> Date? {
        try? stagedURL.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
    }

    private func refreshPreviewIfNeeded() {
        let currentDate = modificationDate()
        guard currentDate != lastImageModificationDate,
              let data = try? Data(contentsOf: stagedURL, options: .uncached),
              let image = NSImage(data: data) else { return }
        previewImageView?.image = image
        lastImageModificationDate = currentDate
    }

    private func startDragging(_ event: NSEvent) {
        guard event.buttonNumber == 0,
              NSEvent.pressedMouseButtons & 1 == 1,
              !dragStarted,
              FileManager.default.fileExists(atPath: stagedURL.path),
              let image = NSImage(contentsOf: stagedURL),
              let view = window?.contentView,
              window?.isVisible == true else {
            return
        }
        dragStarted = true
        let item = NSDraggingItem(pasteboardWriter: stagedURL as NSURL)
        item.setDraggingFrame(view.bounds.insetBy(dx: 8, dy: 8), contents: image)
        view.beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        dragStarted = false
        guard operation.contains(.copy) else { return }
        window?.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.finish(deletePending: true)
        }
    }

    private func finish(deletePending: Bool) {
        dragStarted = false
        if deletePending { try? FileManager.default.removeItem(at: stagedURL) }
        window?.close()
        onFinished?(self)
    }
}

final class ScreenshotManager {
    private var timer: Timer?
    private var seen: Set<String> = []
    private var processing: Set<String> = []
    private var panels: [ThumbnailController] = []
    private let launchedAt = Date()
    private let pendingDirectory: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        pendingDirectory = support.appendingPathComponent(appName).appendingPathComponent("Pending")
        try? FileManager.default.createDirectory(
            at: pendingDirectory,
            withIntermediateDirectories: true
        )
        recoverPendingFiles()
    }

    func start() {
        setNativeThumbnail(enabled: false)
        NSLog("%@: observando %@", appName, screenshotDirectory().path)
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func recoverPendingFiles() {
        let destination = screenshotDirectory()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: pendingDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        for file in files {
            let name = file.lastPathComponent
            let recoveredName = name.split(separator: "-", maxSplits: 1).dropFirst().first.map(String.init) ?? name
            let target = uniqueDestination(destination.appendingPathComponent(recoveredName))
            try? FileManager.default.moveItem(at: file, to: target)
        }
    }

    private func scan() {
        let directory = screenshotDirectory()
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )
        } catch {
            NSLog("%@: no se pudo leer %@: %@", appName, directory.path, error.localizedDescription)
            return
        }

        for file in files where file.pathExtension.lowercased() == "png" {
            let path = file.path
            guard !seen.contains(path), !processing.contains(path) else { continue }
            guard let values = try? file.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  (values.fileSize ?? 0) > 0,
                  let modified = values.contentModificationDate,
                  modified >= launchedAt.addingTimeInterval(-1) else { continue }

            processing.insert(path)
            NSLog("%@: captura detectada %@", appName, file.lastPathComponent)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.stage(file)
            }
        }
    }

    private func stage(_ source: URL) {
        processing.remove(source.path)
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        let staged = pendingDirectory
            .appendingPathComponent(UUID().uuidString + "-" + source.lastPathComponent)
        do {
            try FileManager.default.moveItem(at: source, to: staged)
            seen.insert(source.path)
            show(staged: staged, original: source)
        } catch {
            // The file may still be finishing; a later scan will retry it.
            NSLog("%@: no se pudo mover %@: %@", appName, source.path, error.localizedDescription)
        }
    }

    private func show(staged: URL, original: URL) {
        let controller = ThumbnailController(stagedURL: staged, originalURL: original)
        controller.onFinished = { [weak self] finished in
            self?.panels.removeAll { $0 === finished }
            self?.relayout()
        }
        panels.insert(controller, at: 0)
        while panels.count > 5 {
            let old = panels.removeLast()
            try? FileManager.default.removeItem(at: old.stagedURL)
            old.window?.orderOut(nil)
        }
        relayout()
    }

    private func relayout() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        var y = frame.minY + edgeMargin
        for panel in panels {
            panel.show(at: NSPoint(x: frame.minX + 24, y: y))
            y += panelSize.height + panelGap
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let manager = ScreenshotManager()
    private var statusItem: NSStatusItem?
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let statusIcon = NSImage(
            systemSymbolName: "photo.on.rectangle.angled",
            accessibilityDescription: "\(appName) activo"
        ) ?? NSImage(
            systemSymbolName: "rectangle.on.rectangle",
            accessibilityDescription: "\(appName) activo"
        )
        let iconConfiguration = NSImage.SymbolConfiguration(
            pointSize: 16,
            weight: .semibold
        ).applying(
            NSImage.SymbolConfiguration(
                paletteColors: [.systemBlue, .systemPurple]
            )
        )
        item.button?.image = statusIcon?.withSymbolConfiguration(iconConfiguration)
        item.button?.image?.isTemplate = false
        item.button?.toolTip = "ScreenshotShelf está activo"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "ScreenshotShelf activo", action: nil, keyEquivalent: ""))
        let updates = NSMenuItem(
            title: "Buscar actualizaciones…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updates.target = updaterController
        menu.addItem(updates)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Salir", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
        manager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.stop()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
