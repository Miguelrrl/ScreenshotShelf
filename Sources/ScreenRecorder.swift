import AppKit
import ApplicationServices
import AVFoundation
import Carbon
import CoreMedia
import ScreenCaptureKit

private enum CaptureMode { case region, display }

private final class CaptureSelectionView: NSView {
    private enum DragAction {
        case create, move, resizeLeft, resizeRight, resizeTop, resizeBottom
        case resizeTopLeft, resizeTopRight, resizeBottomLeft, resizeBottomRight
    }
    var onCancel: (() -> Void)?
    var mode: CaptureMode = .region { didSet { needsDisplay = true } }
    var selection = NSRect.zero { didSet { needsDisplay = true } }
    var showsRecordingBorder = false { didSet { needsDisplay = true } }
    private var dragStart: NSPoint?
    private var selectionAtDragStart = NSRect.zero
    private var dragAction: DragAction = .create

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard mode == .region else { return }
        let point = convert(event.locationInWindow, from: nil)
        dragStart = point
        selectionAtDragStart = selection
        let edge: CGFloat = 12
        func near(_ target: NSPoint) -> Bool { hypot(point.x - target.x, point.y - target.y) <= edge * 1.5 }
        if near(NSPoint(x: selection.minX, y: selection.maxY)) {
            dragAction = .resizeTopLeft
        } else if near(NSPoint(x: selection.maxX, y: selection.maxY)) {
            dragAction = .resizeTopRight
        } else if near(NSPoint(x: selection.minX, y: selection.minY)) {
            dragAction = .resizeBottomLeft
        } else if near(NSPoint(x: selection.maxX, y: selection.minY)) {
            dragAction = .resizeBottomRight
        } else if abs(point.x - selection.minX) <= edge, point.y >= selection.minY - edge, point.y <= selection.maxY + edge {
            dragAction = .resizeLeft
        } else if abs(point.x - selection.maxX) <= edge, point.y >= selection.minY - edge, point.y <= selection.maxY + edge {
            dragAction = .resizeRight
        } else if abs(point.y - selection.maxY) <= edge, point.x >= selection.minX - edge, point.x <= selection.maxX + edge {
            dragAction = .resizeTop
        } else if abs(point.y - selection.minY) <= edge, point.x >= selection.minX - edge, point.x <= selection.maxX + edge {
            dragAction = .resizeBottom
        } else if selection.contains(point) {
            dragAction = .move
        } else {
            dragAction = .create
            selection = NSRect(origin: point, size: .zero)
            selectionAtDragStart = selection
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let point = convert(event.locationInWindow, from: nil)
        switch dragAction {
        case .create:
            selection = NSRect(
                x: min(start.x, point.x), y: min(start.y, point.y),
                width: abs(point.x - start.x), height: abs(point.y - start.y)
            ).intersection(bounds)
        case .move:
            var moved = selectionAtDragStart.offsetBy(dx: point.x - start.x, dy: point.y - start.y)
            moved.origin.x = min(max(0, moved.origin.x), bounds.width - moved.width)
            moved.origin.y = min(max(0, moved.origin.y), bounds.height - moved.height)
            selection = moved
        case .resizeLeft:
            let right = selectionAtDragStart.maxX
            selection.origin.x = min(max(0, point.x), right - 20)
            selection.size.width = right - selection.minX
        case .resizeRight:
            selection.size.width = min(bounds.maxX, max(selectionAtDragStart.minX + 20, point.x)) - selectionAtDragStart.minX
        case .resizeTop:
            selection.size.height = min(bounds.maxY, max(selectionAtDragStart.minY + 20, point.y)) - selectionAtDragStart.minY
        case .resizeBottom:
            let top = selectionAtDragStart.maxY
            selection.origin.y = min(max(0, point.y), top - 20)
            selection.size.height = top - selection.minY
        case .resizeTopLeft:
            resize(left: point.x, right: nil, top: point.y, bottom: nil)
        case .resizeTopRight:
            resize(left: nil, right: point.x, top: point.y, bottom: nil)
        case .resizeBottomLeft:
            resize(left: point.x, right: nil, top: nil, bottom: point.y)
        case .resizeBottomRight:
            resize(left: nil, right: point.x, top: nil, bottom: point.y)
        }
    }

    private func resize(left: CGFloat?, right: CGFloat?, top: CGFloat?, bottom: CGFloat?) {
        var rect = selectionAtDragStart
        if let left {
            rect.origin.x = min(max(0, left), selectionAtDragStart.maxX - 20)
            rect.size.width = selectionAtDragStart.maxX - rect.minX
        }
        if let right { rect.size.width = min(bounds.maxX, max(selectionAtDragStart.minX + 20, right)) - rect.minX }
        if let bottom {
            rect.origin.y = min(max(0, bottom), selectionAtDragStart.maxY - 20)
            rect.size.height = selectionAtDragStart.maxY - rect.minY
        }
        if let top { rect.size.height = min(bounds.maxY, max(selectionAtDragStart.minY + 20, top)) - rect.minY }
        selection = rect
    }

    override func mouseUp(with event: NSEvent) { dragStart = nil }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() }
        else { super.keyDown(with: event) }
    }

    override func draw(_ dirtyRect: NSRect) {
        if showsRecordingBorder {
            NSColor.clear.setFill()
            bounds.fill(using: .copy)
            let mask = NSBezierPath(rect: bounds)
            mask.appendRect(selection)
            mask.windingRule = .evenOdd
            NSColor.black.withAlphaComponent(0.48).setFill()
            mask.fill()
            let border = NSBezierPath(rect: selection.insetBy(dx: 1.5, dy: 1.5))
            border.lineWidth = 3
            NSColor.systemRed.setStroke()
            border.stroke()
            return
        }
        NSColor.black.withAlphaComponent(0.48).setFill()
        if mode == .display {
            bounds.fill()
            let border = NSBezierPath(rect: bounds.insetBy(dx: 3, dy: 3))
            border.lineWidth = 4
            NSColor.controlAccentColor.setStroke()
            border.stroke()
            return
        }
        let mask = NSBezierPath(rect: bounds)
        if selection.width > 3, selection.height > 3 { mask.appendRect(selection) }
        mask.windingRule = .evenOdd
        mask.fill()
        if selection.width > 3, selection.height > 3 {
            let border = NSBezierPath(rect: selection)
            border.lineWidth = 2
            NSColor.white.setStroke()
            border.stroke()
            let points = [
                NSPoint(x: selection.minX, y: selection.minY), NSPoint(x: selection.midX, y: selection.minY),
                NSPoint(x: selection.maxX, y: selection.minY), NSPoint(x: selection.minX, y: selection.midY),
                NSPoint(x: selection.maxX, y: selection.midY), NSPoint(x: selection.minX, y: selection.maxY),
                NSPoint(x: selection.midX, y: selection.maxY), NSPoint(x: selection.maxX, y: selection.maxY)
            ]
            NSColor.controlAccentColor.setFill()
            NSColor.white.setStroke()
            for point in points {
                let handle = NSBezierPath(ovalIn: NSRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
                handle.lineWidth = 2
                handle.fill()
                handle.stroke()
            }
            let size = "(Int(selection.width)) × (Int(selection.height))"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.black.withAlphaComponent(0.7)
            ]
            (size as NSString).draw(at: NSPoint(x: selection.minX + 6, y: selection.minY + 6), withAttributes: attributes)
        }
    }
}

private final class CaptureOverlayController: NSWindowController {
    private let selectionView = CaptureSelectionView()
    private let screen: NSScreen
    private weak var toolbar: NSVisualEffectView?
    private weak var regionButton: NSButton?
    private weak var displayButton: NSButton?
    var onRecord: ((NSScreen, NSRect) -> Void)?
    var onCancel: (() -> Void)?

    init(screen: NSScreen, initialSelection: NSRect) {
        self.screen = screen
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = false
        super.init(window: window)
        buildInterface()
        selectionView.selection = initialSelection.intersection(selectionView.bounds)
        selectionView.onCancel = { [weak self] in self?.cancel() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildInterface() {
        guard let content = window?.contentView else { return }
        selectionView.frame = content.bounds
        selectionView.autoresizingMask = [.width, .height]
        content.addSubview(selectionView)

        let bar = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 472, height: 62))
        toolbar = bar
        bar.material = .hudWindow
        bar.state = .active
        bar.appearance = NSAppearance(named: .darkAqua)
        bar.wantsLayer = true
        bar.layer?.cornerRadius = 15
        bar.layer?.masksToBounds = true
        bar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(bar)

        let region = toolbarButton(symbol: "crop", title: "Área", label: "Seleccionar área", width: 92, action: #selector(selectRegion))
        let display = toolbarButton(symbol: "display", title: "Pantalla", label: "Grabar pantalla completa", width: 112, action: #selector(selectDisplay))
        let cancel = toolbarButton(symbol: "xmark", title: "Cancelar", label: "Cancelar (Esc)", width: 116, action: #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"
        cancel.keyEquivalentModifierMask = []
        let record = toolbarButton(symbol: "record.circle.fill", title: "Grabar", label: "Comenzar grabación", width: 102, primary: true, action: #selector(record))
        regionButton = region
        displayButton = display
        let stack = NSStackView(views: [region, display, cancel, record])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)
        NSLayoutConstraint.activate([
            bar.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            bar.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -42),
            bar.widthAnchor.constraint(equalToConstant: 472),
            bar.heightAnchor.constraint(equalToConstant: 62),
            stack.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: bar.centerYAnchor)
        ])
        updateModeButtons()
    }

    private func toolbarButton(
        symbol: String,
        title: String,
        label: String,
        width: CGFloat,
        primary: Bool = false,
        action: Selector
    ) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .semibold))
        let button = NSButton(title: title, target: self, action: action)
        button.image = image
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.imageScaling = .scaleNone
        button.alignment = .center
        button.contentTintColor = .white
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 10
        button.layer?.borderWidth = primary ? 0 : 1
        button.layer?.borderColor = NSColor.white.withAlphaComponent(0.13).cgColor
        button.layer?.backgroundColor = (
            primary ? NSColor.systemRed.withAlphaComponent(0.9) : NSColor.white.withAlphaComponent(0.09)
        ).cgColor
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: width),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
        return button
    }

    private func updateModeButtons() {
        regionButton?.layer?.backgroundColor = (
            selectionView.mode == .region ? NSColor.systemBlue.withAlphaComponent(0.82) : NSColor.white.withAlphaComponent(0.09)
        ).cgColor
        displayButton?.layer?.backgroundColor = (
            selectionView.mode == .display ? NSColor.systemBlue.withAlphaComponent(0.82) : NSColor.white.withAlphaComponent(0.09)
        ).cgColor
    }

    func showOverlay() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(selectionView)
    }

    func showRecordingBorder() {
        toolbar?.isHidden = true
        selectionView.showsRecordingBorder = true
        window?.ignoresMouseEvents = true
        window?.orderFrontRegardless()
    }

    @objc private func selectRegion() {
        selectionView.mode = .region
        updateModeButtons()
    }
    @objc private func selectDisplay() {
        selectionView.mode = .display
        selectionView.selection = selectionView.bounds
        updateModeButtons()
    }
    @objc private func cancel() {
        close()
        onCancel?()
    }
    @objc private func record() {
        let selection: NSRect
        if selectionView.mode == .display {
            selection = selectionView.bounds
        } else {
            selection = selectionView.selection
            guard selection.width >= 20, selection.height >= 20 else {
                NSSound.beep()
                return
            }
        }
        onRecord?(screen, selection)
    }
}

private final class RecordingHUDController: NSWindowController {
    private let timeLabel = NSTextField(labelWithString: "00:00")
    private var timer: Timer?
    private let started = Date()
    var onStop: (() -> Void)?

    init(screen: NSScreen) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 190, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        let origin = NSPoint(x: screen.visibleFrame.midX - 95, y: screen.visibleFrame.maxY - 68)
        panel.setFrameOrigin(origin)
        super.init(window: panel)
        let effect = NSVisualEffectView(frame: panel.contentView!.bounds)
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        let dot = NSTextField(labelWithString: "●")
        dot.textColor = .systemRed
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        let stop = NSButton(title: "Detener", target: self, action: #selector(stop))
        let stack = NSStackView(views: [dot, timeLabel, stop])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.frame = effect.bounds.insetBy(dx: 12, dy: 8)
        effect.addSubview(stack)
        panel.contentView = effect
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showHUD() {
        window?.orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = Int(Date().timeIntervalSince(self.started))
            self.timeLabel.stringValue = String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
        }
    }

    @objc private func stop() { onStop?() }
    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

private final class StreamWriter: NSObject, SCStreamOutput {
    private let queue = DispatchQueue(label: "ScreenshotShelf.Recorder")
    private let writer: AVAssetWriter
    var outputURL: URL { writer.outputURL }
    private let videoInput: AVAssetWriterInput
    private var started = false
    private var encodingError: Error?

    init(url: URL, width: Int, height: Int) throws {
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(2_000_000, width * height * 5),
                AVVideoExpectedSourceFrameRateKey: 30
            ]
        ])
        videoInput.expectsMediaDataInRealTime = true
        super.init()
        guard writer.canAdd(videoInput) else {
            throw CocoaError(.featureUnsupported)
        }
        writer.add(videoInput)
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard sampleBuffer.isValid, outputType == .screen,
              CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]],
           let rawStatus = attachments.first?[.status] as? Int,
           rawStatus != SCFrameStatus.complete.rawValue {
            return
        }
        queue.async {
            guard self.encodingError == nil else { return }
            if !self.started {
                guard self.writer.startWriting() else {
                    self.encodingError = self.writer.error ?? CocoaError(.fileWriteUnknown)
                    return
                }
                self.writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
                self.started = true
            }
            guard self.started else { return }
            if self.videoInput.isReadyForMoreMediaData, !self.videoInput.append(sampleBuffer) {
                self.encodingError = self.writer.error ?? CocoaError(.fileWriteUnknown)
            }
        }
    }

    func finish(completion: @escaping (Result<URL, Error>) -> Void) {
        queue.async {
            if let error = self.encodingError {
                self.writer.cancelWriting()
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard self.started else {
                DispatchQueue.main.async { completion(.failure(CocoaError(.fileWriteUnknown))) }
                return
            }
            self.videoInput.markAsFinished()
            let url = self.writer.outputURL
            self.writer.finishWriting {
                DispatchQueue.main.async {
                    if self.writer.status == .completed { completion(.success(url)) }
                    else { completion(.failure(self.writer.error ?? CocoaError(.fileWriteUnknown))) }
                }
            }
        }
    }
}

final class ScreenRecordingCoordinator: NSObject {
    private static let lastSelectionKey = "ScreenRecordingLastSelection"
    var onFinished: ((URL) -> Void)?
    private(set) var isHotKeyRegistered = false
    private var overlay: CaptureOverlayController?
    private var hud: RecordingHUDController?
    private var stream: SCStream?
    private var writer: StreamWriter?
    private var hotKeyRef: EventHotKeyRef?
    private var escapeHotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var isRecording = false

    override init() {
        super.init()
        installHotKey()
    }

    func installHotKey() {
        guard hotKeyRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let coordinator = Unmanaged<ScreenRecordingCoordinator>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                var identifier = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier
                )
                DispatchQueue.main.async {
                    if identifier.id == 2 { coordinator.cancelRecording() }
                    else { coordinator.toggleCaptureUI() }
                }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &hotKeyHandler
        )
        guard handlerStatus == noErr else {
            NSLog("%@: no se pudo instalar el manejador de ⌘⇧5 (%d)", appName, handlerStatus)
            return
        }
        let identifier = EventHotKeyID(signature: 0x53534846, id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_5),
            UInt32(cmdKey | shiftKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr {
            isHotKeyRegistered = true
            NSLog("%@: atajo ⌘⇧5 registrado", appName)
        } else {
            NSLog("%@: no se pudo registrar ⌘⇧5 (%d)", appName, status)
        }
    }

    func toggleCaptureUI() {
        if isRecording { stopRecording(); return }
        if overlay != nil { overlay?.close(); overlay = nil; return }
        showSelector()
    }

    func showSelector() {
        registerEscapeHotKey()
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let initialSelection = restoredSelection(in: screen.frame.size)
        let controller = CaptureOverlayController(screen: screen, initialSelection: initialSelection)
        controller.onRecord = { [weak self] screen, rect in
            self?.storeSelection(rect, in: screen.frame.size)
            self?.startRecording(screen: screen, selection: rect)
        }
        controller.onCancel = { [weak self] in
            self?.overlay = nil
            self?.unregisterEscapeHotKey()
        }
        overlay = controller
        controller.showOverlay()
    }

    private func restoredSelection(in size: NSSize) -> NSRect {
        if let value = UserDefaults.standard.string(forKey: Self.lastSelectionKey) {
            let numbers = value.split(separator: ",").compactMap { Double($0) }
            if numbers.count == 4 {
                let rect = NSRect(
                    x: numbers[0] * size.width, y: numbers[1] * size.height,
                    width: numbers[2] * size.width, height: numbers[3] * size.height
                ).intersection(NSRect(origin: .zero, size: size))
                if rect.width >= 20, rect.height >= 20 { return rect }
            }
        }
        let width = size.width * 0.6
        let height = size.height * 0.55
        return NSRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    private func storeSelection(_ rect: NSRect, in size: NSSize) {
        guard size.width > 0, size.height > 0 else { return }
        let value = [rect.minX / size.width, rect.minY / size.height, rect.width / size.width, rect.height / size.height]
            .map(String.init).joined(separator: ",")
        UserDefaults.standard.set(value, forKey: Self.lastSelectionKey)
    }

    private func startRecording(screen: NSScreen, selection: NSRect) {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            // macOS presents its own consent sheet. The user can retry after granting access.
            restoreSelectorAfterFailure()
            return
        }
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return }
        Task {
            var stage = "obtener contenido compartible"
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                    throw CocoaError(.fileNoSuchFile)
                }
                let scale = screen.backingScaleFactor
                let local = selection
                let sourceRect = CGRect(
                    x: local.minX,
                    y: screen.frame.height - local.maxY,
                    width: local.width,
                    height: local.height
                )
                let width = max(2, Int(local.width * scale)) & ~1
                let height = max(2, Int(local.height * scale)) & ~1
                let configuration = SCStreamConfiguration()
                configuration.sourceRect = sourceRect
                configuration.width = width
                configuration.height = height
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                configuration.queueDepth = 8
                configuration.pixelFormat = kCVPixelFormatType_32BGRA
                // Audio capture is intentionally disabled until its permission and
                // device lifecycle are handled independently from screen recording.
                configuration.capturesAudio = false
                configuration.showsCursor = true
                let excludedApps = content.applications.filter {
                    $0.bundleIdentifier == Bundle.main.bundleIdentifier
                }
                let filter = SCContentFilter(
                    display: display,
                    excludingApplications: excludedApps,
                    exceptingWindows: []
                )
                let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
                let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(appName).appendingPathComponent("Recordings")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent(UUID().uuidString + ".mp4")
                stage = "crear escritor H.264"
                let writer = try StreamWriter(url: url, width: width, height: height)
                stage = "conectar video con ScreenCaptureKit"
                try stream.addStreamOutput(writer, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInteractive))
                stage = "iniciar ScreenCaptureKit"
                try await stream.startCapture()
                let selectedDisplayID = displayID
                await MainActor.run {
                    self.overlay?.showRecordingBorder()
                    self.stream = stream
                    self.writer = writer
                    self.isRecording = true
                    self.registerEscapeHotKey()
                    let hudScreen = NSScreen.screens.first {
                        ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == selectedDisplayID
                    } ?? NSScreen.main!
                    let hud = RecordingHUDController(screen: hudScreen)
                    hud.onStop = { [weak self] in self?.stopRecording() }
                    self.hud = hud
                    hud.showHUD()
                }
            } catch {
                let failedStage = stage
                self.logRecordingError(error, stage: failedStage)
                await MainActor.run {
                    if CGPreflightScreenCaptureAccess() {
                        self.present(error, stage: failedStage)
                    } else {
                        self.showPermissionAlert()
                    }
                }
            }
        }
    }

    private func restoreSelectorAfterFailure() {
        guard overlay == nil, !isRecording else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, self.overlay == nil, !self.isRecording else { return }
            self.showSelector()
        }
    }

    private func logRecordingError(_ error: Error, stage: String) {
        let nsError = error as NSError
        let line = "\(Date().ISO8601Format()) | \(stage) | \(nsError.domain) | \(nsError.code) | \(nsError.localizedDescription) | \(nsError.userInfo)\n"
        NSLog("%@: %@", appName, line)
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(appName)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("recording-errors.log")
        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }

    private func registerEscapeHotKey() {
        guard escapeHotKeyRef == nil else { return }
        let identifier = EventHotKeyID(signature: 0x53534846, id: 2)
        let status = RegisterEventHotKey(UInt32(kVK_Escape), 0, identifier, GetApplicationEventTarget(), 0, &escapeHotKeyRef)
        if status != noErr { NSLog("%@: no se pudo registrar Esc (%d)", appName, status) }
    }

    private func unregisterEscapeHotKey() {
        if let escapeHotKeyRef { UnregisterEventHotKey(escapeHotKeyRef) }
        escapeHotKeyRef = nil
    }

    private func cancelRecording() {
        if isRecording {
            stopRecording(discard: true)
        } else if let overlay {
            overlay.close()
            self.overlay = nil
            unregisterEscapeHotKey()
        }
    }

    func stopRecording(discard: Bool = false) {
        guard isRecording, let stream, let writer else { return }
        isRecording = false
        unregisterEscapeHotKey()
        hud?.close()
        hud = nil
        overlay?.close()
        overlay = nil
        let outputURL = writer.outputURL
        Task {
            do { try await stream.stopCapture() }
            catch where !discard { await MainActor.run { present(error) } }
            catch { }
            await MainActor.run {
                self.stream = nil
                self.writer = nil
            }
            writer.finish { [weak self] result in
                if discard {
                    try? FileManager.default.removeItem(at: outputURL)
                    return
                }
                switch result {
                case .success(let url): self?.onFinished?(url)
                case .failure(let error):
                    self?.logRecordingError(error, stage: "finalizar archivo MOV")
                    self?.present(error, stage: "finalizar archivo MOV")
                    self?.restoreSelectorAfterFailure()
                }
            }
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "ScreenshotShelf necesita permiso para grabar la pantalla"
        alert.informativeText = "Active ScreenshotShelf en Privacidad y seguridad > Grabación de pantalla y vuelva a abrir la app."
        alert.addButton(withTitle: "Abrir Ajustes")
        alert.addButton(withTitle: "Cancelar")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func present(_ error: Error, stage: String? = nil) {
        NSSound.beep()
        let nsError = error as NSError
        let alert = NSAlert()
        alert.messageText = "No se pudo iniciar la grabación"
        let prefix = stage.map { "Etapa: \($0)\n" } ?? ""
        alert.informativeText = "\(prefix)\(nsError.domain) (\(nsError.code))\n\(nsError.localizedDescription)"
        alert.addButton(withTitle: "Aceptar")
        NSApp.activate(ignoringOtherApps: true)
        if let window = overlay?.window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
