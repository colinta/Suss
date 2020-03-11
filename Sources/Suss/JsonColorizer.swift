////
///  JsonColorizer.swift
//

import Ashen


class JsonColorizer: Colorizer {
    enum Error: Swift.Error {
        case expectedString
    }

    enum Token {
        case whitespace(String)

        case object(String)
        case array(String)

        case comma
        case colon

        case quote
        case char(String)     // any character between quotes
        case unicode(String)  // \u0000
        case escaped(String)  // \\, \/, etc
        case number(String)

        case invalid(String)

        var attrChar: TextType {
            switch self {
            case let .whitespace(c):
                return AttrChar(c, [])
            case let .object(c):
                return AttrChar(c, [.bold])
            case let .array(c):
                return AttrChar(c, [.bold])
            case .comma:
                return AttrChar(",", [.bold])
            case .colon:
                return AttrChar(":", [.bold])
            case .quote:
                return AttrChar("\"", [.foreground(.blue)])
            case let .char(c):
                return AttrChar(c, [.foreground(.blue)])
            case let .unicode(str):
                return Text("\\u\(str)", [.foreground(.blue), .bold])
            case let .escaped(c):
                return Text("\\\(c)", [.foreground(.blue), .bold])
            case let .number(c):
                return AttrChar(c, [.foreground(.cyan)])
            case let .invalid(c):
                return AttrChar(c, [.foreground(.white), .background(.red), .bold])
            }
        }
    }

    enum TokenState {
        case `default`
        case string
        case escaping
        case unicode(String)

        case invalid
    }

    func process(_ input: String) -> TextType {
        var tokens: [Token] = []

        var state: TokenState = .default
        for c in input {
            switch state {
            case .invalid:
                tokens.append(.invalid(c.description))
            case let .unicode(progress):
                switch c {
                case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                    "a", "A", "b", "B", "c", "C", "d", "D", "e", "E", "f", "F":
                    let unicode = progress + c.description
                    if unicode.count == 4 {
                        tokens.append(.unicode(unicode))
                        state = .string
                    }
                    else {
                        state = .unicode(unicode)
                    }
                default:
                    tokens.append(.invalid("\\"))
                    tokens.append(.invalid("u"))
                    tokens += progress.map { .invalid($0.description) }
                    state = .string
                }
            case .escaping:
                switch c {
                case "\"", "\\", "/", "b", "f", "n", "r", "t":
                    tokens.append(.escaped(c.description))
                    state = .string
                case "u":
                    state = .unicode("")
                default:
                    tokens.append(.invalid("\\"))
                    tokens.append(.invalid(c.description))
                    state = .invalid
                }
            case .string:
                switch c {
                case "\"":
                    tokens.append(.quote)
                    state = .default
                case "\\":
                    state = .escaping
                default:
                    tokens.append(.char(c.description))
                }
            case .default:
                switch c {
                case "\n", "\r":
                    tokens.append(.whitespace("\n"))
                case " ", "\t":
                    tokens.append(.whitespace(c.description))
                case "\"":
                    tokens.append(.quote)
                    state = .string
                case "{", "}":
                    tokens.append(.object(c.description))
                case "[", "]":
                    tokens.append(.array(c.description))
                case ",":
                    tokens.append(.comma)
                case ":":
                    tokens.append(.colon)
                case "-", "+", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "x", "e", "E":
                    tokens.append(.number(c.description))
                default:
                    tokens.append(.invalid(c.description))
                    state = .invalid
                }
            }
        }

        return AttrText(tokens.map { $0.attrChar })
    }
}
