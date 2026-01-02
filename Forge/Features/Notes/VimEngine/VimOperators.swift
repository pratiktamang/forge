import Foundation
import AppKit

// MARK: - Operator Executor

@MainActor
struct VimOperatorExecutor {

    // MARK: - Visual Mode Operations

    static func executeVisual(_ op: VimOperator, in state: VimState) -> Bool {
        guard let textView = state.textView else { return false }

        let range = textView.selectedRange()
        guard range.length > 0 else { return false }

        let string = textView.string as NSString
        let selectedText = string.substring(with: range)

        switch op {
        case .delete:
            // Yank before delete
            state.registers["\""] = selectedText
            state.registers["0"] = selectedText

            if textView.shouldChangeText(in: range, replacementString: "") {
                textView.replaceCharacters(in: range, with: "")
                textView.didChangeText()
            }
            state.enterNormalMode()
            return true

        case .yank:
            state.registers["\""] = selectedText
            state.registers["0"] = selectedText
            state.statusMessage = "\(range.length) characters yanked"

            // Return to normal mode and position at start of selection
            textView.setSelectedRange(NSRange(location: range.location, length: 0))
            state.enterNormalMode()
            return true

        case .change:
            // Yank before change
            state.registers["\""] = selectedText
            state.registers["0"] = selectedText

            textView.replaceCharacters(in: range, with: "")
            state.enterInsertMode()
            return true

        case .indent:
            return indentRange(range, in: textView)

        case .outdent:
            return outdentRange(range, in: textView)

        case .format:
            // Not implemented
            return false
        }
    }

    // MARK: - Operator + Motion

    static func executeWithMotion(_ op: VimOperator, motion: VimMotion, count: Int, in state: VimState) -> Bool {
        guard let textView = state.textView else { return false }

        let startRange = textView.selectedRange()
        let startLocation = startRange.location

        // Get the range that the motion covers
        guard let range = getMotionRange(motion, count: count, from: startLocation, in: textView, state: state) else {
            return false
        }

        let string = textView.string as NSString
        let text = string.substring(with: range)

        switch op {
        case .delete:
            state.registers["\""] = text
            state.registers["0"] = text

            textView.replaceCharacters(in: range, with: "")

            // Position cursor appropriately
            let newLocation = min(range.location, textView.string.count - 1)
            textView.setSelectedRange(NSRange(location: max(0, newLocation), length: 0))
            return true

        case .change:
            state.registers["\""] = text
            state.registers["0"] = text

            textView.replaceCharacters(in: range, with: "")
            state.enterInsertMode()
            return true

        case .yank:
            state.registers["\""] = text
            state.registers["0"] = text
            state.statusMessage = "\(range.length) characters yanked"

            // Return cursor to original position
            textView.setSelectedRange(NSRange(location: startLocation, length: 0))
            return true

        case .indent:
            return indentRange(range, in: textView)

        case .outdent:
            return outdentRange(range, in: textView)

        case .format:
            return false
        }
    }

    // MARK: - Character Operations

    static func deleteCharacter(forward: Bool, count: Int, in state: VimState) -> Bool {
        guard let textView = state.textView else { return false }

        let range = textView.selectedRange()
        let string = textView.string as NSString

        if forward {
            // 'x' - delete character under cursor
            guard range.location < string.length else { return false }

            let deleteCount = min(count, string.length - range.location)
            let deleteRange = NSRange(location: range.location, length: deleteCount)
            let deleted = string.substring(with: deleteRange)

            state.registers["\""] = deleted

            textView.replaceCharacters(in: deleteRange, with: "")
        } else {
            // 'X' - delete character before cursor
            guard range.location > 0 else { return false }

            let deleteCount = min(count, range.location)
            let deleteRange = NSRange(location: range.location - deleteCount, length: deleteCount)
            let deleted = string.substring(with: deleteRange)

            state.registers["\""] = deleted

            textView.replaceCharacters(in: deleteRange, with: "")
        }

        return true
    }

    // MARK: - Line Operations

    static func deleteLine(count: Int, in state: VimState) -> Bool {
        guard let textView = state.textView else { return false }

        let range = textView.selectedRange()
        let string = textView.string as NSString

        var lineStart = range.location
        var lineEnd = range.location

        // Find start of current line
        while lineStart > 0 && string.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        // Find end of last line to delete
        var linesRemaining = count
        while linesRemaining > 0 && lineEnd < string.length {
            if string.character(at: lineEnd) == 10 {
                linesRemaining -= 1
                if linesRemaining == 0 {
                    lineEnd += 1 // Include the newline
                    break
                }
            }
            lineEnd += 1
        }

        let deleteRange = NSRange(location: lineStart, length: lineEnd - lineStart)
        let deleted = string.substring(with: deleteRange)

        state.registers["\""] = deleted
        state.registers["0"] = deleted
        state.registers["1"] = deleted // Line register

        if textView.shouldChangeText(in: deleteRange, replacementString: "") {
            textView.replaceCharacters(in: deleteRange, with: "")
            textView.didChangeText()
        }

        // Position at first non-whitespace of next line
        let newLocation = min(lineStart, textView.string.count)
        textView.setSelectedRange(NSRange(location: newLocation, length: 0))

        state.statusMessage = count == 1 ? "1 line deleted" : "\(count) lines deleted"
        return true
    }

    static func yankLine(count: Int, in state: VimState) -> Bool {
        guard let textView = state.textView else { return false }

        let range = textView.selectedRange()
        let string = textView.string as NSString

        var lineStart = range.location
        var lineEnd = range.location

        // Find start of current line
        while lineStart > 0 && string.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        // Find end of last line to yank
        var linesRemaining = count
        while linesRemaining > 0 && lineEnd < string.length {
            if string.character(at: lineEnd) == 10 {
                linesRemaining -= 1
                if linesRemaining == 0 {
                    lineEnd += 1 // Include the newline
                    break
                }
            }
            lineEnd += 1
        }

        let yankRange = NSRange(location: lineStart, length: lineEnd - lineStart)
        let yanked = string.substring(with: yankRange)

        state.registers["\""] = yanked
        state.registers["0"] = yanked
        state.registers["1"] = yanked

        state.statusMessage = count == 1 ? "1 line yanked" : "\(count) lines yanked"
        return true
    }

    static func changeLine(count: Int, in state: VimState) -> Bool {
        guard let textView = state.textView else { return false }

        let range = textView.selectedRange()
        let string = textView.string as NSString

        var lineStart = range.location
        var lineEnd = range.location

        // Find start of current line
        while lineStart > 0 && string.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        // Find first non-whitespace
        var firstNonWhitespace = lineStart
        while firstNonWhitespace < string.length {
            let char = string.character(at: firstNonWhitespace)
            if char != 32 && char != 9 { // space and tab
                break
            }
            firstNonWhitespace += 1
        }

        // Find end of last line (but don't include newline for change)
        var linesRemaining = count
        while linesRemaining > 0 && lineEnd < string.length {
            if string.character(at: lineEnd) == 10 {
                linesRemaining -= 1
                if linesRemaining == 0 {
                    break // Don't include the newline
                }
            }
            lineEnd += 1
        }

        // Delete from first non-whitespace to end of line
        let deleteRange = NSRange(location: firstNonWhitespace, length: lineEnd - firstNonWhitespace)
        let deleted = string.substring(with: deleteRange)

        state.registers["\""] = deleted

        textView.replaceCharacters(in: deleteRange, with: "")
        textView.setSelectedRange(NSRange(location: firstNonWhitespace, length: 0))

        state.enterInsertMode()
        return true
    }

    // MARK: - Paste

    static func paste(position: PastePosition, in state: VimState) -> Bool {
        guard let textView = state.textView else { return false }
        guard let text = state.registers["\""] else {
            state.statusMessage = "Nothing to paste"
            return false
        }

        let range = textView.selectedRange()
        let isLinewise = text.hasSuffix("\n")

        var insertLocation: Int

        if isLinewise {
            let string = textView.string as NSString
            let lineRange = string.lineRange(for: NSRange(location: range.location, length: 0))

            if position == .after {
                // Paste below current line
                insertLocation = lineRange.location + lineRange.length
            } else {
                // Paste above current line
                insertLocation = lineRange.location
            }
        } else {
            if position == .after {
                insertLocation = min(range.location + 1, textView.string.count)
            } else {
                insertLocation = range.location
            }
        }

        textView.replaceCharacters(in: NSRange(location: insertLocation, length: 0), with: text)

        // Position cursor
        if isLinewise {
            // Move to first non-whitespace of pasted line
            textView.setSelectedRange(NSRange(location: insertLocation, length: 0))
        } else {
            textView.setSelectedRange(NSRange(location: insertLocation + text.count - 1, length: 0))
        }

        return true
    }

    // MARK: - Replace Character

    static func replaceCharacter(with char: Character, in state: VimState) -> Bool {
        guard let textView = state.textView else { return false }

        let range = textView.selectedRange()
        guard range.location < textView.string.count else { return false }

        textView.replaceCharacters(in: NSRange(location: range.location, length: 1), with: String(char))
        return true
    }

    // MARK: - Helpers

    private static func getMotionRange(_ motion: VimMotion, count: Int, from location: Int, in textView: NSTextView, state: VimState) -> NSRange? {
        let string = textView.string as NSString

        // Check for text objects first
        if let textObjectRange = VimMotionExecutor.getTextObjectRange(motion, from: location, in: textView) {
            return textObjectRange
        }

        // Calculate end position by simulating motion
        var endLocation = location

        for _ in 0..<count {
            let tempLocation = simulateMotion(motion, from: endLocation, in: textView)
            if tempLocation == endLocation {
                break // Motion didn't move
            }
            endLocation = tempLocation
        }

        // Determine range based on motion type
        switch motion {
        case .left, .wordBackward, .WORDBackward:
            return NSRange(location: endLocation, length: location - endLocation)

        case .right, .wordForward, .WORDForward, .wordEnd, .WORDEnd:
            return NSRange(location: location, length: endLocation - location + 1)

        case .lineEnd:
            return NSRange(location: location, length: endLocation - location + 1)

        case .lineStart, .firstNonWhitespace:
            if endLocation < location {
                return NSRange(location: endLocation, length: location - endLocation)
            } else {
                return NSRange(location: location, length: endLocation - location)
            }

        case .up:
            let currentLineRange = string.lineRange(for: NSRange(location: location, length: 0))
            let targetLineRange = string.lineRange(for: NSRange(location: endLocation, length: 0))
            return NSRange(location: targetLineRange.location, length: currentLineRange.location + currentLineRange.length - targetLineRange.location)

        case .down:
            let currentLineRange = string.lineRange(for: NSRange(location: location, length: 0))
            let targetLineRange = string.lineRange(for: NSRange(location: endLocation, length: 0))
            return NSRange(location: currentLineRange.location, length: targetLineRange.location + targetLineRange.length - currentLineRange.location)

        case .findChar(_, _, _):
            if endLocation > location {
                return NSRange(location: location, length: endLocation - location + 1)
            } else if endLocation < location {
                return NSRange(location: endLocation, length: location - endLocation)
            }
            return nil

        case .paragraphForward, .paragraphBackward, .sentenceForward, .sentenceBackward:
            if endLocation > location {
                return NSRange(location: location, length: endLocation - location)
            } else {
                return NSRange(location: endLocation, length: location - endLocation)
            }

        default:
            return nil
        }
    }

    private static func simulateMotion(_ motion: VimMotion, from location: Int, in textView: NSTextView) -> Int {
        // Store current selection
        let savedRange = textView.selectedRange()

        // Set position
        textView.setSelectedRange(NSRange(location: location, length: 0))

        // This is a bit of a hack - we'd normally calculate without modifying the view
        // For now, manually calculate based on motion type
        let string = textView.string as NSString
        var newLocation = location

        switch motion {
        case .left:
            newLocation = max(0, location - 1)
        case .right:
            newLocation = min(string.length - 1, location + 1)
        case .wordForward:
            newLocation = findNextWordStart(from: location, in: string)
        case .wordBackward:
            newLocation = findPrevWordStart(from: location, in: string)
        case .wordEnd:
            newLocation = findWordEnd(from: location, in: string)
        case .lineStart:
            let lineRange = string.lineRange(for: NSRange(location: location, length: 0))
            newLocation = lineRange.location
        case .lineEnd:
            let lineRange = string.lineRange(for: NSRange(location: location, length: 0))
            newLocation = lineRange.location + lineRange.length - 1
            if newLocation >= 0 && string.character(at: newLocation) == 10 {
                newLocation = max(lineRange.location, newLocation - 1)
            }
        case .up:
            let lineRange = string.lineRange(for: NSRange(location: location, length: 0))
            if lineRange.location > 0 {
                let prevLineRange = string.lineRange(for: NSRange(location: lineRange.location - 1, length: 0))
                let column = location - lineRange.location
                newLocation = prevLineRange.location + min(column, prevLineRange.length - 1)
            }
        case .down:
            let lineRange = string.lineRange(for: NSRange(location: location, length: 0))
            let nextLineStart = lineRange.location + lineRange.length
            if nextLineStart < string.length {
                let nextLineRange = string.lineRange(for: NSRange(location: nextLineStart, length: 0))
                let column = location - lineRange.location
                newLocation = nextLineRange.location + min(column, max(0, nextLineRange.length - 1))
            }
        case .findChar(let char, let forward, let till):
            if forward {
                var pos = location + 1
                while pos < string.length {
                    if string.character(at: pos) == char.asciiValue! {
                        newLocation = till ? pos - 1 : pos
                        break
                    }
                    if string.character(at: pos) == 10 { break }
                    pos += 1
                }
            } else {
                var pos = location - 1
                while pos >= 0 {
                    if string.character(at: pos) == char.asciiValue! {
                        newLocation = till ? pos + 1 : pos
                        break
                    }
                    if string.character(at: pos) == 10 { break }
                    pos -= 1
                }
            }
        default:
            break
        }

        // Restore selection
        textView.setSelectedRange(savedRange)

        return newLocation
    }

    private static func findNextWordStart(from location: Int, in string: NSString) -> Int {
        var pos = location

        // Skip current word
        while pos < string.length {
            let char = Character(UnicodeScalar(string.character(at: pos))!)
            if char.isWhitespace || (!char.isLetter && !char.isNumber && char != "_") {
                break
            }
            pos += 1
        }

        // Skip whitespace/punctuation
        while pos < string.length {
            let char = Character(UnicodeScalar(string.character(at: pos))!)
            if char.isLetter || char.isNumber || char == "_" {
                return pos
            }
            pos += 1
        }

        return min(pos, string.length)
    }

    private static func findPrevWordStart(from location: Int, in string: NSString) -> Int {
        var pos = location - 1

        // Skip whitespace
        while pos >= 0 {
            let char = Character(UnicodeScalar(string.character(at: pos))!)
            if !char.isWhitespace {
                break
            }
            pos -= 1
        }

        // Skip to start of word
        while pos > 0 {
            let char = Character(UnicodeScalar(string.character(at: pos - 1))!)
            if !char.isLetter && !char.isNumber && char != "_" {
                return pos
            }
            pos -= 1
        }

        return max(0, pos)
    }

    private static func findWordEnd(from location: Int, in string: NSString) -> Int {
        var pos = location + 1

        // Skip whitespace first
        while pos < string.length {
            let char = Character(UnicodeScalar(string.character(at: pos))!)
            if !char.isWhitespace {
                break
            }
            pos += 1
        }

        // Find end of word
        while pos < string.length - 1 {
            let nextChar = Character(UnicodeScalar(string.character(at: pos + 1))!)
            if !nextChar.isLetter && !nextChar.isNumber && nextChar != "_" {
                return pos
            }
            pos += 1
        }

        return min(pos, string.length - 1)
    }

    // MARK: - Indent/Outdent

    private static func indentRange(_ range: NSRange, in textView: NSTextView) -> Bool {
        let string = textView.string as NSString

        // Find all lines in range
        var lineStart = range.location
        while lineStart > 0 && string.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        var lineEnd = range.location + range.length
        while lineEnd < string.length && string.character(at: lineEnd) != 10 {
            lineEnd += 1
        }

        // Process each line
        var currentPos = lineStart
        var insertions: [(Int, String)] = []

        while currentPos <= lineEnd && currentPos < string.length {
            insertions.append((currentPos, "    "))

            // Find next line
            while currentPos < string.length && string.character(at: currentPos) != 10 {
                currentPos += 1
            }
            currentPos += 1 // Skip newline
        }

        // Apply insertions in reverse order
        for (pos, indent) in insertions.reversed() {
            textView.replaceCharacters(in: NSRange(location: pos, length: 0), with: indent)
        }

        return true
    }

    private static func outdentRange(_ range: NSRange, in textView: NSTextView) -> Bool {
        let string = textView.string as NSString

        // Find all lines in range
        var lineStart = range.location
        while lineStart > 0 && string.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        var lineEnd = range.location + range.length
        while lineEnd < string.length && string.character(at: lineEnd) != 10 {
            lineEnd += 1
        }

        // Process each line
        var currentPos = lineStart
        var deletions: [(Int, Int)] = []

        while currentPos <= lineEnd && currentPos < string.length {
            var removeCount = 0
            for i in 0..<4 {
                let pos = currentPos + i
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
                deletions.append((currentPos, removeCount))
            }

            // Find next line
            while currentPos < string.length && string.character(at: currentPos) != 10 {
                currentPos += 1
            }
            currentPos += 1 // Skip newline
        }

        // Apply deletions in reverse order
        for (pos, count) in deletions.reversed() {
            textView.replaceCharacters(in: NSRange(location: pos, length: count), with: "")
        }

        return true
    }
}
