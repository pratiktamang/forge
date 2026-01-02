import SwiftUI
import AppKit

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

// MARK: - Markdown Editor View

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var vimState: VimState
    var onLinkClicked: ((String) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = VimTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.insertionPointColor = NSColor.textColor

        // Configure text container
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        // Set up scroll view
        scrollView.documentView = textView

        // Store references
        context.coordinator.textView = textView
        context.coordinator.vimState = vimState
        textView.vimState = vimState
        vimState.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? VimTextView else { return }

        // Only update if text actually changed externally
        if textView.string != text && !context.coordinator.isUpdating {
            context.coordinator.isUpdating = true
            let selectedRange = textView.selectedRange()
            textView.string = text
            applyMarkdownStyling(to: textView)
            textView.setSelectedRange(selectedRange)
            context.coordinator.isUpdating = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Markdown Styling

    private func applyMarkdownStyling(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)

        // Reset to default
        textStorage.beginEditing()
        textStorage.setAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.textColor
        ], range: fullRange)

        let string = textStorage.string

        // Headers
        applyHeaderStyling(to: textStorage, in: string)

        // Bold
        applyPattern(#"\*\*(.+?)\*\*"#, to: textStorage, in: string, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        ])

        // Italic
        applyPattern(#"\*(.+?)\*"#, to: textStorage, in: string, attributes: [
            .font: NSFont(descriptor: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular).fontDescriptor.withSymbolicTraits(.italic), size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ])

        // Code inline
        applyPattern(#"`([^`]+)`"#, to: textStorage, in: string, attributes: [
            .backgroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.1),
            .foregroundColor: NSColor.systemPink
        ])

        // Wiki links [[...]]
        applyPattern(#"\[\[([^\]]+)\]\]"#, to: textStorage, in: string, attributes: [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ])

        // URLs
        applyPattern(#"https?://[^\s]+"#, to: textStorage, in: string, attributes: [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ])

        textStorage.endEditing()
    }

    private func applyHeaderStyling(to textStorage: NSTextStorage, in string: String) {
        let headerPatterns: [(String, CGFloat)] = [
            (#"^#{1}\s+.+$"#, 24),
            (#"^#{2}\s+.+$"#, 20),
            (#"^#{3}\s+.+$"#, 17),
            (#"^#{4}\s+.+$"#, 15),
            (#"^#{5}\s+.+$"#, 14),
            (#"^#{6}\s+.+$"#, 13)
        ]

        for (pattern, fontSize) in headerPatterns {
            applyPattern(pattern, to: textStorage, in: string, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
            ], options: [.anchorsMatchLines])
        }
    }

    private func applyPattern(_ pattern: String, to textStorage: NSTextStorage, in string: String, attributes: [NSAttributedString.Key: Any], options: NSRegularExpression.Options = []) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }

        let range = NSRange(location: 0, length: string.count)
        regex.enumerateMatches(in: string, range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }
            textStorage.addAttributes(attributes, range: matchRange)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditorView
        weak var textView: VimTextView?
        weak var vimState: VimState?
        var isUpdating = false

        init(_ parent: MarkdownEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = textView else { return }

            isUpdating = true
            parent.text = textView.string
            parent.applyMarkdownStyling(to: textView)
            isUpdating = false
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL {
                NSWorkspace.shared.open(url)
                return true
            }
            return false
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Intercept cancelOperation: (escape key) for vim mode
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if let vimState = vimState,
                   UserDefaults.standard.bool(forKey: "isVimModeEnabled") {
                    _ = vimState.handleKeySync("\u{1B}", modifiers: [])
                    return true // We handled it
                }
            }
            return false // Let the text view handle it
        }
    }
}

// MARK: - Vim Text View

class VimTextView: NSTextView {
    weak var vimState: VimState?

    override func keyDown(with event: NSEvent) {
        guard let vimState = vimState,
              UserDefaults.standard.bool(forKey: "isVimModeEnabled") else {
            super.keyDown(with: event)
            return
        }

        // Check for escape key by keyCode (53) since charactersIgnoringModifiers can be unreliable
        let key: String
        if event.keyCode == 53 {
            key = "\u{1B}"
        } else {
            key = event.charactersIgnoringModifiers ?? ""
        }
        let modifiers = event.modifierFlags

        // Handle key synchronously - VimState is @MainActor so this is safe
        let handled = vimState.handleKeySync(key, modifiers: modifiers)

        if !handled && vimState.mode == .insert {
            // In insert mode, let unhandled keys go through normally
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Handle escape key for vim mode
        if event.keyCode == 53 {
            if let vimState = vimState,
               UserDefaults.standard.bool(forKey: "isVimModeEnabled") {
                _ = vimState.handleKeySync("\u{1B}", modifiers: event.modifierFlags)
                return true
            }
        }

        // Let standard key equivalents through (Cmd+S, Cmd+C, etc.)
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if modifiers.contains(.command) {
            return super.performKeyEquivalent(with: event)
        }

        return false
    }


    // Draw block cursor in normal mode
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard let vimState = vimState,
              UserDefaults.standard.bool(forKey: "isVimModeEnabled"),
              vimState.mode == .normal || vimState.mode == .visual || vimState.mode == .visualLine else {
            super.drawInsertionPoint(in: rect, color: color, turnedOn: flag)
            return
        }

        // Draw block cursor
        if flag {
            var blockRect = rect
            blockRect.size.width = 8 // Block cursor width

            // Get character at cursor position if available
            if let layoutManager = layoutManager,
               let textContainer = textContainer,
               selectedRange().location < string.count {

                let glyphRange = layoutManager.glyphRange(for: textContainer)
                if glyphRange.location != NSNotFound {
                    let glyphIndex = layoutManager.glyphIndex(for: NSPoint(x: rect.origin.x, y: rect.origin.y), in: textContainer)
                    if glyphIndex < glyphRange.location + glyphRange.length {
                        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
                        blockRect.size.width = max(glyphRect.width, 8)
                    }
                }
            }

            color.withAlphaComponent(0.7).setFill()
            NSBezierPath(rect: blockRect).fill()
        }
    }

    override func setNeedsDisplay(_ invalidRect: NSRect) {
        // Expand invalidation to include cursor area
        var expandedRect = invalidRect
        expandedRect.size.width += 10
        super.setNeedsDisplay(expandedRect)
    }
}

// MARK: - Vim Mode Indicator

struct VimModeIndicator: View {
    @ObservedObject var vimState: VimState

    var body: some View {
        HStack(spacing: 8) {
            // Mode badge
            Text(vimState.mode.displayName)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(modeColor)
                .foregroundColor(.white)
                .cornerRadius(4)

            // Command buffer
            if !vimState.commandBuffer.isEmpty {
                Text(vimState.commandBuffer)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Status message
            if !vimState.statusMessage.isEmpty {
                Text(vimState.statusMessage)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Position info
            if let textView = vimState.textView {
                let position = getPosition(in: textView)
                Text("Ln \(position.line), Col \(position.column)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var modeColor: Color {
        switch vimState.mode {
        case .normal:
            return .blue
        case .insert:
            return .green
        case .visual, .visualLine:
            return .purple
        case .command:
            return .orange
        case .replace:
            return .red
        }
    }

    private func getPosition(in textView: NSTextView) -> (line: Int, column: Int) {
        let location = textView.selectedRange().location
        let string = textView.string as NSString

        var line = 1
        var lastLineStart = 0

        for i in 0..<location {
            if string.character(at: i) == 10 {
                line += 1
                lastLineStart = i + 1
            }
        }

        let column = location - lastLineStart + 1
        return (line, column)
    }
}

// MARK: - Note Editor View (Full)

struct NoteEditorViewFull: View {
    @StateObject private var viewModel: NoteEditorViewModel
    @StateObject private var vimState = VimState()
    @EnvironmentObject var appState: AppState
    @AppStorage("isVimModeEnabled") private var isVimModeEnabled = true

    init(noteId: String) {
        _viewModel = StateObject(wrappedValue: NoteEditorViewModel(noteId: noteId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let note = viewModel.note {
                // Title bar
                titleBar(note)

                Divider()

                // Editor
                MarkdownEditorView(
                    text: Binding(
                        get: { viewModel.note?.content ?? "" },
                        set: { viewModel.updateContent($0) }
                    ),
                    vimState: vimState,
                    onLinkClicked: { link in
                        handleLinkClick(link)
                    }
                )

                // Vim mode indicator
                if isVimModeEnabled {
                    VimModeIndicator(vimState: vimState)
                }

                // Backlinks panel
                if !viewModel.backlinks.isEmpty {
                    backlinkPanel
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Note not found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Title Bar

    @ViewBuilder
    private func titleBar(_ note: Note) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: note.isDailyNote ? "calendar.day.timeline.left" : "doc.text")
                .font(.title2)
                .foregroundColor(.accentColor)

            // Title
            TextField("Title", text: Binding(
                get: { viewModel.note?.title ?? "" },
                set: { viewModel.updateTitle($0) }
            ))
            .font(.title2.weight(.semibold))
            .textFieldStyle(.plain)

            Spacer()

            // Pin button
            Button(action: {
                viewModel.note?.isPinned.toggle()
                AsyncTask { await viewModel.save() }
            }) {
                Image(systemName: note.isPinned ? "pin.fill" : "pin")
                    .foregroundColor(note.isPinned ? .orange : .secondary)
            }
            .buttonStyle(.plain)

            // Save indicator
            if viewModel.isSaving {
                ProgressView()
                    .scaleEffect(0.7)
            } else if let lastSaved = viewModel.lastSaved {
                Text("Saved \(lastSaved.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Word count
            Text("\(viewModel.note?.wordCount ?? 0) words")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Backlinks Panel

    private var backlinkPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            DisclosureGroup("Backlinks (\(viewModel.backlinks.count))") {
                ForEach(viewModel.backlinks) { note in
                    Button(action: {
                        appState.selectedNoteId = note.id
                    }) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.secondary)
                            Text(note.title)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Link Handling

    private func handleLinkClick(_ link: String) {
        // Check if it's a wiki link
        AsyncTask {
            if let note = await viewModel.navigateToLink(link) {
                appState.selectedNoteId = note.id
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NoteEditorViewFull(noteId: "preview")
        .environmentObject(AppState())
}
