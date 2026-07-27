import AppKit
import Vision

private enum EditTool: Int, CaseIterable {
    case pen, arrow, rectangle, ellipse, text, crop
    var title: String {
        switch self {
        case .pen: return "Lápiz"
        case .arrow: return "Flecha"
        case .rectangle: return "Rectángulo"
        case .ellipse: return "Círculo"
        case .text: return "Texto"
        case .crop: return "Recortar"
        }
    }
    var symbol: String {
        switch self {
        case .pen: return "pencil.tip"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "textformat"
        case .crop: return "crop"
        }
    }
}

private final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var constrained = super.constrainBoundsRect(proposedBounds)
        guard let documentView else { return constrained }
        let documentFrame = documentView.frame
        if documentFrame.width < constrained.width {
            constrained.origin.x = documentFrame.midX - constrained.width / 2
        }
        if documentFrame.height < constrained.height {
            constrained.origin.y = documentFrame.midY - constrained.height / 2
        }
        return constrained
    }
}

private struct Stroke { var points: [NSPoint]; var color: NSColor; var width: CGFloat }
private struct Shape {
    var tool: EditTool; var start: NSPoint; var end: NSPoint
    var color: NSColor; var width: CGFloat
}
private struct Label { var point: NSPoint; var text: String; var color: NSColor; var size: CGFloat }
private struct CanvasState {
    var strokes: [Stroke] = []; var shapes: [Shape] = []; var labels: [Label] = []
    var crop: NSRect?
}

private final class EditorCanvas: NSView {
    let image: NSImage
    var tool: EditTool = .pen
    var color: NSColor = .systemRed
    var width: CGFloat = 5
    var onHistoryChange: (() -> Void)?
    private var state = CanvasState()
    private var undoStack: [CanvasState] = [], redoStack: [CanvasState] = []
    private var start: NSPoint?, current: NSPoint?, activeStroke: Stroke?
    private var movingLabel: Int?
    private var movingOffset = NSPoint.zero
    private var selectedLabel: Int?

    init(image: NSImage) {
        self.image = image
        super.init(frame: NSRect(origin: .zero, size: image.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    private func point(_ event: NSEvent) -> NSPoint {
        let p = convert(event.locationInWindow, from: nil)
        return NSPoint(x: min(max(p.x, 0), bounds.maxX), y: min(max(p.y, 0), bounds.maxY))
    }
    private func rect(_ a: NSPoint, _ b: NSPoint) -> NSRect {
        NSRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
    private func checkpoint() {
        undoStack.append(state)
        if undoStack.count > 60 { undoStack.removeFirst() }
        redoStack.removeAll()
    }
    func undo() {
        guard let value = undoStack.popLast() else { return }
        redoStack.append(state); state = value; changed()
    }
    func redo() {
        guard let value = redoStack.popLast() else { return }
        undoStack.append(state); state = value; changed()
    }
    func reset() {
        guard canUndo || !state.strokes.isEmpty || !state.shapes.isEmpty ||
                !state.labels.isEmpty || state.crop != nil else { return }
        checkpoint(); state = CanvasState(); changed()
    }
    private func changed() { needsDisplay = true; onHistoryChange?() }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = point(event)
        if tool == .text {
            if let index = labelIndex(at: p) {
                checkpoint()
                movingLabel = index
                selectedLabel = index
                movingOffset = NSPoint(
                    x: p.x - state.labels[index].point.x,
                    y: p.y - state.labels[index].point.y
                )
                needsDisplay = true
            } else {
                selectedLabel = nil
                addText(at: p)
            }
            return
        }
        selectedLabel = nil
        start = p; current = p
        if tool == .pen { activeStroke = Stroke(points: [p], color: color, width: width) }
        needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        if let index = movingLabel {
            let p = point(event)
            state.labels[index].point = NSPoint(
                x: p.x - movingOffset.x,
                y: p.y - movingOffset.y
            )
            needsDisplay = true
            return
        }
        current = point(event)
        if tool == .pen, let p = current { activeStroke?.points.append(p) }
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if movingLabel != nil {
            movingLabel = nil
            onHistoryChange?()
            return
        }
        guard let a = start else { return }
        let b = point(event)
        if hypot(b.x - a.x, b.y - a.y) >= 2 {
            checkpoint()
            switch tool {
            case .pen: if let activeStroke { state.strokes.append(activeStroke) }
            case .crop: state.crop = rect(a, b).intersection(bounds)
            case .arrow, .rectangle, .ellipse:
                state.shapes.append(Shape(tool: tool, start: a, end: b, color: color, width: width))
            case .text: break
            }
            onHistoryChange?()
        }
        start = nil; current = nil; activeStroke = nil; needsDisplay = true
    }
    private func addText(at point: NSPoint) {
        let alert = NSAlert()
        alert.messageText = "Agregar texto"
        alert.addButton(withTitle: "Agregar"); alert.addButton(withTitle: "Cancelar")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 26))
        alert.accessoryView = field; alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn,
              !field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        checkpoint()
        state.labels.append(Label(point: point, text: field.stringValue, color: color, size: max(16, width * 4)))
        selectedLabel = state.labels.indices.last
        changed()
    }
    private func labelAttributes(_ label: Label) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: label.size, weight: .semibold),
            .foregroundColor: label.color,
            .strokeColor: NSColor.black.withAlphaComponent(0.45),
            .strokeWidth: -2
        ]
    }
    private func labelRect(_ label: Label) -> NSRect {
        let size = (label.text as NSString).size(withAttributes: labelAttributes(label))
        return NSRect(origin: label.point, size: size).insetBy(dx: -8, dy: -6)
    }
    private func labelIndex(at point: NSPoint) -> Int? {
        state.labels.indices.reversed().first { labelRect(state.labels[$0]).contains(point) }
    }

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds); drawAnnotations(showSelection: true)
        if let activeStroke { draw(stroke: activeStroke) }
        if let a = start, let b = current, tool != .pen, tool != .text {
            if tool == .crop { cropOverlay(rect(a, b)) }
            else { draw(shape: Shape(tool: tool, start: a, end: b, color: color, width: width)) }
        } else if let crop = state.crop { cropOverlay(crop) }
    }
    private func drawAnnotations(showSelection: Bool) {
        state.strokes.forEach { draw(stroke: $0) }
        state.shapes.forEach { draw(shape: $0) }
        for (index, label) in state.labels.enumerated() {
            (label.text as NSString).draw(at: label.point, withAttributes: labelAttributes(label))
            if showSelection, index == selectedLabel {
                let selection = NSBezierPath(roundedRect: labelRect(label), xRadius: 4, yRadius: 4)
                selection.lineWidth = 1.5
                selection.setLineDash([5, 3], count: 2, phase: 0)
                NSColor.controlAccentColor.setStroke()
                selection.stroke()
            }
        }
    }
    private func draw(stroke: Stroke) {
        guard let first = stroke.points.first else { return }
        let path = NSBezierPath(); path.lineWidth = stroke.width
        path.lineCapStyle = .round; path.lineJoinStyle = .round; path.move(to: first)
        stroke.points.dropFirst().forEach { path.line(to: $0) }
        stroke.color.setStroke(); path.stroke()
    }
    private func draw(shape: Shape) {
        let path = NSBezierPath(); path.lineWidth = shape.width
        path.lineCapStyle = .round; path.lineJoinStyle = .round
        switch shape.tool {
        case .rectangle: path.appendRect(rect(shape.start, shape.end))
        case .ellipse: path.appendOval(in: rect(shape.start, shape.end))
        case .arrow:
            path.move(to: shape.start); path.line(to: shape.end)
            let angle = atan2(shape.end.y - shape.start.y, shape.end.x - shape.start.x)
            let head = max(12, shape.width * 3.5)
            for offset in [-CGFloat.pi / 6, CGFloat.pi / 6] {
                path.move(to: shape.end)
                path.line(to: NSPoint(x: shape.end.x - head * cos(angle + offset),
                                      y: shape.end.y - head * sin(angle + offset)))
            }
        default: return
        }
        shape.color.setStroke(); path.stroke()
    }
    private func cropOverlay(_ selection: NSRect) {
        let outside = NSBezierPath(rect: bounds); outside.appendRect(selection)
        outside.windingRule = .evenOdd; NSColor.black.withAlphaComponent(0.5).setFill(); outside.fill()
        let line = NSBezierPath(rect: selection); line.lineWidth = 2
        line.setLineDash([7, 5], count: 2, phase: 0); NSColor.white.setStroke(); line.stroke()
    }
    func png() -> Data? {
        let output = (state.crop ?? bounds).intersection(bounds).integral
        guard output.width > 0, output.height > 0,
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                pixelsWide: Int(output.width), pixelsHigh: Int(output.height),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bitmapFormat: [], bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        let transform = NSAffineTransform()
        transform.translateX(by: -output.minX, yBy: -output.minY)
        transform.concat()
        image.draw(in: bounds); drawAnnotations(showSelection: false)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])
    }
}

final class EditorWindowController: NSWindowController, NSWindowDelegate {
    private let destination: URL
    private let canvas: EditorCanvas
    private var toolButtons: [NSButton] = []
    private var undoButton: NSButton!, redoButton: NSButton!
    private weak var scrollView: NSScrollView?
    var onApply: (() -> Void)?
    var onClose: (() -> Void)?

    init?(imageURL: URL) {
        guard let image = NSImage(contentsOf: imageURL) else { return nil }
        destination = imageURL; canvas = EditorCanvas(image: image)
        let visible = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1280, height: 800)
        let size = NSSize(width: min(max(image.size.width + 40, 820), visible.width * 0.9),
                          height: min(max(image.size.height + 100, 560), visible.height * 0.9))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Editar captura — ScreenshotShelf"; window.minSize = NSSize(width: 900, height: 480)
        window.isReleasedWhenClosed = false; window.center()
        super.init(window: window); window.delegate = self; build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        guard let content = window?.contentView else { return }
        let bar = NSVisualEffectView(); bar.material = .headerView
        let scroll = NSScrollView(); scroll.hasHorizontalScroller = true; scroll.hasVerticalScroller = true
        scroll.contentView = CenteringClipView()
        scroll.allowsMagnification = true; scroll.minMagnification = 0.15; scroll.maxMagnification = 4
        scroll.documentView = canvas; scroll.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1)
        scrollView = scroll
        [bar, scroll].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; content.addSubview($0) }
        let stack = NSStackView(); stack.orientation = .horizontal; stack.alignment = .centerY; stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false; bar.addSubview(stack)
        EditTool.allCases.forEach { tool in
            let b = NSButton(title: "", target: self, action: #selector(selectTool(_:)))
            b.image = NSImage(systemSymbolName: tool.symbol, accessibilityDescription: tool.title)
            b.imagePosition = .imageOnly
            b.toolTip = tool.title
            b.setAccessibilityLabel(tool.title)
            b.tag = tool.rawValue; b.setButtonType(.toggle); b.bezelStyle = .texturedRounded
            b.widthAnchor.constraint(equalToConstant: 38).isActive = true
            b.heightAnchor.constraint(equalToConstant: 32).isActive = true
            b.state = tool == .pen ? .on : .off; stack.addArrangedSubview(b); toolButtons.append(b)
        }
        let color = NSColorWell(); color.color = canvas.color; color.target = self
        color.action = #selector(changeColor(_:)); stack.addArrangedSubview(color)
        let slider = NSSlider(value: 5, minValue: 2, maxValue: 18, target: self, action: #selector(changeWidth(_:)))
        slider.widthAnchor.constraint(equalToConstant: 75).isActive = true; stack.addArrangedSubview(slider)
        stack.addArrangedSubview(iconButton("text.viewfinder", "Copiar texto de la imagen", #selector(copyRecognizedText)))
        stack.addArrangedSubview(iconButton("minus.magnifyingglass", "Alejar", #selector(zoomOut)))
        stack.addArrangedSubview(iconButton("plus.magnifyingglass", "Acercar", #selector(zoomIn)))
        stack.addArrangedSubview(iconButton("arrow.down.right.and.arrow.up.left", "Ajustar a la ventana", #selector(zoomToFit)))
        undoButton = makeButton("↶", #selector(undo)); redoButton = makeButton("↷", #selector(redo))
        stack.addArrangedSubview(undoButton); stack.addArrangedSubview(redoButton)
        stack.addArrangedSubview(makeButton("Restablecer", #selector(reset)))
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer); stack.addArrangedSubview(makeButton("Cancelar", #selector(cancel)))
        let apply = makeButton("Aplicar", #selector(apply)); apply.keyEquivalent = "\r"
        apply.bezelColor = .controlAccentColor; stack.addArrangedSubview(apply)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: content.topAnchor), bar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor), bar.heightAnchor.constraint(equalToConstant: 58),
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -10), stack.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            scroll.topAnchor.constraint(equalTo: bar.bottomAnchor), scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
        canvas.onHistoryChange = { [weak self] in self?.updateHistory() }; updateHistory()
        DispatchQueue.main.async { self.fitImage() }
    }
    private func makeButton(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action); b.bezelStyle = .rounded; return b
    }
    private func iconButton(_ symbol: String, _ label: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: "", target: self, action: action)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.imagePosition = .imageOnly
        button.bezelStyle = .texturedRounded
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.widthAnchor.constraint(equalToConstant: 36).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return button
    }
    @objc private func selectTool(_ sender: NSButton) {
        guard let tool = EditTool(rawValue: sender.tag) else { return }
        canvas.tool = tool; toolButtons.forEach { $0.state = $0 === sender ? .on : .off }
    }
    @objc private func changeColor(_ sender: NSColorWell) { canvas.color = sender.color }
    @objc private func changeWidth(_ sender: NSSlider) { canvas.width = CGFloat(sender.doubleValue) }
    @objc private func zoomIn() {
        guard let scrollView else { return }
        scrollView.setMagnification(min(scrollView.magnification * 1.25, scrollView.maxMagnification), centeredAt: visibleCenter)
    }
    @objc private func zoomOut() {
        guard let scrollView else { return }
        scrollView.setMagnification(max(scrollView.magnification / 1.25, scrollView.minMagnification), centeredAt: visibleCenter)
    }
    @objc private func zoomToFit() { fitImage() }
    private var visibleCenter: NSPoint {
        guard let scrollView else { return .zero }
        return NSPoint(x: scrollView.documentVisibleRect.midX, y: scrollView.documentVisibleRect.midY)
    }
    private func fitImage() {
        guard let scrollView else { return }
        scrollView.magnification = min(
            scrollView.contentSize.width / max(canvas.image.size.width, 1),
            scrollView.contentSize.height / max(canvas.image.size.height, 1),
            1
        )
    }
    @objc private func copyRecognizedText() {
        guard let cgImage = canvas.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            NSSound.beep()
            return
        }
        let request = VNRecognizeTextRequest { request, error in
            let text = (request.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""
            DispatchQueue.main.async {
                guard error == nil, !text.isEmpty else {
                    self.showOCRResult("No se encontró texto legible.", copied: false)
                    return
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                self.showOCRResult(text, copied: true)
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        DispatchQueue.global(qos: .userInitiated).async {
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        }
    }
    private func showOCRResult(_ text: String, copied: Bool) {
        let alert = NSAlert()
        alert.messageText = copied ? "Texto copiado" : "Reconocimiento de texto"
        alert.informativeText = copied
            ? "El texto detectado se copió al portapapeles."
            : text
        alert.addButton(withTitle: "Aceptar")
        if copied {
            let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 180))
            scroll.hasVerticalScroller = true
            let textView = NSTextView(frame: scroll.bounds)
            textView.string = text
            textView.isEditable = false
            textView.isSelectable = true
            scroll.documentView = textView
            alert.accessoryView = scroll
        }
        alert.runModal()
    }
    @objc private func undo() { canvas.undo() }
    @objc private func redo() { canvas.redo() }
    @objc private func reset() { canvas.reset() }
    @objc private func cancel() { close() }
    @objc private func apply() {
        guard let data = canvas.png() else { NSSound.beep(); return }
        do { try data.write(to: destination, options: .atomic); onApply?(); close() }
        catch { NSSound.beep(); NSAlert(error: error).runModal() }
    }
    private func updateHistory() { undoButton?.isEnabled = canvas.canUndo; redoButton?.isEnabled = canvas.canRedo }
    func showEditor() {
        NSApp.activate(ignoringOtherApps: true); showWindow(nil); window?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) { onClose?() }
}
