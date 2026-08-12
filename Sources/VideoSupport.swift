import AppKit
import AVFoundation
import AVKit
import ImageIO
import UniformTypeIdentifiers

private enum VideoExportError: LocalizedError {
    case unsupported
    case invalidDuration
    case exportFailed(String)
    case gifFailed

    var errorDescription: String? {
        switch self {
        case .unsupported: return "Este video no puede exportarse en el formato solicitado."
        case .invalidDuration: return "El rango de tiempo seleccionado no es válido."
        case .exportFailed(let message): return message
        case .gifFailed: return "No se pudo crear el GIF."
        }
    }
}

private func videoPreviewImage(at url: URL, time: Double = 0) -> NSImage? {
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = NSSize(width: 960, height: 540)
    guard let image = try? generator.copyCGImage(
        at: CMTime(seconds: time, preferredTimescale: 600),
        actualTime: nil
    ) else { return nil }
    return NSImage(cgImage: image, size: .zero)
}

private func exportVideo(
    source: URL,
    destination: URL,
    fileType: AVFileType,
    start: Double,
    end: Double,
    completion: @escaping (Result<URL, Error>) -> Void
) {
    let asset = AVURLAsset(url: source)
    guard end > start,
          let exporter = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
          ),
          exporter.supportedFileTypes.contains(fileType) else {
        completion(.failure(VideoExportError.unsupported))
        return
    }
    exporter.outputURL = destination
    exporter.outputFileType = fileType
    exporter.shouldOptimizeForNetworkUse = true
    exporter.timeRange = CMTimeRange(
        start: CMTime(seconds: start, preferredTimescale: 600),
        duration: CMTime(seconds: end - start, preferredTimescale: 600)
    )
    exporter.exportAsynchronously {
        DispatchQueue.main.async {
            if exporter.status == .completed {
                completion(.success(destination))
            } else {
                completion(.failure(
                    exporter.error ?? VideoExportError.exportFailed("La exportación no terminó correctamente.")
                ))
            }
        }
    }
}

final class VideoThumbnailController: NSWindowController, NSDraggingSource {
    let stagedURL: URL
    let originalURL: URL
    var onFinished: ((VideoThumbnailController) -> Void)?
    var onSaved: ((URL) -> Void)?
    private(set) var isManuallyPositioned = false
    private var editorController: VideoEditorWindowController?
    private var autoSaveTimer: Timer?
    private var settingsObserver: NSObjectProtocol?
    private var isFinishing = false
    private var isExporting = false
    private var dragStarted = false
    private weak var previewView: NSImageView?

    init?(stagedURL: URL, originalURL: URL) {
        guard videoPreviewImage(at: stagedURL) != nil else { return nil }
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        super.init(window: panel)
        buildInterface()
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .screenshotShelfSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.scheduleAutoSave() }
        scheduleAutoSave()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func pill(_ title: String, _ action: Selector, blue: Bool = false) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.contentTintColor = .white
        button.wantsLayer = true
        button.layer?.cornerRadius = 16
        button.layer?.borderWidth = 1
        button.layer?.borderColor = NSColor.white.withAlphaComponent(blue ? 0.42 : 0.25).cgColor
        button.layer?.backgroundColor = (
            blue ? NSColor.systemBlue.withAlphaComponent(0.78) : NSColor.black.withAlphaComponent(0.68)
        ).cgColor
        return button
    }

    private func icon(_ symbol: String, _ label: String, _ action: Selector) -> NSButton {
        let button = pill("", action)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.imagePosition = .imageOnly
        button.toolTip = label
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

        let preview = DragImageView(frame: root.bounds.insetBy(dx: 6, dy: 6))
        preview.image = videoPreviewImage(at: stagedURL)
        preview.imageScaling = .scaleProportionallyUpOrDown
        preview.wantsLayer = true
        preview.layer?.cornerRadius = 9
        preview.layer?.masksToBounds = true
        preview.beginDrag = { [weak self] event in self?.startDragging(event) }
        preview.onClick = { [weak self] in self?.editVideo() }
        previewView = preview
        root.addSubview(preview)

        let playBadge = NSImageView(frame: NSRect(x: 78, y: 55, width: 36, height: 36))
        playBadge.image = NSImage(systemSymbolName: "play.circle.fill", accessibilityDescription: "Video")
        playBadge.contentTintColor = .white
        root.addSubview(playBadge)

        let edit = pill("✎  Editar", #selector(editVideo))
        edit.frame = NSRect(x: 48, y: 83, width: 96, height: 32)
        root.addSubview(edit)
        let save = pill("↓  Guardar", #selector(saveVideo), blue: true)
        save.frame = NSRect(x: 48, y: 43, width: 96, height: 32)
        root.addSubview(save)
        let close = pill("✕", #selector(discardVideo))
        close.frame = NSRect(x: 7, y: 112, width: 30, height: 30)
        close.layer?.cornerRadius = 15
        root.addSubview(close)
        let saveAs = icon("externaldrive.fill", "Guardar video como", #selector(saveVideoAs))
        saveAs.frame = NSRect(x: 7, y: 7, width: 30, height: 30)
        root.addSubview(saveAs)
        let move = WindowMoveButton(title: "", target: nil, action: nil)
        move.isBordered = false
        move.image = NSImage(
            systemSymbolName: "arrow.up.and.down.and.arrow.left.and.right",
            accessibilityDescription: "Mover miniatura"
        )
        move.imagePosition = .imageOnly
        move.contentTintColor = .white
        move.toolTip = "Arrastrar para mover la miniatura"
        move.wantsLayer = true
        move.layer?.cornerRadius = 15
        move.layer?.borderWidth = 1
        move.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        move.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.68).cgColor
        move.frame = NSRect(x: 155, y: 7, width: 30, height: 30)
        move.onMoved = { [weak self] in self?.isManuallyPositioned = true }
        root.addSubview(move)

        root.controls = [edit, save, close, saveAs, move]
        root.controls.forEach { $0.alphaValue = 0 }
        panel.contentView = root
    }

    func show(at origin: NSPoint) {
        window?.setFrameOrigin(origin)
        window?.orderFrontRegardless()
    }

    @objc private func saveVideo() {
        let destination = uniqueDestination(
            screenshotDirectory().appendingPathComponent(originalURL.lastPathComponent)
        )
        export(to: destination, replaceExisting: false)
    }

    @objc private func saveVideoAs() {
        guard !isExporting else { return }
        autoSaveTimer?.invalidate()
        let panel = NSSavePanel()
        panel.title = "Guardar grabación"
        panel.prompt = "Guardar"
        panel.nameFieldStringValue = originalURL.lastPathComponent
        panel.allowedContentTypes = [.mpeg4Movie]
        if let path = UserDefaults.standard.string(forKey: lastSaveAsDirectoryKey) {
            panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            panel.directoryURL = screenshotDirectory()
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard let self else { return }
            guard response == .OK, let destination = panel.url else {
                self.scheduleAutoSave()
                return
            }
            UserDefaults.standard.set(
                destination.deletingLastPathComponent().path,
                forKey: lastSaveAsDirectoryKey
            )
            self.export(to: destination, replaceExisting: true)
        }
    }

    private func export(to destination: URL, replaceExisting: Bool) {
        guard !isExporting else { return }
        isExporting = true
        autoSaveTimer?.invalidate()
        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if replaceExisting && FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
        } catch {
            isExporting = false
            present(error)
            return
        }
        let duration = CMTimeGetSeconds(AVURLAsset(url: stagedURL).duration)
        exportVideo(
            source: stagedURL,
            destination: destination,
            fileType: .mp4,
            start: 0,
            end: duration
        ) { [weak self] result in
            guard let self else { return }
            self.isExporting = false
            switch result {
            case .success(let url):
                tagSavedFile(url)
                self.onSaved?(url)
                self.finish(deletePending: true)
            case .failure(let error):
                self.present(error)
                self.scheduleAutoSave()
            }
        }
    }

    @objc private func editVideo() {
        guard editorController == nil,
              let editor = VideoEditorWindowController(
                videoURL: stagedURL,
                defaultDestination: originalURL
              ) else {
            NSSound.beep()
            return
        }
        autoSaveTimer?.invalidate()
        editor.onApply = { [weak self] in
            self?.previewView?.image = videoPreviewImage(at: self?.stagedURL ?? URL(fileURLWithPath: "/"))
        }
        editor.onGIFExported = { [weak self] destination in
            tagSavedFile(destination)
            self?.finish(deletePending: true)
        }
        editor.onSaved = { [weak self] destination in
            tagSavedFile(destination)
            self?.onSaved?(destination)
            self?.finish(deletePending: true)
        }
        editor.onClose = { [weak self, weak editor] in
            guard let self, self.editorController === editor else { return }
            self.editorController = nil
            self.scheduleAutoSave()
        }
        editorController = editor
        editor.showEditor()
    }

    @objc private func discardVideo() { finish(deletePending: true) }

    private func startDragging(_ event: NSEvent) {
        guard !dragStarted,
              let preview = previewView?.image,
              let view = window?.contentView else { return }
        dragStarted = true
        autoSaveTimer?.invalidate()
        let item = NSDraggingItem(pasteboardWriter: stagedURL as NSURL)
        item.setDraggingFrame(view.bounds.insetBy(dx: 8, dy: 8), contents: preview)
        view.beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation { .copy }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        dragStarted = false
        if operation.contains(.copy) { finish(deletePending: true) }
        else { scheduleAutoSave() }
    }

    private func present(_ error: Error) {
        NSSound.beep()
        let alert = NSAlert(error: error)
        alert.messageText = "No se pudo procesar la grabación"
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func finish(deletePending: Bool) {
        guard !isFinishing else { return }
        isFinishing = true
        autoSaveTimer?.invalidate()
        if let settingsObserver { NotificationCenter.default.removeObserver(settingsObserver) }
        editorController?.close()
        editorController = nil
        if deletePending { try? FileManager.default.removeItem(at: stagedURL) }
        window?.orderOut(nil)
        window?.close()
        onFinished?(self)
    }

    private func scheduleAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        guard !isFinishing,
              !isExporting,
              UserDefaults.standard.bool(forKey: autoSaveEnabledKey) else { return }
        autoSaveTimer = Timer.scheduledTimer(
            withTimeInterval: configuredAutoSaveSeconds(),
            repeats: false
        ) { [weak self] _ in self?.saveVideo() }
    }
}

private final class VideoTrimTimelineView: NSView {
    var duration: Double = 1
    var startTime: Double = 0 { didSet { needsDisplay = true } }
    var endTime: Double = 1 { didSet { needsDisplay = true } }
    var playhead: Double = 0 { didSet { needsDisplay = true } }
    var onRangeChanged: (() -> Void)?
    var onSeek: ((Double) -> Void)?
    private var thumbnails: [NSImage] = []
    private enum DragTarget { case start, end, playhead }
    private var dragTarget: DragTarget?

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 92) }

    func loadThumbnails(from url: URL) {
        let duration = self.duration
        DispatchQueue.global(qos: .userInitiated).async {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = NSSize(width: 240, height: 120)
            var images: [NSImage] = []
            for index in 0..<10 {
                let time = CMTime(seconds: duration * Double(index) / 10, preferredTimescale: 600)
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    images.append(NSImage(cgImage: cgImage, size: .zero))
                }
            }
            DispatchQueue.main.async { self.thumbnails = images; self.needsDisplay = true }
        }
    }

    private var trackRect: NSRect { bounds.insetBy(dx: 16, dy: 12) }
    private func x(for time: Double) -> CGFloat {
        trackRect.minX + CGFloat(time / max(duration, 0.001)) * trackRect.width
    }
    private func time(for x: CGFloat) -> Double {
        min(max(Double((x - trackRect.minX) / trackRect.width) * duration, 0), duration)
    }

    override func draw(_ dirtyRect: NSRect) {
        let track = trackRect
        let clip = NSBezierPath(roundedRect: track, xRadius: 8, yRadius: 8)
        NSGraphicsContext.saveGraphicsState()
        clip.addClip()
        NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
        track.fill()
        if !thumbnails.isEmpty {
            let width = track.width / CGFloat(thumbnails.count)
            for (index, image) in thumbnails.enumerated() {
                image.draw(
                    in: NSRect(x: track.minX + CGFloat(index) * width, y: track.minY, width: width + 1, height: track.height),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 0.8,
                    respectFlipped: true,
                    hints: [.interpolation: NSImageInterpolation.low]
                )
            }
        }
        NSColor.black.withAlphaComponent(0.62).setFill()
        NSRect(x: track.minX, y: track.minY, width: max(0, x(for: startTime) - track.minX), height: track.height).fill()
        NSRect(x: x(for: endTime), y: track.minY, width: max(0, track.maxX - x(for: endTime)), height: track.height).fill()
        NSGraphicsContext.restoreGraphicsState()

        let selected = NSRect(
            x: x(for: startTime), y: track.minY,
            width: x(for: endTime) - x(for: startTime), height: track.height
        )
        let outline = NSBezierPath(roundedRect: selected, xRadius: 5, yRadius: 5)
        outline.lineWidth = 3
        NSColor.controlAccentColor.setStroke()
        outline.stroke()
        for handleX in [selected.minX, selected.maxX] {
            let handle = NSBezierPath(roundedRect: NSRect(x: handleX - 6, y: track.minY - 3, width: 12, height: track.height + 6), xRadius: 5, yRadius: 5)
            NSColor.controlAccentColor.setFill()
            handle.fill()
        }
        let playheadX = x(for: playhead)
        let playheadPath = NSBezierPath()
        playheadPath.move(to: NSPoint(x: playheadX, y: track.minY - 7))
        playheadPath.line(to: NSPoint(x: playheadX, y: track.maxY + 7))
        playheadPath.lineWidth = 2
        NSColor.white.setStroke()
        playheadPath.stroke()
        let head = NSBezierPath(ovalIn: NSRect(x: playheadX - 5, y: track.maxY + 2, width: 10, height: 10))
        NSColor.white.setFill()
        head.fill()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let distances: [(DragTarget, CGFloat)] = [
            (.start, abs(point.x - x(for: startTime))),
            (.end, abs(point.x - x(for: endTime))),
            (.playhead, abs(point.x - x(for: playhead)))
        ]
        dragTarget = distances.min(by: { $0.1 < $1.1 })?.0
        updateDrag(at: point.x)
    }
    override func mouseDragged(with event: NSEvent) {
        updateDrag(at: convert(event.locationInWindow, from: nil).x)
    }
    override func mouseUp(with event: NSEvent) { dragTarget = nil }
    private func updateDrag(at x: CGFloat) {
        let value = time(for: x)
        switch dragTarget {
        case .start:
            startTime = min(value, endTime - 0.1)
            playhead = startTime
            onRangeChanged?(); onSeek?(playhead)
        case .end:
            endTime = max(value, startTime + 0.1)
            playhead = endTime
            onRangeChanged?(); onSeek?(playhead)
        case .playhead:
            playhead = min(max(value, startTime), endTime)
            onSeek?(playhead)
        case nil: break
        }
    }
}

final class VideoEditorWindowController: NSWindowController, NSWindowDelegate {
    private let videoURL: URL
    private let defaultDestination: URL
    private let player: AVPlayer
    private let duration: Double
    private let playerView = AVPlayerView()
    private let timeline = VideoTrimTimelineView()
    private let startLabel = NSTextField(labelWithString: "")
    private let endLabel = NSTextField(labelWithString: "")
    private var timeObserver: Any?
    private var exporting = false
    var onApply: (() -> Void)?
    var onGIFExported: ((URL) -> Void)?
    var onSaved: ((URL) -> Void)?
    var onClose: (() -> Void)?

    init?(videoURL: URL, defaultDestination: URL) {
        let asset = AVURLAsset(url: videoURL)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0 else { return nil }
        self.videoURL = videoURL
        self.defaultDestination = defaultDestination
        self.duration = duration
        player = AVPlayer(url: videoURL)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Editar grabación — ScreenshotShelf"
        window.minSize = NSSize(width: 720, height: 520)
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        buildInterface()
        timeline.loadThumbnails(from: videoURL)
        observePlayback()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildInterface() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 1).cgColor
        playerView.player = player
        playerView.controlsStyle = .floating
        playerView.videoGravity = .resizeAspect
        playerView.translatesAutoresizingMaskIntoConstraints = false
        let playerContainer = NSView()
        playerContainer.wantsLayer = true
        playerContainer.layer?.backgroundColor = NSColor.black.cgColor
        playerContainer.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(playerContainer)
        playerContainer.addSubview(playerView)

        timeline.duration = duration
        timeline.startTime = 0
        timeline.endTime = duration
        timeline.playhead = 0
        timeline.onRangeChanged = { [weak self] in self?.updateLabels() }
        timeline.onSeek = { [weak self] time in self?.seek(to: time) }
        updateLabels()
        let rangeLabels = NSStackView(views: [
            NSTextField(labelWithString: "Inicio"), startLabel,
            NSView(), NSTextField(labelWithString: "Final"), endLabel
        ])
        rangeLabels.orientation = .horizontal
        rangeLabels.alignment = .centerY
        rangeLabels.spacing = 8

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        let gif = editorButton(symbol: "photo.on.rectangle.angled", label: "Exportar GIF", action: #selector(exportGIF))
        let trim = editorButton(symbol: "scissors", label: "Aplicar recorte", action: #selector(applyTrim))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let cancel = editorButton(symbol: "xmark", label: "Cancelar", action: #selector(cancel))
        let saveAs = editorButton(symbol: "folder.badge.plus", label: "Guardar como…", action: #selector(saveAs))
        let save = editorButton(symbol: "square.and.arrow.down", label: "Guardar", primary: true, action: #selector(save))
        buttons.addArrangedSubview(gif)
        buttons.addArrangedSubview(trim)
        buttons.addArrangedSubview(spacer)
        buttons.addArrangedSubview(cancel)
        buttons.addArrangedSubview(saveAs)
        buttons.addArrangedSubview(save)

        let controlsBackground = NSVisualEffectView()
        controlsBackground.material = .hudWindow
        controlsBackground.state = .active
        controlsBackground.appearance = NSAppearance(named: .darkAqua)
        controlsBackground.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(controlsBackground)
        let controls = NSStackView(views: [timeline, rangeLabels, buttons])
        controls.orientation = .vertical
        controls.alignment = .leading
        controls.spacing = 10
        controls.translatesAutoresizingMaskIntoConstraints = false
        controlsBackground.addSubview(controls)
        NSLayoutConstraint.activate([
            playerContainer.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            playerContainer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            playerContainer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            playerContainer.bottomAnchor.constraint(equalTo: controlsBackground.topAnchor, constant: -18),
            playerView.topAnchor.constraint(equalTo: playerContainer.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: playerContainer.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: playerContainer.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: playerContainer.bottomAnchor),
            controlsBackground.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            controlsBackground.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            controlsBackground.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            controlsBackground.heightAnchor.constraint(equalToConstant: 166),
            controls.leadingAnchor.constraint(equalTo: controlsBackground.leadingAnchor, constant: 18),
            controls.trailingAnchor.constraint(equalTo: controlsBackground.trailingAnchor, constant: -18),
            controls.topAnchor.constraint(equalTo: controlsBackground.topAnchor, constant: 10),
            controls.bottomAnchor.constraint(equalTo: controlsBackground.bottomAnchor, constant: -12),
            timeline.widthAnchor.constraint(equalTo: controls.widthAnchor),
            rangeLabels.widthAnchor.constraint(equalTo: controls.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: controls.widthAnchor)
        ])
    }

    private func editorButton(
        symbol: String,
        label: String,
        primary: Bool = false,
        action: Selector
    ) -> NSButton {
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(configuration)
        let button = NSButton(title: label, target: self, action: action)
        button.image = image
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.imageScaling = .scaleNone
        button.alignment = .center
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.contentTintColor = .white
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 10
        button.layer?.borderWidth = primary ? 0 : 1
        button.layer?.borderColor = NSColor.white.withAlphaComponent(0.13).cgColor
        button.layer?.backgroundColor = (
            primary ? NSColor.systemBlue.withAlphaComponent(0.9) : NSColor.white.withAlphaComponent(0.09)
        ).cgColor
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        let minimumWidth: CGFloat
        switch label {
        case "Exportar GIF": minimumWidth = 112
        case "Aplicar recorte": minimumWidth = 130
        case "Guardar como…": minimumWidth = 132
        default: minimumWidth = 104
        }
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: minimumWidth).isActive = true
        return button
    }

    @objc private func save() {
        let destination = uniqueDestination(
            screenshotDirectory().appendingPathComponent(defaultDestination.lastPathComponent)
        )
        exportSelection(to: destination, replaceExisting: false)
    }

    @objc private func saveAs() {
        guard !exporting, let window else { return }
        let panel = NSSavePanel()
        panel.title = "Guardar grabación"
        panel.prompt = "Guardar"
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = defaultDestination.lastPathComponent
        if let path = UserDefaults.standard.string(forKey: lastSaveAsDirectoryKey) {
            panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            panel.directoryURL = screenshotDirectory()
        }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let destination = panel.url else { return }
            UserDefaults.standard.set(
                destination.deletingLastPathComponent().path,
                forKey: lastSaveAsDirectoryKey
            )
            self.exportSelection(to: destination, replaceExisting: true)
        }
    }

    private func exportSelection(to destination: URL, replaceExisting: Bool) {
        guard !exporting else { return }
        exporting = true
        player.pause()
        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if replaceExisting, FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
        } catch {
            exporting = false
            present(error)
            return
        }
        exportVideo(
            source: videoURL,
            destination: destination,
            fileType: .mp4,
            start: timeline.startTime,
            end: timeline.endTime
        ) { [weak self] result in
            guard let self else { return }
            self.exporting = false
            switch result {
            case .success(let url):
                self.onSaved?(url)
                self.close()
            case .failure(let error): self.present(error)
            }
        }
    }

    private func observePlayback() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            self.timeline.playhead = seconds
            if seconds >= self.timeline.endTime {
                self.player.pause()
                self.seek(to: self.timeline.startTime)
            }
        }
    }
    private func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    private func updateLabels() {
        startLabel.stringValue = format(timeline.startTime)
        endLabel.stringValue = format(timeline.endTime)
    }
    private func format(_ seconds: Double) -> String {
        String(format: "%02d:%02d.%01d", Int(seconds) / 60, Int(seconds) % 60, Int(seconds * 10) % 10)
    }

    @objc private func applyTrim() {
        guard !exporting else { return }
        exporting = true
        player.pause()
        let temporary = videoURL.deletingLastPathComponent().appendingPathComponent(
            UUID().uuidString + "-edited.mp4"
        )
        exportVideo(
            source: videoURL,
            destination: temporary,
            fileType: .mp4,
            start: timeline.startTime,
            end: timeline.endTime
        ) { [weak self] result in
            guard let self else { return }
            self.exporting = false
            switch result {
            case .success(let url):
                do {
                    _ = try FileManager.default.replaceItemAt(self.videoURL, withItemAt: url)
                    self.onApply?()
                    self.close()
                } catch { self.present(error) }
            case .failure(let error): self.present(error)
            }
        }
    }

    @objc private func exportGIF() {
        guard !exporting else { return }
        let selectedDuration = timeline.endTime - timeline.startTime
        guard selectedDuration <= 120 else {
            present(VideoExportError.exportFailed("Recorte el video a un máximo de 2 minutos para exportarlo como GIF."))
            return
        }
        let panel = NSSavePanel()
        panel.title = "Exportar como GIF"
        panel.prompt = "Exportar"
        panel.allowedContentTypes = [.gif]
        panel.nameFieldStringValue = videoURL.deletingPathExtension().lastPathComponent + ".gif"
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let self, let destination = panel.url else { return }
            self.exporting = true
            self.player.pause()
            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }
            self.createGIF(at: destination) { result in
                self.exporting = false
                switch result {
                case .success(let url):
                    self.onGIFExported?(url)
                    self.close()
                case .failure(let error): self.present(error)
                }
            }
        }
    }

    private func createGIF(
        at destination: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let start = timeline.startTime
        let end = timeline.endTime
        DispatchQueue.global(qos: .userInitiated).async {
            let fps = 12.0
            let frameCount = max(1, Int((end - start) * fps))
            guard let output = CGImageDestinationCreateWithURL(
                destination as CFURL,
                UTType.gif.identifier as CFString,
                frameCount,
                nil
            ) else {
                DispatchQueue.main.async { completion(.failure(VideoExportError.gifFailed)) }
                return
            }
            CGImageDestinationSetProperties(output, [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
            ] as CFDictionary)
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: self.videoURL))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = NSSize(width: 1280, height: 1280)
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            let properties = [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]
            ] as CFDictionary
            for index in 0..<frameCount {
                autoreleasepool {
                    let time = CMTime(
                        seconds: start + Double(index) / fps,
                        preferredTimescale: 600
                    )
                    if let image = try? generator.copyCGImage(at: time, actualTime: nil) {
                        CGImageDestinationAddImage(output, image, properties)
                    }
                }
            }
            let success = CGImageDestinationFinalize(output)
            DispatchQueue.main.async {
                completion(success ? .success(destination) : .failure(VideoExportError.gifFailed))
            }
        }
    }

    @objc private func cancel() { close() }
    private func present(_ error: Error) {
        NSSound.beep()
        let alert = NSAlert(error: error)
        alert.messageText = "No se pudo exportar el video"
        alert.runModal()
    }
    func showEditor() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        onClose?()
    }
}
