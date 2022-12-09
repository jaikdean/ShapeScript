//
//  Lexer.swift
//  ShapeScript
//
//  Created by Nick Lockwood on 07/09/2018.
//  Copyright © 2018 Nick Lockwood. All rights reserved.
//

import Foundation

// MARK: Public interface

public func tokenize(_ input: String) throws -> [Token] {
    var tokens: [Token] = []
    var characters = Substring(input)
    var spaceBefore = true
    _ = characters.skipWhitespaceAndComments()
    while let token = try characters.readToken(spaceBefore: spaceBefore) {
        switch (tokens.last?.type, token.type) {
        case (.linebreak?, .linebreak):
            break // Skip duplicate linebreak
        case (.identifier?, .lparen) where spaceBefore && tokens.count > 1:
            switch tokens[tokens.count - 2].type {
            case .infix, .prefix:
                // Insert parens for disambiguation
                let identifier = tokens.removeLast()
                let range = identifier.range
                let lRange = range.lowerBound ..< range.lowerBound
                let rRange = range.upperBound ..< range.upperBound
                tokens += [
                    Token(type: .lparen, range: lRange),
                    identifier,
                    Token(type: .rparen, range: rRange),
                    token,
                ]
            default:
                tokens.append(token)
            }
        default:
            tokens.append(token)
        }
        spaceBefore = characters.skipWhitespaceAndComments()
        if !spaceBefore, let lastTokenType = tokens.last?.type {
            switch lastTokenType {
            case .infix, .prefix, .dot, .lparen, .lbrace, .linebreak:
                spaceBefore = true
            case .identifier, .keyword, .hexColor,
                 .number, .string, .rbrace, .rparen, .eof:
                break
            }
        }
    }
    if !characters.isEmpty {
        let start = characters.startIndex
        let token = characters.readToEndOfToken()
        let range = start ..< characters.startIndex
        throw LexerError(.unexpectedToken(token), at: range)
    }
    tokens.append(Token(type: .eof, range: characters.startIndex ..< characters.endIndex))
    return tokens
}

// Note: only includes keywords that start a command, not joining words
public enum Keyword: String, CaseIterable {
    case define
    case `for`
    case `if`
    case `else`
    case `import`
}

public enum PrefixOperator: String {
    case plus = "+"
    case minus = "-"
}

public enum InfixOperator: String, CaseIterable {
    case plus = "+"
    case minus = "-"
    case times = "*"
    case divide = "/"
    // Comparison operators
    case lt = "<"
    case gt = ">"
    case lte = "<="
    case gte = ">="
    case equal = "="
    case unequal = "<>"
    // Boolean operators
    case and, or
    // Range operators
    case to, step
}

public enum TokenType: Equatable {
    case linebreak
    case identifier(String)
    case keyword(Keyword)
    case hexColor(String)
    case infix(InfixOperator)
    case prefix(PrefixOperator)
    case number(Double)
    case string(String)
    case lbrace
    case rbrace
    case lparen
    case rparen
    case dot
    case eof
}

public typealias SourceRange = Range<String.Index>

public struct Token: Equatable {
    public let type: TokenType
    public let range: SourceRange
}

public enum LexerErrorType: Equatable {
    case invalidNumber(String)
    case invalidColor(String)
    case unexpectedToken(String)
    case unterminatedString
    case invalidEscapeSequence(String)
}

public struct LexerError: Error, Equatable {
    public let type: LexerErrorType
    public let range: SourceRange

    public init(_ type: LexerErrorType, at range: SourceRange) {
        self.type = type
        self.range = range
    }
}

public extension LexerError {
    var message: String {
        switch type {
        case let .invalidNumber(digits):
            return "Invalid numeric literal '\(digits)'"
        case let .invalidColor(string):
            return "Invalid color literal '#\(string)'"
        case let .unexpectedToken(token):
            guard token.count < 20, !token.contains("'") else {
                return "Unexpected token"
            }
            return "Unexpected token '\(token)'"
        case .unterminatedString:
            return "Unterminated string literal"
        case let .invalidEscapeSequence(sequence):
            let sequence = sequence.unicodeScalars.contains {
                CharacterSet.whitespaces.contains($0)
            } ? "'\(sequence)'" : sequence
            return "Invalid escape sequence \(sequence)"
        }
    }

    var suggestion: String? {
        switch type {
        case let .unexpectedToken(string):
            return Self.alternatives[string.lowercased()] ??
                string.bestMatches(in: InfixOperator.allCases.map { $0.rawValue }).first
        case let .invalidEscapeSequence(string):
            return [
                "\"\"": "\\\"",
                "\\r": "\\n",
            ][string]
        default:
            return nil
        }
    }

    var hint: String? {
        switch type {
        case let .invalidNumber(digits):
            if digits.components(separatedBy: ".").count > 2 {
                return "Numbers must contain at most one decimal point."
            }
            return nil
        case .invalidColor:
            return "Hex colors must be 3, 4, 6 or 8 digits in length."
        case .unexpectedToken:
            if let suggestion = suggestion {
                return "Did you mean '\(suggestion)'?"
            }
            return nil
        case .unterminatedString:
            return "Try adding a closing \" (double quote) at the end of the line."
        case .invalidEscapeSequence:
            let hint = "Supported sequences are \\\", \\n and \\\\."
            if let suggestion = suggestion {
                return "\(hint) Did you mean \(suggestion)?"
            }
            return hint
        }
    }
}

public extension String {
    func lineRange(at index: String.Index, includingIndent: Bool = false) -> SourceRange {
        var endIndex = self.endIndex
        var startIndex = self.startIndex
        var i = startIndex
        while i < endIndex {
            let nextIndex = self.index(after: i)
            if self[i].isLinebreak {
                if i >= index {
                    endIndex = i
                    break
                }
                startIndex = nextIndex
            }
            i = nextIndex
        }
        if !includingIndent {
            while startIndex < endIndex, self[startIndex].isWhitespace {
                startIndex = self.index(after: startIndex)
            }
        }
        return startIndex ..< endIndex
    }

    func lineAndColumn(at index: String.Index) -> (line: Int, column: Int) {
        var line = 1, column = 1
        var i = startIndex
        assert(index <= endIndex)
        while i < min(index, endIndex) {
            if self[i].isLinebreak == true {
                line += 1
                column = 1
            } else {
                column += 1
            }
            i = self.index(after: i)
        }
        return (line: line, column: column)
    }

    func line(at index: String.Index) -> Int {
        lineAndColumn(at: index).line
    }

    @available(*, deprecated, message: "Use lineAndColumn(at:) instead.")
    func lineAndColumn(
        at index: String.Index,
        withLinebreakIndices linebreakIndices: [String.Index]
    ) -> (line: Int, column: Int) {
        guard indices.contains(index),
              let line = linebreakIndices.firstIndex(where: { $0 >= index })
        else {
            assertionFailure("index out of range")
            return (linebreakIndices.count, 1)
        }
        let linebreakIndex = line > 0 ? self
            .index(after: linebreakIndices[line - 1]) : startIndex
        guard indices.contains(linebreakIndex) else {
            assertionFailure("linebreakIndex out of range")
            return (line, 1)
        }
        var i = linebreakIndex
        var column = 1
        while i < index {
            i = self.index(after: i)
            column += 1
        }
        return (line: line + 1, column: column)
    }

    @available(*, deprecated, message: "Obsolete.")
    var linebreakIndices: [String.Index] {
        indices.compactMap { self[$0].isLinebreak ? $0 : nil } + [endIndex]
    }
}

// MARK: Implementation

private extension LexerError {
    static let alternatives = [
        "&&": "and",
        "&": "and",
        "||": "or",
        "|": "or",
        "!": "not",
        "==": "=",
        "===": "=",
        "!=": "<>",
        "/=": "<>",
        "=/=": "<>",
        "=<": "<=",
        "=>": ">=",
    ]
}

private let whitespace = " \t"
private let linebreaks = "\n\r\r\n"
private let punctuation = "/()[]{}"
private let operators = "+-*/<>=!?&|%^~"
private let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
private let digits = "0123456789"
private let alphanumerics = digits + letters
private let hexadecimals = digits + "ABCDEFabcdef"

private extension Character {
    var isWhitespace: Bool {
        whitespace.contains(self)
    }

    var isLinebreak: Bool {
        linebreaks.contains(self)
    }

    var isWhitespaceOrLinebreak: Bool {
        isWhitespace || isLinebreak
    }
}

private extension Substring {
    mutating func skipWhitespaceAndComments() -> Bool {
        var wasSpace = false
        while let c = first {
            guard c.isWhitespace else {
                if c == "/" {
                    wasSpace = true
                    let nextIndex = index(after: startIndex)
                    if nextIndex != endIndex, self[nextIndex] == "/" {
                        removeFirst()
                        removeFirst()
                        while let c = first, !c.isLinebreak {
                            removeFirst()
                        }
                    }
                }
                break
            }
            wasSpace = true
            removeFirst()
        }
        return wasSpace
    }

    mutating func readLineBreak() -> TokenType? {
        guard let c = first, c.isLinebreak else {
            return nil
        }
        removeFirst()
        return .linebreak
    }

    mutating func readToEndOfToken() -> String {
        var string = ""
        if let c = popFirst() {
            string.append(c)
            if punctuation.contains(c) {
                while let c = first, punctuation.contains(c) {
                    string.append(removeFirst())
                }
            } else {
                let terminator = whitespace + linebreaks + punctuation
                while let c = first, !terminator.contains(c) {
                    string.append(removeFirst())
                }
            }
        }
        return string
    }

    mutating func readOperator(spaceBefore: Bool) -> TokenType? {
        let start = self
        switch popFirst() {
        case "{": return .lbrace
        case "}": return .rbrace
        case "(": return .lparen
        case ")": return .rparen
        case "." where !spaceBefore:
            if let next = first, !next.isWhitespace, !next.isLinebreak {
                return .dot
            }
            self = start
            return nil
        case let c? where operators.contains(c):
            func toOp(_ string: String) -> TokenType? {
                if let op = InfixOperator(rawValue: string) {
                    guard let next = first else {
                        // technically postfix, but we don't have those
                        return .infix(op)
                    }
                    if !spaceBefore || next.isWhitespace || next.isLinebreak {
                        return .infix(op)
                    }
                    if let op = PrefixOperator(rawValue: string) {
                        return .prefix(op)
                    }
                    return .infix(op)
                } else if let op = PrefixOperator(rawValue: string) {
                    return .prefix(op)
                } else {
                    return nil
                }
            }
            var string = String(c)
            var op = toOp(string)
            var end = start
            if op != nil {
                end = self
            }
            while let c = first, operators.contains(c) {
                removeFirst()
                string.append(c)
                if let nextOp = toOp(string) {
                    op = nextOp
                    end = self
                }
            }
            let remaining = String(end[..<startIndex])
            if !remaining.isEmpty, PrefixOperator(rawValue: remaining) == nil {
                self = start
                return nil
            }
            self = end
            return op
        default:
            self = start
            return nil
        }
    }

    mutating func readNumber() throws -> TokenType? {
        let start = self
        var digits = ""
        while let c = first, "01234567890.".contains(c) {
            digits.append(removeFirst())
        }
        if digits.isEmpty {
            return nil
        }
        guard let double = Double(digits) else {
            let range = start.startIndex ..< startIndex
            let error: LexerErrorType = (digits == ".") ?
                .unexpectedToken(digits) : .invalidNumber(digits)
            throw LexerError(error, at: range)
        }
        return .number(double)
    }

    mutating func readString() throws -> TokenType? {
        guard first == "\"" else {
            return nil
        }
        let start = self
        removeFirst()
        var string = "", escaped = false
        loop: while let c = first {
            if !escaped {
                switch c {
                case "\"":
                    removeFirst()
                    if first == "\"" {
                        let range = start.index(before: startIndex) ..< index(after: startIndex)
                        throw LexerError(.invalidEscapeSequence(String(start[range])), at: range)
                    }
                    return .string(string)
                case "\\":
                    escaped = true
                case "\n", "\r", "\r\n":
                    break loop
                default:
                    string.append(c)
                }
                removeFirst()
                continue
            }
            switch c {
            case "n":
                string.append("\n")
            case "\\", "\"":
                string.append(c)
            case "\n", "\r", "\r\n":
                break loop
            default:
                let range = start.index(before: startIndex) ..< index(after: startIndex)
                throw LexerError(.invalidEscapeSequence(String(start[range])), at: range)
            }
            removeFirst()
            escaped = false
        }
        let range = start.startIndex ..< startIndex
        throw LexerError(.unterminatedString, at: range)
    }

    mutating func readIdentifier() -> TokenType? {
        guard let head = first, letters.contains(head) else {
            return nil
        }
        var name = String(removeFirst())
        while let c = first, alphanumerics.contains(c) || c == "_" {
            name.append(removeFirst())
        }
        if let keyword = Keyword(rawValue: name) {
            return .keyword(keyword)
        }
        return .identifier(name)
    }

    mutating func readHexColor() throws -> TokenType? {
        guard first == "#" else {
            return nil
        }
        let start = self
        removeFirst()
        var string = "", isValid = true
        while let c = first, alphanumerics.contains(c) {
            isValid = isValid && hexadecimals.contains(c)
            string.append(removeFirst())
        }
        let range = start.startIndex ..< startIndex
        guard isValid else {
            throw LexerError(.invalidColor(string), at: range)
        }
        switch string.count {
        case 3, 4, 6, 8:
            return .hexColor(string)
        case 0:
            throw LexerError(.unexpectedToken("#"), at: range)
        default:
            throw LexerError(.invalidColor(string), at: range)
        }
    }

    mutating func readToken(spaceBefore: Bool) throws -> Token? {
        let startIndex = self.startIndex
        guard let tokenType = try
            readLineBreak() ??
            readOperator(spaceBefore: spaceBefore) ??
            readNumber() ??
            readString() ??
            readIdentifier() ??
            readHexColor()
        else {
            return nil
        }
        let range = startIndex ..< self.startIndex
        return Token(type: tokenType, range: range)
    }
}
