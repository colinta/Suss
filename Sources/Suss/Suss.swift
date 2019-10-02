////
///  Suss.swift
//

import Ashen
import Foundation


struct Suss: Program {
    enum Error: Swift.Error {
        case invalidURL
        case missingScheme
        case missingHost
        case cannotDecode
    }

    enum Message {
        case quit
        case submit
        case nextInput
        case prevInput
        case nextMethod
        case prevMethod
        case clearError
        case received(String, Http.Headers)
        case receivedError(String)
        case onChange(Model.Input, String)
        case scrollResponseHeaders(Int, Int)
        case scrollResponseContent(Int, Int)
    }

    struct Model {
        enum Input: Int {
            static let first: Input = .url
            static let last: Input = .responseBody

            case url
            case httpMethod
            case urlParameters
            case body
            case headers
            case responseHeaders
            case responseBody

            var next: Input { return Input(rawValue: rawValue + 1) ?? .first }
            var prev: Input { return Input(rawValue: rawValue - 1) ?? .last }
        }

        var active: Input = .url
        var url: String = ""
        var httpMethod: Http.Method = .get
        var urlParameters: String = ""
        var body: String = ""
        var headers: String = ""

        var httpCommand: Http?
        var requestSent: Bool { return httpCommand != nil }

        var response: (content: String, headers: Http.Headers)?
        var headersOffset = Point(x: 0, y: 0)
        var contentOffset = Point(x: 0, y: 0)

        var error: String?
        var lastSentURL: String?
        var status: String {
            var status = "[Suss v1.0.0]"
            if let lastSentURL = lastSentURL {
                status += " \(lastSentURL)"
            }
            return status
        }

        var nextMethod: Http.Method {
            switch httpMethod {
            case .get: return .post
            case .post: return .put
            case .put: return .patch
            case .patch: return .delete
            case .delete: return .head
            case .head: return .options
            default: return .get
            }
        }
        var prevMethod: Http.Method {
            switch httpMethod {
            case .post: return .get
            case .put: return .post
            case .patch: return .put
            case .delete: return .patch
            case .head: return .delete
            case .options: return .head
            default: return .options
            }
        }

        init() {
        }
    }

    let fullBorder = Box.Border(
        tlCorner: "┌", trCorner: "┐", blCorner: "│", brCorner: "│",
        tbSide: "─", topSide: "─", bottomSide: "",
        lrSide: "│", leftSide: "│", rightSide: "│"
        )
    let sideBorder = Box.Border(
        tlCorner: "┌", trCorner: "─", blCorner: "│", brCorner: "",
        tbSide: "─", topSide: "─", bottomSide: "",
        lrSide: "│", leftSide: "│", rightSide: ""
        )

    func initial() -> (Model, [Command]) {
        return (Model(), [])
    }

    func update(model: inout Model, message: Message)
        -> (Model, [Command], LoopState)
    {
        switch message {
        case .quit:
            return (model, [], .quit)
        case .submit:
            do {
               return try submit(model: &model, message: message)
            }
            catch {
                model.error = (error as? Error)?.description
                return (model, [], .continue)
            }
        case let .received(response, headers):
            model.httpCommand = nil
            model.response = (content: response, headers: headers)
        case let .receivedError(error):
            model.httpCommand = nil
            model.error = error
        case .nextInput:
            model.active = model.active.next
        case .prevInput:
            model.active = model.active.prev
        case .nextMethod:
            model.httpMethod = model.nextMethod
        case .prevMethod:
            model.httpMethod = model.prevMethod
        case .clearError:
            model.error = nil
        case let .onChange(input, value):
            switch input {
            case .url:
                model.url = value
            case .body:
                model.body = value
            case .urlParameters:
                model.urlParameters = value
            case .headers:
                model.headers = value
            default:
                break
            }
        case let .scrollResponseHeaders(dy, dx):
            if let response = model.response {
                let maxOffset = response.headers.count - 1
                model.headersOffset = Point(
                    x: min(maxOffset, max(0, model.headersOffset.x + dx)),
                    y: min(maxOffset, max(0, model.headersOffset.y + dy))
                    )
            }
        case let .scrollResponseContent(dy, dx):
            if let response = model.response {
                let maxOffset = split(response.content, separator: "\n").count - 1
                model.contentOffset = Point(
                    x: min(maxOffset, max(0, model.contentOffset.x + dx)),
                    y: min(maxOffset, max(0, model.contentOffset.y + dy))
                    )
            }
        }

        return (model, [], .continue)
    }

    func submit(model: inout Model, message: Message) throws
        -> (Model, [Command], LoopState)
    {
        var urlString = model.url

        let urlParameters = split(model.urlParameters, separator: "\n")

        if urlParameters.count > 0 {
            if !urlString.contains("?") {
                urlString += "?"
            }
            else if !urlString.hasSuffix("&") {
                urlString += "&"
            }
            urlString += urlParameters.map { param -> String in
                let parts = split(param, separator: "=", limit: 2)
                return parts.map({ part in
                    part.addingPercentEncoding(withAllowedCharacters: CharacterSet.letters) ?? part
                }).joined(separator: "=")
            }.joined(separator: "&")
        }

        let headers: Http.Headers = split(model.headers, separator: "\n").compactMap({ entries -> Http.Header? in
            let kvp = split(entries, separator: ":", limit: 2, trim: true)
            guard kvp.count == 2 else { return nil }
            return (kvp[0], kvp[1])
        })

        guard let url = URL(string: urlString) else { throw Error.invalidURL }
        guard url.scheme != nil else { throw Error.missingScheme }
        guard url.host != nil else { throw Error.missingHost }

        model.lastSentURL = urlString

        var options: Http.Options = [
            .method(model.httpMethod),
            .headers(headers)
        ]

        if model.httpMethod != .get {
            options.append(.body(.string(model.body)))
        }

        let cmd = Http(url: url, options: options) { result in
            do {
                let (response, headers) = try result.map { data, headers -> (String, Http.Headers) in
                    if let str = String(data: data, encoding: .utf8) {
                        return (str, headers)
                    }
                    throw Error.cannotDecode
                }.unwrap()
                return Message.received(response, headers)
            }
            catch {
                let errorDescription = (error as? Error)?.description ?? "Unknown error"
                return Message.receivedError(errorDescription)
            }
        }

        model.httpCommand = cmd
        return (model, [cmd], .continue)
    }

    func render(model: Model, in screenSize: Size) -> Component {
        let activeInput: Model.Input?
        if model.error != nil || model.requestSent {
            activeInput = nil
        }
        else {
            activeInput = model.active
        }

        let urlInput = InputView(
            text: model.url,
            isFirstResponder: activeInput == .url,
            onChange: { model in
                return Message.onChange(.url, model)
            },
            onEnter: {
                return Message.submit
            })

        let httpMethods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]
        let activeAttrs: [Attr]
        if activeInput == .httpMethod {
            activeAttrs = [.reverse]
        }
        else {
            activeAttrs = [.underline]
        }

        let httpMethodText: [TextType] = httpMethods.map { httpMethod -> Text in
            return Text(httpMethod, httpMethod == model.httpMethod.rawValue ? activeAttrs : [])
        }.reduce([TextType]()) { (memo, httpMethodText) -> [TextType] in
            if memo.count > 0 {
                return memo + [" ", httpMethodText]
            }
            else {
                return [httpMethodText]
            }
        }
        let httpMethodInputs: [Component]
        if activeInput == .httpMethod {
            httpMethodInputs = [
                LabelView(text: AttrText(httpMethodText)),
                OnKeyPress(.left, { return Message.prevMethod }),
                OnKeyPress(.right, { return Message.nextMethod }),
                OnKeyPress(.enter, { return Message.submit }),
            ]
        }
        else {
            httpMethodInputs = [LabelView(text: AttrText(httpMethodText))]
        }

        func highlight(if input: Model.Input) -> [Attr] {
            guard activeInput == input else {
                return []
            }
            return [.reverse]
        }

        let urlLabel = Text("URL", highlight(if: .url))

        let methodLabel = Text("Method", highlight(if: .httpMethod))

        let requestBodyLabel = Text("POST Body", highlight(if: .body))
        let bodyInput = InputView(
            text: model.body,
            isFirstResponder: activeInput == .body,
            isMultiline: true,
            onChange: { model in
                return Message.onChange(.body, model)
            })

        let requestParametersLabel = Text("GET Parameters", highlight(if: .urlParameters))
        let urlParametersInput = InputView(
            text: model.urlParameters,
            isFirstResponder: activeInput == .urlParameters,
            isMultiline: true,
            onChange: { model in
                return Message.onChange(.urlParameters, model)
            })

        let requestHeadersLabel = Text("Headers", highlight(if: .headers))
        let headersInput = InputView(
            text: model.headers,
            isFirstResponder: activeInput == .headers,
            isMultiline: true,
            onChange: { model in
                return Message.onChange(.headers, model)
            })

        let responseHeadersLabel = Text("Response headers", highlight(if: .responseHeaders))
        let responseBodyLabel = Text("Response body", highlight(if: .responseBody))

        let maxSideWidth = 40
        let remainingHeight = max(screenSize.height - 8, 0)
        let responseHeight = max(screenSize.height - 5, 0)
        let requestWidth = min(maxSideWidth, screenSize.width / 3)
        let responseWidth = screenSize.width - requestWidth

        let topLevelComponents: [Component]
        if let error = model.error {
            topLevelComponents = [
                OnKeyPress({ _ in return Message.clearError }),
                Box(at: .middleCenter(), size: DesiredSize(width: error.count + 4, height: 5), border: .single, label: "Error", components: [
                    LabelView(at: .topCenter(), text: Text(error, [.foreground(.red)])),
                    LabelView(at: .bottomCenter(), text: Text("< OK >", [.reverse])),
                ]),
            ]
        }
        else if model.requestSent {
            topLevelComponents = [
                SpinnerView(at: .bottomLeft())
            ]
        }
        else {
            topLevelComponents = [
                OnKeyPress(.esc, { return Message.quit }),
                OnKeyPress(.tab, { return Message.nextInput }),
                OnKeyPress(.backtab, { return Message.prevInput }),
            ]
        }

        var responseHeaders: [Component] = []
        var responseContent: [Component] = []
        if let response = model.response {
            var headerString = AttrText()
            response.headers.forEach { key, value in
                headerString.append(Text(key, [.bold]))
                headerString.append(": \(value)\n")
            }
            responseHeaders.append(LabelView(text: headerString))
            responseContent.append(LabelView(text: response.content))
        }

        if activeInput == .responseHeaders {
            responseHeaders += [
                OnKeyPress(.up, { return Message.scrollResponseHeaders(-1, 0) }),
                OnKeyPress(.left, { return Message.scrollResponseHeaders(0, -1) }),
                OnKeyPress(.down, { return Message.scrollResponseHeaders(+1, 0) }),
                OnKeyPress(.right, { return Message.scrollResponseHeaders(0, +1) }),
            ]
        }

        if activeInput == .responseBody {
            responseContent += [
                OnKeyPress(.up, { return Message.scrollResponseContent(-1, 0) }),
                OnKeyPress(.left, { return Message.scrollResponseContent(0, -1) }),
                OnKeyPress(.down, { return Message.scrollResponseContent(+1, 0) }),
                OnKeyPress(.right, { return Message.scrollResponseContent(0, +1) }),
            ]
        }

        return Window(components: [
            Box(at: .topLeft(x: 0, y: 0), size: DesiredSize(width: screenSize.width, height: 2), border: fullBorder, label: urlLabel, components: [urlInput]),
            Box(at: .topLeft(x: 0, y: 3), size: DesiredSize(width: maxSideWidth, height: 2), border: sideBorder, label: methodLabel, components: httpMethodInputs),
            GridLayout(at: .topLeft(x: 0, y: 6), size: Size(width: requestWidth, height: remainingHeight), rows: [
                .row([Box(border: sideBorder, label: requestParametersLabel, components: [urlParametersInput])]),
                .row([Box(border: sideBorder, label: requestBodyLabel, components: [bodyInput])]),
                .row([Box(border: sideBorder, label: requestHeadersLabel, components: [headersInput])]),
            ]),
            GridLayout(at: .topLeft(x: requestWidth, y: 3), size: Size(width: responseWidth, height: responseHeight), rows: [
                .row(weight: .fixed(10), [
                    Box(border: sideBorder, label: responseHeadersLabel, components: responseHeaders, scrollOffset: model.headersOffset)
                ]),
                .row([
                    Box(border: sideBorder, label: responseBodyLabel, components: responseContent, scrollOffset: model.contentOffset)
                ]),
            ]),
            Box(at: .bottomRight(x: 0, y: -1), size: DesiredSize(width: screenSize.width, height: 1), background: Text(" ", [.reverse]), components: [LabelView(text: Text(model.status, [.reverse]))]),
        ] + topLevelComponents)
    }
}

extension Suss.Error {
    var description: String {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .missingScheme: return "URL scheme is required"
        case .missingHost: return "URL host is required"
        case .cannotDecode: return "Cannot print response"
        }
    }
}

private func split(_ string: String, separator: Character, limit: Int? = nil, trim: Bool = false) -> [String] {
    guard limit != 0 else { return [] }

    var count = 1
    return string.split(whereSeparator: { c -> Bool in
        guard c == separator else { return false }
        guard let limit = limit else { return true }
        guard count < limit else { return false }
        count += 1
        return true
    }).filter({ $0.count > 0 }).map({ chars in
        let retval = String(chars)
        if trim {
            return retval.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return retval })
}
