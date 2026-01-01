import Foundation
import AppKit

// MARK: - Vim Mode

enum VimMode: Equatable {
    case normal
    case insert
    case visual
    case visualLine
    case command
    case replace

    var displayName: String {
        switch self {
        case .normal: return "NORMAL"
        case .insert: return "INSERT"
        case .visual: return "VISUAL"
        case .visualLine: return "V-LINE"
        case .command: return "COMMAND"
        case .replace: return "REPLACE"
        }
    }

    var cursorStyle: NSCursor {
        switch self {
        case .normal, .visual, .visualLine:
            return .iBeam
        case .insert, .replace:
            return .iBeam
        case .command:
            return .arrow
        }
    }
}

// MARK: - Vim State

@MainActor
final class VimState: ObservableObject {
    @Published var mode: VimMode = .normal
    @Published var commandBuffer: String = ""
    @Published var statusMessage: String = ""
    @Published var count: Int = 1
    @Published var pendingOperator: VimOperator?
    @Published var lastSearch: String = ""
    @Published var searchDirection: SearchDirection = .forward
    @Published var registers: [Character: String] = [:]

    // Visual mode anchor
    var visualAnchor: Int?

    // Marks
    var marks: [Character: Int] = [:]

    // Last command for repeat (.)
    var lastCommand: VimCommand?

    // Text view reference for operations
    weak var textView: NSTextView?

    enum SearchDirection {
        case forward
        case backward
    }

    // MARK: - Mode Transitions

    func enterNormalMode() {
        mode = .normal
        commandBuffer = ""
        count = 1
        pendingOperator = nil
        visualAnchor = nil
        statusMessage = ""
    }

    func enterInsertMode(at position: InsertPosition = .cursor) {
        guard let textView = textView else { return }

        mode = .insert
        commandBuffer = ""
        statusMessage = "-- INSERT --"

        let range = textView.selectedRange()

        switch position {
        case .cursor:
            break
        case .afterCursor:
            if range.location < textView.string.count {
                textView.setSelectedRange(NSRange(location: range.location + 1, length: 0))
            }
        case .lineStart:
            let lineStart = findLineStart(from: range.location)
            let firstNonWhitespace = findFirstNonWhitespace(from: lineStart)
            textView.setSelectedRange(NSRange(location: firstNonWhitespace, length: 0))
        case .lineEnd:
            let lineEnd = findLineEnd(from: range.location)
            textView.setSelectedRange(NSRange(location: lineEnd, length: 0))
        case .newLineBelow:
            let lineEnd = findLineEnd(from: range.location)
            textView.setSelectedRange(NSRange(location: lineEnd, length: 0))
            textView.insertText("\n", replacementRange: NSRange(location: lineEnd, length: 0))
        case .newLineAbove:
            let lineStart = findLineStart(from: range.location)
            textView.setSelectedRange(NSRange(location: lineStart, length: 0))
            textView.insertText("\n", replacementRange: NSRange(location: lineStart, length: 0))
            textView.setSelectedRange(NSRange(location: lineStart, length: 0))
        }
    }

    func enterVisualMode() {
        guard let textView = textView else { return }

        mode = .visual
        visualAnchor = textView.selectedRange().location
        statusMessage = "-- VISUAL --"
    }

    func enterVisualLineMode() {
        guard let textView = textView else { return }

        mode = .visualLine
        visualAnchor = textView.selectedRange().location
        statusMessage = "-- VISUAL LINE --"
    }

    func enterCommandMode() {
        mode = .command
        commandBuffer = ":"
        statusMessage = ""
    }

    func enterReplaceMode() {
        mode = .replace
        statusMessage = "-- REPLACE --"
    }

    enum InsertPosition {
        case cursor
        case afterCursor
        case lineStart
        case lineEnd
        case newLineBelow
        case newLineAbove
    }

    // MARK: - Key Handling

    func handleKey(_ key: String, modifiers: NSEvent.ModifierFlags = []) -> Bool {
        switch mode {
        case .normal:
            return handleNormalModeKey(key, modifiers: modifiers)
        case .insert:
            return handleInsertModeKey(key, modifiers: modifiers)
        case .visual, .visualLine:
            return handleVisualModeKey(key, modifiers: modifiers)
        case .command:
            return handleCommandModeKey(key, modifiers: modifiers)
        case .replace:
            return handleReplaceModeKey(key, modifiers: modifiers)
        }
    }

    // MARK: - Normal Mode

    private func handleNormalModeKey(_ key: String, modifiers: NSEvent.ModifierFlags) -> Bool {
        // Handle Escape
        if key == "\u{1B}" {
            enterNormalMode()
            return true
        }

        // Handle count prefix
        if let digit = Int(key), digit >= 0 && digit <= 9 {
            if commandBuffer.isEmpty && digit == 0 {
                // '0' goes to line start
                return executeMotion(.lineStart)
            }
            commandBuffer += key
            if let newCount = Int(commandBuffer) {
                count = newCount
            }
            return true
        }

        // Add to command buffer
        commandBuffer += key

        // Try to parse and execute command
        if let command = parseCommand(commandBuffer) {
            let result = executeCommand(command)
            commandBuffer = ""
            count = 1
            return result
        }

        // Check if it could be a valid prefix
        if isValidCommandPrefix(commandBuffer) {
            return true
        }

        // Invalid command
        commandBuffer = ""
        count = 1
        return false
    }

    // MARK: - Insert Mode

    private func handleInsertModeKey(_ key: String, modifiers: NSEvent.ModifierFlags) -> Bool {
        // Escape to normal mode
        if key == "\u{1B}" {
            enterNormalMode()
            // Move cursor back one position
            if let textView = textView {
                let range = textView.selectedRange()
                if range.location > 0 {
                    textView.setSelectedRange(NSRange(location: range.location - 1, length: 0))
                }
            }
            return true
        }

        // Ctrl+[ also escapes
        if modifiers.contains(.control) && key == "[" {
            enterNormalMode()
            return true
        }

        // Let the text view handle normal input
        return false
    }

    // MARK: - Visual Mode

    private func handleVisualModeKey(_ key: String, modifiers: NSEvent.ModifierFlags) -> Bool {
        // Escape to normal mode
        if key == "\u{1B}" {
            enterNormalMode()
            return true
        }

        // Handle motions
        if let motion = parseMotion(key) {
            return executeVisualMotion(motion)
        }

        // Handle operators on selection
        switch key {
        case "d", "x":
            return executeVisualOperator(.delete)
        case "y":
            return executeVisualOperator(.yank)
        case "c":
            return executeVisualOperator(.change)
        case "v":
            if mode == .visual {
                enterNormalMode()
            } else {
                mode = .visual
                statusMessage = "-- VISUAL --"
            }
            return true
        case "V":
            if mode == .visualLine {
                enterNormalMode()
            } else {
                mode = .visualLine
                statusMessage = "-- VISUAL LINE --"
            }
            return true
        default:
            return false
        }
    }

    // MARK: - Command Mode

    private func handleCommandModeKey(_ key: String, modifiers: NSEvent.ModifierFlags) -> Bool {
        // Escape cancels
        if key == "\u{1B}" {
            enterNormalMode()
            return true
        }

        // Enter executes
        if key == "\r" {
            executeExCommand(String(commandBuffer.dropFirst())) // Remove ':'
            enterNormalMode()
            return true
        }

        // Backspace
        if key == "\u{7F}" {
            if commandBuffer.count > 1 {
                commandBuffer.removeLast()
            } else {
                enterNormalMode()
            }
            return true
        }

        // Add to command
        commandBuffer += key
        return true
    }

    // MARK: - Replace Mode

    private func handleReplaceModeKey(_ key: String, modifiers: NSEvent.ModifierFlags) -> Bool {
        // Escape to normal mode
        if key == "\u{1B}" {
            enterNormalMode()
            return true
        }

        // Replace character
        guard let textView = textView else { return false }
        let range = textView.selectedRange()

        if range.location < textView.string.count {
            textView.replaceCharacters(in: NSRange(location: range.location, length: 1), with: key)
            textView.setSelectedRange(NSRange(location: range.location + 1, length: 0))
        }

        enterNormalMode()
        return true
    }

    // MARK: - Command Parsing

    private func parseCommand(_ buffer: String) -> VimCommand? {
        // Simple motions
        if let motion = parseMotion(buffer) {
            return .motion(motion)
        }

        // Operators
        switch buffer {
        case "i":
            return .enterInsert(.cursor)
        case "I":
            return .enterInsert(.lineStart)
        case "a":
            return .enterInsert(.afterCursor)
        case "A":
            return .enterInsert(.lineEnd)
        case "o":
            return .enterInsert(.newLineBelow)
        case "O":
            return .enterInsert(.newLineAbove)
        case "v":
            return .enterVisual
        case "V":
            return .enterVisualLine
        case ":":
            return .enterCommand
        case "R":
            return .enterReplace
        case "x":
            return .deleteChar
        case "X":
            return .deleteCharBefore
        case "dd":
            return .deleteLine
        case "yy":
            return .yankLine
        case "cc":
            return .changeLine
        case "p":
            return .paste(.after)
        case "P":
            return .paste(.before)
        case "u":
            return .undo
        case ".":
            return .repeatLast
        case "J":
            return .joinLines
        case "~":
            return .toggleCase
        case ">>":
            return .indent
        case "<<":
            return .outdent
        case "gg":
            return .goToLine(1)
        case "G":
            return .goToLine(nil) // End of file
        case "ZZ":
            return .saveAndQuit
        case "ZQ":
            return .quitWithoutSaving
        default:
            break
        }

        // Operator + motion combinations
        if buffer.hasPrefix("d") && buffer.count > 1 {
            if let motion = parseMotion(String(buffer.dropFirst())) {
                return .operatorMotion(.delete, motion)
            }
        }

        if buffer.hasPrefix("c") && buffer.count > 1 {
            if let motion = parseMotion(String(buffer.dropFirst())) {
                return .operatorMotion(.change, motion)
            }
        }

        if buffer.hasPrefix("y") && buffer.count > 1 {
            if let motion = parseMotion(String(buffer.dropFirst())) {
                return .operatorMotion(.yank, motion)
            }
        }

        // Search
        if buffer.hasPrefix("/") {
            return nil // Wait for complete search
        }

        if buffer.hasPrefix("?") {
            return nil // Wait for complete search
        }

        // Find character
        if buffer.hasPrefix("f") && buffer.count == 2 {
            return .motion(.findChar(buffer.last!, forward: true, till: false))
        }

        if buffer.hasPrefix("F") && buffer.count == 2 {
            return .motion(.findChar(buffer.last!, forward: false, till: false))
        }

        if buffer.hasPrefix("t") && buffer.count == 2 {
            return .motion(.findChar(buffer.last!, forward: true, till: true))
        }

        if buffer.hasPrefix("T") && buffer.count == 2 {
            return .motion(.findChar(buffer.last!, forward: false, till: true))
        }

        // Replace single character
        if buffer.hasPrefix("r") && buffer.count == 2 {
            return .replaceChar(buffer.last!)
        }

        // Mark
        if buffer.hasPrefix("m") && buffer.count == 2 {
            return .setMark(buffer.last!)
        }

        // Go to mark
        if buffer.hasPrefix("'") && buffer.count == 2 {
            return .goToMark(buffer.last!)
        }
        if buffer.hasPrefix("`") && buffer.count == 2 {
            return .goToMark(buffer.last!)
        }

        return nil
    }

    private func parseMotion(_ buffer: String) -> VimMotion? {
        switch buffer {
        case "h":
            return .left
        case "j":
            return .down
        case "k":
            return .up
        case "l":
            return .right
        case "w":
            return .wordForward
        case "W":
            return .WORDForward
        case "b":
            return .wordBackward
        case "B":
            return .WORDBackward
        case "e":
            return .wordEnd
        case "E":
            return .WORDEnd
        case "0":
            return .lineStart
        case "^":
            return .firstNonWhitespace
        case "$":
            return .lineEnd
        case "{":
            return .paragraphBackward
        case "}":
            return .paragraphForward
        case "(":
            return .sentenceBackward
        case ")":
            return .sentenceForward
        case "n":
            return .searchNext
        case "N":
            return .searchPrevious
        case ";":
            return .repeatFind
        case ",":
            return .repeatFindReverse
        case "iw":
            return .innerWord
        case "aw":
            return .aroundWord
        case "i\"", "i'", "i`":
            return .innerQuote(buffer.last!)
        case "a\"", "a'", "a`":
            return .aroundQuote(buffer.last!)
        case "i(", "i)", "ib":
            return .innerParen
        case "a(", "a)", "ab":
            return .aroundParen
        case "i{", "i}", "iB":
            return .innerBrace
        case "a{", "a}", "aB":
            return .aroundBrace
        case "i[", "i]":
            return .innerBracket
        case "a[", "a]":
            return .aroundBracket
        default:
            return nil
        }
    }

    private func isValidCommandPrefix(_ buffer: String) -> Bool {
        let validPrefixes = ["d", "c", "y", "f", "F", "t", "T", "r", "m", "'", "`", "g", ">", "<", "Z", "/", "?", "i", "a"]
        return validPrefixes.contains(where: { buffer.hasPrefix($0) && buffer.count < 3 })
    }

    // MARK: - Command Execution

    private func executeCommand(_ command: VimCommand) -> Bool {
        lastCommand = command

        switch command {
        case .motion(let motion):
            return executeMotion(motion)
        case .enterInsert(let position):
            enterInsertMode(at: position)
            return true
        case .enterVisual:
            enterVisualMode()
            return true
        case .enterVisualLine:
            enterVisualLineMode()
            return true
        case .enterCommand:
            enterCommandMode()
            return true
        case .enterReplace:
            enterReplaceMode()
            return true
        case .deleteChar:
            return deleteCharacter(forward: true)
        case .deleteCharBefore:
            return deleteCharacter(forward: false)
        case .deleteLine:
            return deleteLine()
        case .yankLine:
            return yankLine()
        case .changeLine:
            return changeLine()
        case .paste(let position):
            return paste(position: position)
        case .undo:
            textView?.undoManager?.undo()
            return true
        case .repeatLast:
            if let last = lastCommand {
                return executeCommand(last)
            }
            return false
        case .operatorMotion(let op, let motion):
            return executeOperatorMotion(op, motion: motion)
        case .replaceChar(let char):
            return replaceCharacter(with: char)
        case .setMark(let mark):
            return setMark(mark)
        case .goToMark(let mark):
            return goToMark(mark)
        case .goToLine(let line):
            return goToLine(line)
        case .joinLines:
            return joinLines()
        case .toggleCase:
            return toggleCase()
        case .indent:
            return indent()
        case .outdent:
            return outdent()
        case .saveAndQuit, .quitWithoutSaving:
            // These need to be handled at a higher level
            statusMessage = "Use the standard save/close commands"
            return true
        }
    }

    // MARK: - Helpers

    private func findLineStart(from position: Int) -> Int {
        guard let textView = textView else { return position }
        let string = textView.string as NSString
        let lineRange = string.lineRange(for: NSRange(location: position, length: 0))
        return lineRange.location
    }

    private func findLineEnd(from position: Int) -> Int {
        guard let textView = textView else { return position }
        let string = textView.string as NSString
        let lineRange = string.lineRange(for: NSRange(location: position, length: 0))
        let endLocation = lineRange.location + lineRange.length
        // Don't include the newline
        if endLocation > 0 && endLocation <= string.length {
            let char = string.character(at: endLocation - 1)
            if char == 10 { // newline
                return endLocation - 1
            }
        }
        return endLocation
    }

    private func findFirstNonWhitespace(from position: Int) -> Int {
        guard let textView = textView else { return position }
        let string = textView.string
        let lineEnd = findLineEnd(from: position)

        var current = position
        while current < lineEnd {
            let index = string.index(string.startIndex, offsetBy: current)
            let char = string[index]
            if !char.isWhitespace {
                return current
            }
            current += 1
        }
        return position
    }

    // Motion execution and other operation implementations will be in VimMotions.swift
    func executeMotion(_ motion: VimMotion) -> Bool {
        return VimMotionExecutor.execute(motion, count: count, in: self)
    }

    func executeVisualMotion(_ motion: VimMotion) -> Bool {
        return VimMotionExecutor.executeVisual(motion, count: count, in: self)
    }

    func executeVisualOperator(_ op: VimOperator) -> Bool {
        return VimOperatorExecutor.executeVisual(op, in: self)
    }

    func executeOperatorMotion(_ op: VimOperator, motion: VimMotion) -> Bool {
        return VimOperatorExecutor.executeWithMotion(op, motion: motion, count: count, in: self)
    }

    func deleteCharacter(forward: Bool) -> Bool {
        return VimOperatorExecutor.deleteCharacter(forward: forward, count: count, in: self)
    }

    func deleteLine() -> Bool {
        return VimOperatorExecutor.deleteLine(count: count, in: self)
    }

    func yankLine() -> Bool {
        return VimOperatorExecutor.yankLine(count: count, in: self)
    }

    func changeLine() -> Bool {
        return VimOperatorExecutor.changeLine(count: count, in: self)
    }

    func paste(position: PastePosition) -> Bool {
        return VimOperatorExecutor.paste(position: position, in: self)
    }

    func replaceCharacter(with char: Character) -> Bool {
        return VimOperatorExecutor.replaceCharacter(with: char, in: self)
    }

    func setMark(_ mark: Character) -> Bool {
        guard let textView = textView else { return false }
        marks[mark] = textView.selectedRange().location
        statusMessage = "Mark '\(mark)' set"
        return true
    }

    func goToMark(_ mark: Character) -> Bool {
        guard let textView = textView, let position = marks[mark] else {
            statusMessage = "Mark '\(mark)' not set"
            return false
        }
        textView.setSelectedRange(NSRange(location: position, length: 0))
        return true
    }

    func goToLine(_ line: Int?) -> Bool {
        guard let textView = textView else { return false }

        if let line = line {
            let string = textView.string as NSString
            var lineCount = 1
            var position = 0

            while position < string.length && lineCount < line {
                if string.character(at: position) == 10 {
                    lineCount += 1
                }
                position += 1
            }

            textView.setSelectedRange(NSRange(location: position, length: 0))
        } else {
            // Go to end
            let length = textView.string.count
            textView.setSelectedRange(NSRange(location: length, length: 0))
        }
        return true
    }

    func joinLines() -> Bool {
        guard let textView = textView else { return false }

        let range = textView.selectedRange()
        let lineEnd = findLineEnd(from: range.location)
        let string = textView.string as NSString

        guard lineEnd < string.length else { return false }

        // Find next line start and first non-whitespace
        let nextLineStart = lineEnd + 1
        var firstNonWhitespace = nextLineStart
        while firstNonWhitespace < string.length {
            let char = string.character(at: firstNonWhitespace)
            if char != 32 && char != 9 { // space and tab
                break
            }
            firstNonWhitespace += 1
        }

        // Replace newline and leading whitespace with space
        let replaceRange = NSRange(location: lineEnd, length: firstNonWhitespace - lineEnd)
        textView.replaceCharacters(in: replaceRange, with: " ")

        return true
    }

    func toggleCase() -> Bool {
        guard let textView = textView else { return false }

        let range = textView.selectedRange()
        guard range.location < textView.string.count else { return false }

        let string = textView.string as NSString
        let char = String(UnicodeScalar(string.character(at: range.location))!)

        let toggled = char.uppercased() == char ? char.lowercased() : char.uppercased()
        textView.replaceCharacters(in: NSRange(location: range.location, length: 1), with: toggled)

        return true
    }

    func indent() -> Bool {
        guard let textView = textView else { return false }

        let range = textView.selectedRange()
        let lineStart = findLineStart(from: range.location)
        textView.replaceCharacters(in: NSRange(location: lineStart, length: 0), with: "    ")

        return true
    }

    func outdent() -> Bool {
        guard let textView = textView else { return false }

        let range = textView.selectedRange()
        let lineStart = findLineStart(from: range.location)
        let string = textView.string as NSString

        var removeCount = 0
        for i in 0..<4 {
            let pos = lineStart + i
            guard pos < string.length else { break }
            let char = string.character(at: pos)
            if char == 32 { // space
                removeCount += 1
            } else if char == 9 { // tab
                removeCount += 1
                break
            } else {
                break
            }
        }

        if removeCount > 0 {
            textView.replaceCharacters(in: NSRange(location: lineStart, length: removeCount), with: "")
        }

        return true
    }

    func executeExCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespaces)

        switch trimmed {
        case "w":
            statusMessage = "Use Cmd+S to save"
        case "q":
            statusMessage = "Use Cmd+W to close"
        case "wq", "x":
            statusMessage = "Use Cmd+S then Cmd+W"
        case "q!":
            statusMessage = "Use Cmd+W to close without saving"
        default:
            if trimmed.hasPrefix("set") {
                statusMessage = "Settings not yet implemented"
            } else if let lineNum = Int(trimmed) {
                _ = goToLine(lineNum)
            } else {
                statusMessage = "Unknown command: \(trimmed)"
            }
        }
    }
}

// MARK: - Vim Command

enum VimCommand {
    case motion(VimMotion)
    case enterInsert(VimState.InsertPosition)
    case enterVisual
    case enterVisualLine
    case enterCommand
    case enterReplace
    case deleteChar
    case deleteCharBefore
    case deleteLine
    case yankLine
    case changeLine
    case paste(PastePosition)
    case undo
    case repeatLast
    case operatorMotion(VimOperator, VimMotion)
    case replaceChar(Character)
    case setMark(Character)
    case goToMark(Character)
    case goToLine(Int?)
    case joinLines
    case toggleCase
    case indent
    case outdent
    case saveAndQuit
    case quitWithoutSaving
}

enum PastePosition {
    case before
    case after
}

// MARK: - Vim Operator

enum VimOperator {
    case delete
    case change
    case yank
    case indent
    case outdent
    case format
}
