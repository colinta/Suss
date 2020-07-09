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
        case char(String)  // any character between quotes
        case unicode(String)  // \u0000
        case escaped(String)  // \\, \/, etc
        case number(String)
        case boolean(Bool)

        case invalid(String)

        var attrChar: TextType {
            switch self {
            case let .whitespace(c):
                return AttrChar(c)
            case let .object(c):
                return AttrChar(c)
            case let .array(c):
                return AttrChar(c)
            case .comma:
                return AttrChar(",", [.bold])
            case .colon:
                return AttrChar(":", [.bold])
            case .quote:
                return AttrChar("\"", [.foreground(.red)])
            case let .char(c):
                return AttrChar(c, [.foreground(.red)])
            case let .unicode(str):
                return Text("\\u\(str)", [.foreground(.blue), .bold])
            case let .escaped(c):
                return Text("\\\(c)", [.foreground(.blue), .bold])
            case let .number(c):
                return AttrChar(c, [.foreground(.cyan)])
            case .boolean(false):
                return Text("false", [.foreground(.yellow), .bold])
            case .boolean(true):
                return Text("true", [.foreground(.yellow), .bold])
            case let .invalid(c):
                return AttrChar(c, [.foreground(.white), .background(.red), .bold])
            }
        }
    }

    enum TokenState {
        case `default`
        case string
        case escaping
        case boolean(Bool, String, String)
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
                    } else {
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
            case let .boolean(val, found, rem):
                if rem == "" {
                    tokens.append(.boolean(val))
                    state = .default
                } else if rem[rem.startIndex] == c {
                    let nextRemainder = String(rem.dropFirst())
                    state = .boolean(
                        val,
                        found + String(rem[rem.startIndex]),
                        String(nextRemainder)
                    )
                } else {
                    for err in found + rem {
                        tokens.append(.char(err.description))
                    }
                    state = .invalid
                }
            case .default:
                switch c {
                case "t":
                    state = .boolean(true, "t", "rue")
                case "f":
                    state = .boolean(false, "f", "alse")
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
