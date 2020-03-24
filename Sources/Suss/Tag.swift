////
///  Tag.swift
//

import Foundation
import Ashen


let Singletons = [
    "area",
    "base",
    "br",
    "col",
    "command",
    "embed",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "param",
    "source"
]

enum State: String {
    case start = "Start"
    case doctype = "Doctype"
    case reset = "Reset"
    case end = "End"
    case tagOpen = "TagOpen"
    case tagClose = "TagClose"
    case tagWs = "TagWs"
    case tagGt = "TagGt"
    case singleton = "Singleton"
    case attrReset = "AttrReset"
    case attr = "Attr"
    case attrEq = "AttrEq"
    case attrDqt = "AttrDqt"
    case attrSqt = "AttrSqt"
    case attrValue = "AttrValue"
    case attrDvalue = "AttrDvalue"
    case attrSvalue = "AttrSvalue"
    case attrCdqt = "AttrCdqt"
    case attrCsqt = "AttrCsqt"
    case text = "Text"
    case cdata = "Cdata"
    case ieOpen = "IeOpen"
    case ieClose = "IeClose"
    case predoctypeWhitespace = "PredoctypeWhitespace"
    case predoctypeCommentOpen = "PredoctypeCommentOpen"
    case predoctypeComment = "PredoctypeComment"
    case predoctypeCommentClose = "PredoctypeCommentClose"
    case commentOpen = "CommentOpen"
    case comment = "Comment"
    case commentClose = "CommentClose"

    var nextPossibleStates: [State] {
        switch self {
        case .start:
            return [.tagOpen, .doctype, .predoctypeWhitespace, .predoctypeCommentOpen, .text, .end]
        case .doctype: return [.reset]
        case .reset: return [.tagOpen, .ieOpen, .ieClose, .commentOpen, .tagClose, .text, .end]
        case .end: return []
        case .tagOpen: return [.attrReset]
        case .tagClose: return [.reset]
        case .tagWs: return [.attr, .singleton, .tagGt]
        case .tagGt: return [.cdata, .reset]
        case .singleton: return [.reset]
        case .attrReset: return [.tagWs, .singleton, .tagGt]
        case .attr: return [.tagWs, .attrEq, .tagGt, .singleton]
        case .attrEq: return [.attrValue, .attrDqt, .attrSqt]
        case .attrDqt: return [.attrDvalue]
        case .attrSqt: return [.attrSvalue]
        case .attrValue: return [.tagWs, .tagGt, .singleton]
        case .attrDvalue: return [.attrCdqt]
        case .attrSvalue: return [.attrCsqt]
        case .attrCdqt: return [.tagWs, .tagGt, .singleton]
        case .attrCsqt: return [.tagWs, .tagGt, .singleton]
        case .text: return [.reset]
        case .cdata: return [.tagClose]
        case .ieOpen: return [.reset]
        case .ieClose: return [.reset]
        case .predoctypeWhitespace: return [.start]
        case .predoctypeCommentOpen: return [.predoctypeComment]
        case .predoctypeComment: return [.predoctypeCommentClose]
        case .predoctypeCommentClose: return [.start]
        case .commentOpen: return [.comment]
        case .comment: return [.commentClose]
        case .commentClose: return [.reset]
        }
    }

    func match(_ str: String) -> String {
        switch self {
        case .start: return ""
        case .reset: return ""
        case .doctype: return regexFind(input: str.lowercased(), pattern: "^<!doctype .*?>") ?? ""
        case .end: return ""
        case .tagOpen: return regexFind(input: str, pattern: "^<[a-zA-Z]([-_]?[a-zA-Z0-9])*") ?? ""
        case .tagClose: return regexFind(input: str, pattern: "^</[a-zA-Z]([-_]?[a-zA-Z0-9])*>") ?? ""
        case .tagWs: return regexFind(input: str, pattern: "^[ \t\n]+") ?? ""
        case .tagGt: return regexFind(input: str, pattern: "^>") ?? ""
        case .singleton: return regexFind(input: str, pattern: "^/>") ?? ""
        case .attrReset: return ""
        case .attr: return regexFind(input: str, pattern: "^[a-zA-Z]([-_]?[a-zA-Z0-9])*") ?? ""
        case .attrEq: return regexFind(input: str, pattern: "^=") ?? ""
        case .attrDqt: return regexFind(input: str, pattern: "^\"") ?? ""
        case .attrSqt: return regexFind(input: str, pattern: "^'") ?? ""
        case .attrValue: return regexFind(input: str, pattern: "^[a-zA-Z0-9]([-_]?[a-zA-Z0-9])*") ?? ""
        case .attrDvalue: return regexFind(input: str, pattern: "^[^\"]*") ?? ""
        case .attrSvalue: return regexFind(input: str, pattern: "^[^']*") ?? ""
        case .attrCdqt: return regexFind(input: str, pattern: "^\"") ?? ""
        case .attrCsqt: return regexFind(input: str, pattern: "^'") ?? ""
        case .cdata: return regexFind(input: str, pattern: "^(//)?<!\\[CDATA\\[([^>]|>)*?//]]>") ?? ""
        case .text: return regexFind(input: str, pattern: "^(.|\n)+?($|(?=<[!/a-zA-Z]))") ?? ""
        case .ieOpen: return regexFind(input: str, pattern: "^<!(?:--)?\\[if.*?\\[>") ?? ""
        case .ieClose: return regexFind(input: str, pattern: "^<!\\[endif\\[(?:--)?>") ?? ""
        case .predoctypeWhitespace: return regexFind(input: str, pattern: "^[ \t\n]+") ?? ""
        case .predoctypeCommentOpen: return regexFind(input: str, pattern: "^<!--") ?? ""
        case .predoctypeComment: return regexFind(input: str, pattern: "^(.|\n)*?(?=-->)") ?? ""
        case .predoctypeCommentClose: return regexFind(input: str, pattern: "^-->") ?? ""
        case .commentOpen: return regexFind(input: str, pattern: "^<!--") ?? ""
        case .comment: return regexFind(input: str, pattern: "^(.|\n)*?(?=-->)") ?? ""
        case .commentClose: return regexFind(input: str, pattern: "^-->") ?? ""
        }
    }

    func detect(_ str: String) -> Bool {
        switch self {
        case .start: return true
        case .reset: return true
        case .doctype: return regexMatches(input: str.lowercased(), pattern: "^<!doctype .*?>")
        case .end: return str.isEmpty
        case .tagOpen: return regexMatches(input: str, pattern: "^<[a-zA-Z]([-_]?[a-zA-Z0-9])*")
        case .tagClose: return regexMatches(input: str, pattern: "^</[a-zA-Z]([-_]?[a-zA-Z0-9])*>")
        case .tagWs: return regexMatches(input: str, pattern: "^[ \t\n]+")
        case .tagGt: return regexMatches(input: str, pattern: "^>")
        case .singleton: return regexMatches(input: str, pattern: "^/>")
        case .attrReset: return true
        case .attr: return regexMatches(input: str, pattern: "^[a-zA-Z]([-_]?[a-zA-Z0-9])*")
        case .attrEq: return regexMatches(input: str, pattern: "^=")
        case .attrDqt: return regexMatches(input: str, pattern: "^\"")
        case .attrSqt: return regexMatches(input: str, pattern: "^'")
        case .attrValue: return regexMatches(input: str, pattern: "^[a-zA-Z0-9]([-_]?[a-zA-Z0-9])*")
        case .attrDvalue: return regexMatches(input: str, pattern: "^[^\"]*")
        case .attrSvalue: return regexMatches(input: str, pattern: "^[^']*")
        case .attrCdqt: return regexMatches(input: str, pattern: "^\"")
        case .attrCsqt: return regexMatches(input: str, pattern: "^'")
        case .cdata: return regexMatches(input: str, pattern: "^(//)?<!\\[CDATA\\[([^>]|>)*?//]]>")
        case .text: return regexMatches(input: str, pattern: "^(.|\n)+?($|(?=<[!/a-zA-Z]))")
        case .ieOpen: return regexMatches(input: str, pattern: "^<!(?:--)?\\[if.*?\\[>")
        case .ieClose: return regexMatches(input: str, pattern: "^<!\\[endif\\](?:--)?>")
        case .predoctypeWhitespace: return regexMatches(input: str, pattern: "^[ \t\n]+")
        case .predoctypeCommentOpen: return regexMatches(input: str, pattern: "^<!--")
        case .predoctypeComment: return regexMatches(input: str, pattern: "^(.|\n)*?(?=-->)")
        case .predoctypeCommentClose: return regexMatches(input: str, pattern: "^-->")
        case .commentOpen: return regexMatches(input: str, pattern: "^<!--")
        case .comment: return regexMatches(input: str, pattern: "^(.|\n)*?(?=-->)")
        case .commentClose: return regexMatches(input: str, pattern: "^-->")
        }
    }
}

enum AttrValue {
    case `true`
    case `false`
    case value(value: String)

    func toString(_ tag: String) -> String {
        switch self {
        case .`false`: return ""
        case .`true`: return tag
        case let .value(value): return "\"\(value)\""
        }
    }
}

class Tag: CustomStringConvertible {
    var isSingleton = false
    var name: String?
    var attrs = [String: AttrValue]()
    var tags = [Tag]()
    var text: String?
    var comment: String?

    init() {}
    init?(input: String) {
        var state: State = .start
        var lastTag = self
        var lastAttr: String?
        var parentTags = [Tag]()
        var preWhitespace: String?

        var html = input
        html = html.replacingOccurrences(of: "\r\n", with: "\n")
        html = html.replacingOccurrences(of: "\r", with: "\n")

        var c = html.startIndex
        while state != .end {
            let current = String(html[c..<html.endIndex])

            var nextPossibleStates = [State]()
            for possible in state.nextPossibleStates {
                if possible.detect(current) {
                    nextPossibleStates.append(possible)
                }
            }
            if nextPossibleStates.count == 0 {
                return nil
            }

            let nextState = nextPossibleStates.first!
            let value = nextState.match(current)
            c = html.index(c, offsetBy: value.count)

            switch nextState {
            case .doctype:
                let doctype = Doctype()
                let match = regexAllGroups(input: value.lowercased(), pattern: "^<!doctype (.*?)>$")
                doctype.name = match[1]
                lastTag.tags.append(doctype)
                preWhitespace = nil
            case .predoctypeWhitespace:
                preWhitespace = value
            case .tagOpen:
                if let pre = preWhitespace {
                    let tag = Tag()
                    tag.text = pre
                    lastTag.tags.append(tag)
                    preWhitespace = nil
                }

                let newTag = Tag()
                let name = String(value[value.index(after: value.startIndex)...])
                newTag.name = name
                newTag.isSingleton = Singletons.contains(name)
                lastTag.tags.append(newTag)
                parentTags.append(lastTag)

                lastTag = newTag
                lastAttr = nil
            case .attr:
                lastAttr = value
            case .tagWs:
                if let lastAttr = lastAttr {
                    lastTag.attrs[lastAttr] = .true
                }
                lastAttr = nil
            case .attrValue, .attrDvalue, .attrSvalue:
                if let lastAttr = lastAttr {
                    lastTag.attrs[lastAttr] = .value(value: value)
                }
                lastAttr = nil
            case .tagGt:
                if let lastAttr = lastAttr {
                    lastTag.attrs[lastAttr] = .true
                }

                if lastTag.isSingleton && parentTags.count > 0 {
                    lastTag = parentTags.removeLast()
                }
            case .singleton, .tagClose, .ieClose:
                if parentTags.count > 0 {
                    lastTag = parentTags.removeLast()
                }
            case .text:
                var text = ""
                if let pre = preWhitespace {
                    text += pre
                    preWhitespace = nil
                }
                text += value

                let tag = Tag()
                tag.text = text
                lastTag.tags.append(tag)
            case .cdata:
                let tag = Tag()
                tag.text = value
                lastTag.tags.append(tag)
            case .comment, .predoctypeComment:
                let tag = Tag()
                tag.comment = value
                lastTag.tags.append(tag)
            default:
                break
            }

            state = nextState
        }
    }

    var attrText: TextType {
        var retval = AttrText()
        if let tag = name {
            retval.append(Text("<\(tag)", [.foreground(.blue)]))
            for (key, value) in attrs {
                retval.append(" ")
                retval.append(Text("\(key)=", [.foreground(.cyan)]))
                retval.append(Text(value.toString(tag), [.foreground(.red)]))
            }

            if isSingleton {
                retval.append(Text(" />", [.foreground(.blue)]))
            }
            else {
                retval.append(Text(">", [.foreground(.blue)]))
            }
        }

        if let comment = comment {
            retval.append(Text("<!-- \(comment) -->\n", [.foreground(.green)]))
        }

        if let text = text {
            retval.append(Text(text))
        }

        for child in tags {
            retval.append(child.attrText)
        }

        if let tag = name, !isSingleton {
            retval.append(Text("</\(tag)>", [.foreground(.blue)]))
        }

        return retval
    }

    var description: String {
        var retval = ""
        if let tag = name {
            retval += "<\(tag)"
            for (key, value) in attrs {
                retval += " "
                retval += key
                retval += "="
                retval += value.toString(tag)
            }

            if isSingleton {
                retval += " />"
            }
            else {
                retval += ">"
            }
        }

        if let comment = comment {
            retval += "<!-- \(comment) -->\n"
        }

        if let text = text {
            retval += text
        }

        for child in tags {
            retval += child.description
        }

        if let tag = name, !isSingleton {
            retval += "</\(tag)>"
        }

        return retval
    }
}

class Doctype: Tag {
}

func regexMatches(input: String, pattern: String) -> Bool {
    input.range(of: pattern, options: .regularExpression) != nil
}

func regexFind(input: String, pattern: String) -> String? {
    guard let range = input.range(of: pattern, options: .regularExpression) else { return nil }
    return String(input[range])
}

func regexAllGroups(input: String, pattern: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
    guard let match = regex.firstMatch(in: input, options: [], range: NSRange(input.startIndex..<input.endIndex, in: input)) else { return [] }

    return (0..<match.numberOfRanges).compactMap { i in
        guard let range = Range(match.range(at: i), in: input) else { return nil }
        return String(input[range])
    }
}
