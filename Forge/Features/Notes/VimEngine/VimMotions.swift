import Foundation
import AppKit

// MARK: - Vim Motion

enum VimMotion {
    // Basic movements
    case left
    case down
    case up
    case right

    // Word movements
    case wordForward
    case wordBackward
    case wordEnd
    case WORDForward
    case WORDBackward
    case WORDEnd

    // Line movements
    case lineStart
    case lineEnd
    case firstNonWhitespace

    // Paragraph/Sentence
    case paragraphForward
    case paragraphBackward
    case sentenceForward
    case sentenceBackward

    // Search
    case searchNext
    case searchPrevious
    case findChar(Character, forward: Bool, till: Bool)
    case repeatFind
    case repeatFindReverse

    // Text objects
    case innerWord
    case aroundWord
    case innerQuote(Character)
    case aroundQuote(Character)
    case innerParen
    case aroundParen
    case innerBrace
    case aroundBrace
    case innerBracket
    case aroundBracket
}

// MARK: - Motion Executor

@MainActor
struct VimMotionExecutor {

    static func execute(_ motion: VimMotion, count: Int, in state: VimState) -> Bool {
        guard let textView = state.textView else { return false }

        let range = textView.selectedRange()
        var newLocation = range.location

        for _ in 0..<count {
            switch motion {
            case .left:
                newLocation = moveLeft(from: newLocation, in: textView)
            case .right:
                newLocation = moveRight(from: newLocation, in: textView)
            case .up:
                newLocation = moveUp(from: newLocation, in: textView)
            case .down:
                newLocation = moveDown(from: newLocation, in: textView)
            case .wordForward:
                newLocation = moveWordForward(from: newLocation, in: textView, bigWord: false)
            case .wordBackward:
                newLocation = moveWordBackward(from: newLocation, in: textView, bigWord: false)
            case .wordEnd:
                newLocation = moveWordEnd(from: newLocation, in: textView, bigWord: false)
            case .WORDForward:
                newLocation = moveWordForward(from: newLocation, in: textView, bigWord: true)
            case .WORDBackward:
                newLocation = moveWordBackward(from: newLocation, in: textView, bigWord: true)
            case .WORDEnd:
                newLocation = moveWordEnd(from: newLocation, in: textView, bigWord: true)
            case .lineStart:
                newLocation = moveToLineStart(from: newLocation, in: textView)
            case .lineEnd:
                newLocation = moveToLineEnd(from: newLocation, in: textView)
            case .firstNonWhitespace:
                newLocation = moveToFirstNonWhitespace(from: newLocation, in: textView)
            case .paragraphForward:
                newLocation = moveParagraphForward(from: newLocation, in: textView)
            case .paragraphBackward:
                newLocation = moveParagraphBackward(from: newLocation, in: textView)
            case .sentenceForward:
                newLocation = moveSentenceForward(from: newLocation, in: textView)
            case .sentenceBackward:
                newLocation = moveSentenceBackward(from: newLocation, in: textView)
            case .searchNext:
                if let found = searchNext(from: newLocation, pattern: state.lastSearch, forward: state.searchDirection == .forward, in: textView) {
                    newLocation = found
                }
            case .searchPrevious:
                if let found = searchNext(from: newLocation, pattern: state.lastSearch, forward: state.searchDirection != .forward, in: textView) {
                    newLocation = found
                }
            case .findChar(let char, let forward, let till):
                if let found = findCharacter(char, from: newLocation, forward: forward, till: till, in: textView) {
                    newLocation = found
                }
            case .repeatFind, .repeatFindReverse:
                // Would need to track last find
                break
            case .innerWord, .aroundWord, .innerQuote, .aroundQuote,
                 .innerParen, .aroundParen, .innerBrace, .aroundBrace,
                 .innerBracket, .aroundBracket:
                // Text objects return ranges, handled differently
                break
            }
        }

        textView.setSelectedRange(NSRange(location: newLocation, length: 0))
        textView.scrollRangeToVisible(NSRange(location: newLocation, length: 0))
        return true
    }

    static func executeVisual(_ motion: VimMotion, count: Int, in state: VimState) -> Bool {
        guard let textView = state.textView,
              let anchor = state.visualAnchor else { return false }

        let range = textView.selectedRange()
        var newLocation = range.location + range.length

        for _ in 0..<count {
            switch motion {
            case .left:
                newLocation = moveLeft(from: newLocation, in: textView)
            case .right:
                newLocation = moveRight(from: newLocation, in: textView)
            case .up:
                newLocation = moveUp(from: newLocation, in: textView)
            case .down:
                newLocation = moveDown(from: newLocation, in: textView)
            case .wordForward:
                newLocation = moveWordForward(from: newLocation, in: textView, bigWord: false)
            case .wordBackward:
                newLocation = moveWordBackward(from: newLocation, in: textView, bigWord: false)
            case .wordEnd:
                newLocation = moveWordEnd(from: newLocation, in: textView, bigWord: false)
            case .WORDForward:
                newLocation = moveWordForward(from: newLocation, in: textView, bigWord: true)
            case .WORDBackward:
                newLocation = moveWordBackward(from: newLocation, in: textView, bigWord: true)
            case .WORDEnd:
                newLocation = moveWordEnd(from: newLocation, in: textView, bigWord: true)
            case .lineStart:
                newLocation = moveToLineStart(from: newLocation, in: textView)
            case .lineEnd:
                newLocation = moveToLineEnd(from: newLocation, in: textView)
            case .firstNonWhitespace:
                newLocation = moveToFirstNonWhitespace(from: newLocation, in: textView)
            case .paragraphForward:
                newLocation = moveParagraphForward(from: newLocation, in: textView)
            case .paragraphBackward:
                newLocation = moveParagraphBackward(from: newLocation, in: textView)
            default:
                break
            }
        }

        // Update selection based on anchor and new location
        let start = min(anchor, newLocation)
        let end = max(anchor, newLocation)

        if state.mode == .visualLine {
            // Expand to full lines
            let lineStart = moveToLineStart(from: start, in: textView)
            var lineEnd = moveToLineEnd(from: end, in: textView)
            if lineEnd < textView.string.count {
                lineEnd += 1 // Include newline
            }
            textView.setSelectedRange(NSRange(location: lineStart, length: lineEnd - lineStart))
        } else {
            textView.setSelectedRange(NSRange(location: start, length: end - start + 1))
        }

        return true
    }

    // MARK: - Text Object Ranges

    static func getTextObjectRange(_ motion: VimMotion, from location: Int, in textView: NSTextView) -> NSRange? {
        let string = textView.string as NSString

        switch motion {
        case .innerWord:
            return getWordRange(from: location, in: string, around: false)
        case .aroundWord:
            return getWordRange(from: location, in: string, around: true)
        case .innerQuote(let quote):
            return getQuoteRange(quote: quote, from: location, in: string, around: false)
        case .aroundQuote(let quote):
            return getQuoteRange(quote: quote, from: location, in: string, around: true)
        case .innerParen:
            return getMatchedRange(open: "(", close: ")", from: location, in: string, around: false)
        case .aroundParen:
            return getMatchedRange(open: "(", close: ")", from: location, in: string, around: true)
        case .innerBrace:
            return getMatchedRange(open: "{", close: "}", from: location, in: string, around: false)
        case .aroundBrace:
            return getMatchedRange(open: "{", close: "}", from: location, in: string, around: true)
        case .innerBracket:
            return getMatchedRange(open: "[", close: "]", from: location, in: string, around: false)
        case .aroundBracket:
            return getMatchedRange(open: "[", close: "]", from: location, in: string, around: true)
        default:
            return nil
        }
    }

    // MARK: - Basic Movements

    private static func moveLeft(from location: Int, in textView: NSTextView) -> Int {
        guard location > 0 else { return location }

        // Don't move past line start in normal mode
        let string = textView.string as NSString
        if location > 0 && string.character(at: location - 1) == 10 {
            return location
        }

        return location - 1
    }

    private static func moveRight(from location: Int, in textView: NSTextView) -> Int {
        let string = textView.string as NSString
        guard location < string.length else { return location }

        // Don't move past line end (onto newline)
        if string.character(at: location) == 10 {
            return location
        }

        return location + 1
    }

    private static func moveUp(from location: Int, in textView: NSTextView) -> Int {
        let string = textView.string as NSString
        let lineRange = string.lineRange(for: NSRange(location: location, length: 0))

        // Already at first line
        if lineRange.location == 0 {
            return location
        }

        // Column in current line
        let column = location - lineRange.location

        // Find previous line
        let prevLineEnd = lineRange.location - 1
        let prevLineRange = string.lineRange(for: NSRange(location: prevLineEnd, length: 0))
        let prevLineLength = prevLineRange.length - 1 // Exclude newline

        // Move to same column or end of line
        return prevLineRange.location + min(column, max(0, prevLineLength))
    }

    private static func moveDown(from location: Int, in textView: NSTextView) -> Int {
        let string = textView.string as NSString
        let lineRange = string.lineRange(for: NSRange(location: location, length: 0))

        let nextLineStart = lineRange.location + lineRange.length

        // Already at last line
        if nextLineStart >= string.length {
            return location
        }

        // Column in current line
        let column = location - lineRange.location

        // Find next line length
        let nextLineRange = string.lineRange(for: NSRange(location: nextLineStart, length: 0))
        let nextLineLength = nextLineRange.length - 1 // Exclude newline

        // Move to same column or end of line
        return nextLineStart + min(column, max(0, nextLineLength))
    }

    // MARK: - Word Movements

    private static func moveWordForward(from location: Int, in textView: NSTextView, bigWord: Bool) -> Int {
        let string = textView.string
        var pos = location

        guard pos < string.count else { return pos }

        let index = string.index(string.startIndex, offsetBy: pos)
        var isInWord = !string[index].isWhitespace

        // Skip current word
        while pos < string.count {
            let idx = string.index(string.startIndex, offsetBy: pos)
            let char = string[idx]

            if bigWord {
                if char.isWhitespace {
                    isInWord = false
                } else if !isInWord {
                    return pos
                }
            } else {
                let isWordChar = char.isLetter || char.isNumber || char == "_"
                if !isWordChar && isInWord {
                    // Crossed word boundary, check if punctuation
                    if !char.isWhitespace {
                        return pos
                    }
                    isInWord = false
                } else if isWordChar && !isInWord {
                    return pos
                }
            }
            pos += 1
        }

        return pos
    }

    private static func moveWordBackward(from location: Int, in textView: NSTextView, bigWord: Bool) -> Int {
        let string = textView.string
        var pos = location - 1

        guard pos >= 0 else { return 0 }

        // Skip whitespace
        while pos >= 0 {
            let idx = string.index(string.startIndex, offsetBy: pos)
            if !string[idx].isWhitespace {
                break
            }
            pos -= 1
        }

        guard pos >= 0 else { return 0 }

        // Find start of word
        let idx = string.index(string.startIndex, offsetBy: pos)
        let startedOnWord = string[idx].isLetter || string[idx].isNumber || string[idx] == "_"

        while pos > 0 {
            let prevIdx = string.index(string.startIndex, offsetBy: pos - 1)
            let char = string[prevIdx]

            if bigWord {
                if char.isWhitespace {
                    return pos
                }
            } else {
                let isWordChar = char.isLetter || char.isNumber || char == "_"
                if startedOnWord && !isWordChar {
                    return pos
                } else if !startedOnWord && isWordChar {
                    return pos
                }
            }
            pos -= 1
        }

        return 0
    }

    private static func moveWordEnd(from location: Int, in textView: NSTextView, bigWord: Bool) -> Int {
        let string = textView.string
        var pos = location + 1

        guard pos < string.count else { return string.count - 1 }

        // Skip whitespace
        while pos < string.count {
            let idx = string.index(string.startIndex, offsetBy: pos)
            if !string[idx].isWhitespace {
                break
            }
            pos += 1
        }

        guard pos < string.count else { return string.count - 1 }

        // Find end of word
        let idx = string.index(string.startIndex, offsetBy: pos)
        let startedOnWord = string[idx].isLetter || string[idx].isNumber || string[idx] == "_"

        while pos < string.count - 1 {
            let nextIdx = string.index(string.startIndex, offsetBy: pos + 1)
            let char = string[nextIdx]

            if bigWord {
                if char.isWhitespace {
                    return pos
                }
            } else {
                let isWordChar = char.isLetter || char.isNumber || char == "_"
                if startedOnWord && !isWordChar {
                    return pos
                } else if !startedOnWord && (isWordChar || char.isWhitespace) {
                    return pos
                }
            }
            pos += 1
        }

        return pos
    }

    // MARK: - Line Movements

    private static func moveToLineStart(from location: Int, in textView: NSTextView) -> Int {
        let string = textView.string as NSString
        let lineRange = string.lineRange(for: NSRange(location: location, length: 0))
        return lineRange.location
    }

    private static func moveToLineEnd(from location: Int, in textView: NSTextView) -> Int {
        let string = textView.string as NSString
        let lineRange = string.lineRange(for: NSRange(location: location, length: 0))
        let endLocation = lineRange.location + lineRange.length

        // Don't include newline
        if endLocation > 0 && endLocation <= string.length {
            let char = string.character(at: endLocation - 1)
            if char == 10 {
                return max(lineRange.location, endLocation - 1)
            }
        }
        return max(lineRange.location, endLocation - 1)
    }

    private static func moveToFirstNonWhitespace(from location: Int, in textView: NSTextView) -> Int {
        let string = textView.string
        let lineStart = moveToLineStart(from: location, in: textView)
        let lineEnd = moveToLineEnd(from: location, in: textView)

        var pos = lineStart
        while pos <= lineEnd {
            let idx = string.index(string.startIndex, offsetBy: pos)
            if !string[idx].isWhitespace {
                return pos
            }
            pos += 1
        }

        return lineStart
    }

    // MARK: - Paragraph Movements

    private static func moveParagraphForward(from location: Int, in textView: NSTextView) -> Int {
        let string = textView.string as NSString
        var pos = location

        // Skip current paragraph (non-empty lines)
        while pos < string.length {
            let lineRange = string.lineRange(for: NSRange(location: pos, length: 0))
            let lineContent = string.substring(with: NSRange(location: lineRange.location, length: max(0, lineRange.length - 1)))

            if lineContent.trimmingCharacters(in: .whitespaces).isEmpty {
                break
            }
            pos = lineRange.location + lineRange.length
        }

        // Skip empty lines
        while pos < string.length {
            let lineRange = string.lineRange(for: NSRange(location: pos, length: 0))
            let lineContent = string.substring(with: NSRange(location: lineRange.location, length: max(0, lineRange.length - 1)))

            if !lineContent.trimmingCharacters(in: .whitespaces).isEmpty {
                return lineRange.location
            }
            pos = lineRange.location + lineRange.length
        }

        return min(pos, string.length)
    }

    private static func moveParagraphBackward(from location: Int, in textView: NSTextView) -> Int {
        let string = textView.string as NSString
        var pos = location

        guard pos > 0 else { return 0 }

        // Go to previous line first
        let currentLineRange = string.lineRange(for: NSRange(location: pos, length: 0))
        pos = max(0, currentLineRange.location - 1)

        // Skip empty lines
        while pos > 0 {
            let lineRange = string.lineRange(for: NSRange(location: pos, length: 0))
            let lineContent = string.substring(with: NSRange(location: lineRange.location, length: max(0, lineRange.length - 1)))

            if !lineContent.trimmingCharacters(in: .whitespaces).isEmpty {
                break
            }
            pos = max(0, lineRange.location - 1)
        }

        // Skip non-empty lines (current paragraph)
        while pos > 0 {
            let lineRange = string.lineRange(for: NSRange(location: pos, length: 0))
            let lineContent = string.substring(with: NSRange(location: lineRange.location, length: max(0, lineRange.length - 1)))

            if lineContent.trimmingCharacters(in: .whitespaces).isEmpty {
                return lineRange.location + lineRange.length
            }
            pos = max(0, lineRange.location - 1)
        }

        return 0
    }

    // MARK: - Sentence Movements

    private static func moveSentenceForward(from location: Int, in textView: NSTextView) -> Int {
        let string = textView.string
        var pos = location

        let sentenceEnders: Set<Character> = [".", "!", "?"]

        while pos < string.count {
            let idx = string.index(string.startIndex, offsetBy: pos)
            let char = string[idx]

            if sentenceEnders.contains(char) {
                // Skip past the sentence ender and any following whitespace
                pos += 1
                while pos < string.count {
                    let nextIdx = string.index(string.startIndex, offsetBy: pos)
                    if !string[nextIdx].isWhitespace {
                        return pos
                    }
                    pos += 1
                }
            }
            pos += 1
        }

        return string.count
    }

    private static func moveSentenceBackward(from location: Int, in textView: NSTextView) -> Int {
        let string = textView.string
        var pos = location - 1

        let sentenceEnders: Set<Character> = [".", "!", "?"]

        // Skip whitespace
        while pos > 0 {
            let idx = string.index(string.startIndex, offsetBy: pos)
            if !string[idx].isWhitespace {
                break
            }
            pos -= 1
        }

        while pos > 0 {
            let idx = string.index(string.startIndex, offsetBy: pos - 1)
            let char = string[idx]

            if sentenceEnders.contains(char) {
                return pos
            }
            pos -= 1
        }

        return 0
    }

    // MARK: - Search

    private static func searchNext(from location: Int, pattern: String, forward: Bool, in textView: NSTextView) -> Int? {
        guard !pattern.isEmpty else { return nil }

        let string = textView.string as NSString

        if forward {
            let searchRange = NSRange(location: location + 1, length: string.length - location - 1)
            let found = string.range(of: pattern, options: [], range: searchRange)

            if found.location != NSNotFound {
                return found.location
            }

            // Wrap around
            let wrapRange = NSRange(location: 0, length: location)
            let wrapFound = string.range(of: pattern, options: [], range: wrapRange)
            return wrapFound.location != NSNotFound ? wrapFound.location : nil
        } else {
            let searchRange = NSRange(location: 0, length: location)
            let found = string.range(of: pattern, options: .backwards, range: searchRange)

            if found.location != NSNotFound {
                return found.location
            }

            // Wrap around
            let wrapRange = NSRange(location: location + 1, length: string.length - location - 1)
            let wrapFound = string.range(of: pattern, options: .backwards, range: wrapRange)
            return wrapFound.location != NSNotFound ? wrapFound.location : nil
        }
    }

    // MARK: - Find Character

    private static func findCharacter(_ char: Character, from location: Int, forward: Bool, till: Bool, in textView: NSTextView) -> Int? {
        let string = textView.string
        let charString = String(char)

        if forward {
            var pos = location + 1
            while pos < string.count {
                let idx = string.index(string.startIndex, offsetBy: pos)
                if string[idx] == char {
                    return till ? pos - 1 : pos
                }
                // Stop at end of line
                if string[idx] == "\n" {
                    return nil
                }
                pos += 1
            }
        } else {
            var pos = location - 1
            while pos >= 0 {
                let idx = string.index(string.startIndex, offsetBy: pos)
                if string[idx] == char {
                    return till ? pos + 1 : pos
                }
                // Stop at start of line
                if string[idx] == "\n" {
                    return nil
                }
                pos -= 1
            }
        }

        return nil
    }

    // MARK: - Text Object Helpers

    private static func getWordRange(from location: Int, in string: NSString, around: Bool) -> NSRange? {
        guard location < string.length else { return nil }

        let char = String(UnicodeScalar(string.character(at: location))!)
        let isWordChar = char.first!.isLetter || char.first!.isNumber || char == "_"

        var start = location
        var end = location

        // Find start
        while start > 0 {
            let prevChar = String(UnicodeScalar(string.character(at: start - 1))!)
            let prevIsWord = prevChar.first!.isLetter || prevChar.first!.isNumber || prevChar == "_"
            if prevIsWord != isWordChar {
                break
            }
            start -= 1
        }

        // Find end
        while end < string.length - 1 {
            let nextChar = String(UnicodeScalar(string.character(at: end + 1))!)
            let nextIsWord = nextChar.first!.isLetter || nextChar.first!.isNumber || nextChar == "_"
            if nextIsWord != isWordChar {
                break
            }
            end += 1
        }

        if around {
            // Include trailing whitespace
            while end < string.length - 1 {
                let nextChar = string.character(at: end + 1)
                if nextChar != 32 && nextChar != 9 { // space and tab
                    break
                }
                end += 1
            }
        }

        return NSRange(location: start, length: end - start + 1)
    }

    private static func getQuoteRange(quote: Character, from location: Int, in string: NSString, around: Bool) -> NSRange? {
        let quoteCode = quote.asciiValue!

        // Find opening quote (search backward)
        var start = location
        while start > 0 && string.character(at: start) != quoteCode {
            start -= 1
        }

        guard string.character(at: start) == quoteCode else { return nil }

        // Find closing quote (search forward from after opening)
        var end = location
        if end <= start {
            end = start + 1
        }
        while end < string.length && string.character(at: end) != quoteCode {
            end += 1
        }

        guard end < string.length && string.character(at: end) == quoteCode else { return nil }

        if around {
            return NSRange(location: start, length: end - start + 1)
        } else {
            return NSRange(location: start + 1, length: end - start - 1)
        }
    }

    private static func getMatchedRange(open: String, close: String, from location: Int, in string: NSString, around: Bool) -> NSRange? {
        let openChar = open.utf16.first!
        let closeChar = close.utf16.first!

        // Find opening bracket (search backward)
        var start = location
        var depth = 0

        while start >= 0 {
            let char = string.character(at: start)
            if char == closeChar {
                depth += 1
            } else if char == openChar {
                if depth == 0 {
                    break
                }
                depth -= 1
            }
            start -= 1
        }

        guard start >= 0 else { return nil }

        // Find closing bracket (search forward)
        var end = start + 1
        depth = 1

        while end < string.length {
            let char = string.character(at: end)
            if char == openChar {
                depth += 1
            } else if char == closeChar {
                depth -= 1
                if depth == 0 {
                    break
                }
            }
            end += 1
        }

        guard end < string.length else { return nil }

        if around {
            return NSRange(location: start, length: end - start + 1)
        } else {
            return NSRange(location: start + 1, length: end - start - 1)
        }
    }
}
