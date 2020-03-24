////
///  Suss.swift
//

import Ashen
import Foundation

let Version = "1.0.0"

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
        case received(TextType, Http.Headers)
        case receivedError(String)
        case onChange(Model.Input, String)
        case scrollResponseHeaders(Int, Int)
        case scrollResponseContent(Int, Int)
        case scrollTopResponseContent
        case responseComponentSize(Size)
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

            var next: Input { Input(rawValue: rawValue + 1) ?? .first }
            var prev: Input { Input(rawValue: rawValue - 1) ?? .last }
        }

        var active: Input = .url
        var url: String = ""
        var httpMethod: Http.Method = .get
        var urlParameters: String = ""
        var urlParametersList: [String] { split(urlParameters, separator: "\n") }
        var body: String = ""
        var bodyList: [String] { split(body, separator: "\n") }
        var headers: String = ""
        var headersList: [String] { split(headers, separator: "\n")}

        var httpCommand: Http?
        var requestSent: Bool { httpCommand != nil }

        var response: (content: TextType, headers: Http.Headers)?
        var responseComponentSize: Size?
        var headersOffset = Point(x: 0, y: 0)
        var contentOffset = Point(x: 0, y: 0)

        var error: String?
        var lastSentURL: String?
        var status: String {
            var status = "[Suss v\(Version)]"
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

        init(
            url: String,
            httpMethod: Http.Method,
            urlParameters: String,
            body: String,
            headers: String
        ) {
            self.url = url
            self.httpMethod = httpMethod
            self.urlParameters = urlParameters
            self.body = body
            self.headers = headers
        }

        init() {
        }
    }

    let fullBorder = Box.Border(
        tlCorner: "┌",
        trCorner: "┐",
        blCorner: "│",
        brCorner: "│",
        tbSide: "─",
        topSide: "─",
        bottomSide: "",
        lrSide: "│",
        leftSide: "│",
        rightSide: "│"
    )
    let sideBorder = Box.Border(
        tlCorner: "┌",
        trCorner: "─",
        blCorner: "│",
        brCorner: "",
        tbSide: "─",
        topSide: "─",
        bottomSide: "",
        lrSide: "│",
        leftSide: "│",
        rightSide: ""
    )

    var initialModel: Model?

    init() {
        self.initialModel = nil
    }

    init(_ initialModel: Model) {
        self.initialModel = initialModel
    }

    func initial() -> (Model, [Command]) {
        if var initialModel = initialModel, !initialModel.url.isEmpty {
            do {
                initialModel.active = .responseBody
                let (model, cmd, _) = try submit(model: &initialModel)
                return (model, cmd)
            }
            catch {
                initialModel.error = (error as? Error)?.description
                return (initialModel, [])
            }
        }
        else {
            return (Model(), [])
        }
    }

    func update(model: inout Model, message: Message)
        -> (Model, [Command], LoopState)
    {
        switch message {
        case .quit:
            let m = model
            return (model, [], .quitAnd() {
                print("suss", terminator: "")
                if m.httpMethod != .get {
                    print(" -x \(m.httpMethod.rawValue)", terminator: "")
                }
                print(" \"\(m.url)\"", terminator: "")
                for header in m.headersList {
                    print(" \\\n    -H \(header)", terminator: "")
                }
                for query in m.urlParametersList {
                    print(" \\\n    -p \(query)", terminator: "")
                }
                for data in m.bodyList {
                    print(" \\\n    --data \(data)", terminator: "")
                }
                print("")
                return .quit
            })
        case .submit:
            do {
                return try submit(model: &model)
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
                let height: Int
                if let maxHeight = model.responseComponentSize?.height {
                    height = maxHeight
                }
                else {
                    height = 1
                }
                let maxOffset = response.content.chars.reduce(-height) { count, s in
                    s.char == "\n" ? count + 1 : count
                }
                model.contentOffset = Point(
                    x: min(maxOffset, max(0, model.contentOffset.x + dx)),
                    y: min(maxOffset, max(0, model.contentOffset.y + dy))
                )
            }
        case .scrollTopResponseContent:
            model.contentOffset = Point(x: 0, y: 0)
        case let .responseComponentSize(size):
            model.responseComponentSize = size
        }

        return (model, [], .continue)
    }

    func submit(model: inout Model) throws
        -> (Model, [Command], LoopState)
    {
        var urlString = model.url
        let urlParameters = model.urlParametersList

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

        let headers: Http.Headers = split(model.headers, separator: "\n").compactMap({
            entries -> Http.Header? in
            let kvp = split(entries, separator: ":", limit: 2)
            guard kvp.count == 2 else { return nil }
            return Http.Header(name: kvp[0], value: kvp[1])
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
                let (response, headers) = try result.map {
                    data,
                    headers -> (TextType, Http.Headers) in
                    if let str = String(data: data, encoding: .utf8) {
                        var colorizer: Colorizer = DefaultColorizer()
                        if let contentType = headers.first(where: { $0.is(.contentType) }) {
                            if contentType.value.hasPrefix("application/json") {
                                colorizer = JsonColorizer()
                            }
                        }
                        return (colorizer.process(str), headers)
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
                Message.onChange(.url, model)
            },
            onEnter: {
                Message.submit
            }
        )

        let httpMethods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]
        let activeAttrs: [Attr]
        if activeInput == .httpMethod {
            activeAttrs = [.reverse]
        }
        else {
            activeAttrs = [.underline]
        }

        let httpMethodText: [TextType] = httpMethods.map { httpMethod -> Text in
            Text(httpMethod, httpMethod == model.httpMethod.rawValue ? activeAttrs : [])
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
                OnKeyPress(.left, { Message.prevMethod }),
                OnKeyPress(.right, { Message.nextMethod }),
                OnKeyPress(.enter, { Message.submit }),
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
                Message.onChange(.body, model)
            }
        )

        let requestParametersLabel = Text("GET Parameters", highlight(if: .urlParameters))
        let urlParametersInput = InputView(
            text: model.urlParameters,
            isFirstResponder: activeInput == .urlParameters,
            isMultiline: true,
            onChange: { model in
                Message.onChange(.urlParameters, model)
            }
        )

        let requestHeadersLabel = Text("Headers", highlight(if: .headers))
        let headersInput = InputView(
            text: model.headers,
            isFirstResponder: activeInput == .headers,
            isMultiline: true,
            onChange: { model in
                Message.onChange(.headers, model)
            }
        )

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
                OnKeyPress({ _ in Message.clearError }),
                Box(
                    at: .middleCenter(),
                    size: DesiredSize(width: error.count + 4, height: 5),
                    border: .single,
                    label: "Error",
                    components: [
                        LabelView(at: .topCenter(), text: Text(error, [.foreground(.red)])),
                        LabelView(at: .bottomCenter(), text: Text("< OK >", [.reverse])),
                    ]
                ),
            ]
        }
        else if model.requestSent {
            topLevelComponents = [
            ]
        }
        else {
            topLevelComponents = [
                OnKeyPress(.esc, { Message.quit }),
                OnKeyPress(.tab, { Message.nextInput }),
                OnKeyPress(.backtab, { Message.prevInput }),
            ]
        }

        var responseHeaders: [Component] = []
        var responseContent: [Component] = [
            OnComponentResize({ size in Message.responseComponentSize(size) }),
        ]

        if let response = model.response {
            var headerString = AttrText()
            response.headers.forEach { header in
                headerString.append(Text(header.name, [.bold]))
                headerString.append(": \(header.value)\n")
            }
            responseHeaders.append(LabelView(text: headerString))
            responseContent.append(LabelView(text: response.content))
        }
        else if model.requestSent {
            responseContent.append(SpinnerView(at: .middleCenter()))
        }

        if activeInput == .responseHeaders {
            responseHeaders += [
                OnKeyPress(.up, { Message.scrollResponseHeaders(-1, 0) }),
                OnKeyPress(.left, { Message.scrollResponseHeaders(0, -1) }),
                OnKeyPress(.down, { Message.scrollResponseHeaders(+1, 0) }),
                OnKeyPress(.right, { Message.scrollResponseHeaders(0, +1) }),
            ]
        }

        if activeInput == .responseBody {
            responseContent += [
                OnKeyPress(.up, { Message.scrollResponseContent(-1, 0) }),
                OnKeyPress(.left, { Message.scrollResponseContent(0, -1) }),
                OnKeyPress(.down, { Message.scrollResponseContent(+1, 0) }),
                OnKeyPress(.right, { Message.scrollResponseContent(0, +1) }),
                OnKeyPress(.ctrl(.a), { Message.scrollTopResponseContent }),
            ]

            if let size = model.responseComponentSize {
                responseContent += [
                    OnKeyPress(.pageUp, { Message.scrollResponseContent(-(size.height - 1), 0) }),
                    OnKeyPress(.pageDown, { Message.scrollResponseContent(size.height - 1, 0) }),
                    OnKeyPress(
                        .alt(.left),
                        { Message.scrollResponseContent(0, -(size.width - 1)) }
                    ),
                    OnKeyPress(.alt(.right), { Message.scrollResponseContent(0, size.width - 1) }),
                    OnKeyPress(.space, { Message.scrollResponseContent(size.height - 1, 0) }),
                ]
            }
        }

        return Window(
            components: [
                Box(
                    at: .topLeft(x: 0, y: 0),
                    size: DesiredSize(width: screenSize.width, height: 2),
                    border: fullBorder,
                    label: urlLabel,
                    components: [urlInput]
                ),
                Box(
                    at: .topLeft(x: 0, y: 3),
                    size: DesiredSize(width: maxSideWidth, height: 2),
                    border: sideBorder,
                    label: methodLabel,
                    components: httpMethodInputs
                ),
                GridLayout(
                    at: .topLeft(x: 0, y: 6),
                    size: Size(width: requestWidth, height: remainingHeight),
                    rows: [
                        .row([
                            Box(
                                border: sideBorder,
                                label: requestParametersLabel,
                                components: [urlParametersInput]
                            )
                        ]),
                        .row([
                            Box(
                                border: sideBorder,
                                label: requestBodyLabel,
                                components: [bodyInput]
                            )
                        ]),
                        .row([
                            Box(
                                border: sideBorder,
                                label: requestHeadersLabel,
                                components: [headersInput]
                            )
                        ]),
                    ]
                ),
                GridLayout(
                    at: .topLeft(x: requestWidth, y: 3),
                    size: Size(width: responseWidth, height: responseHeight),
                    rows: [
                        .row(
                            weight: .fixed(10),
                            [
                                Box(
                                    border: sideBorder,
                                    label: responseHeadersLabel,
                                    components: responseHeaders,
                                    scrollOffset: model.headersOffset
                                )
                            ]
                        ),
                        .row([
                            Box(
                                border: sideBorder,
                                label: responseBodyLabel,
                                components: responseContent,
                                scrollOffset: model.contentOffset
                            )
                        ]),
                    ]
                ),
                Box(
                    at: .bottomRight(x: 0, y: -1),
                    size: DesiredSize(width: screenSize.width, height: 1),
                    background: Text(" ", [.reverse]),
                    components: [LabelView(text: Text(model.status, [.reverse]))]
                ),
            ] + topLevelComponents
        )
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

// can be given a 'limit' for splitting only once (i.e. headers and query
// params) and always trims the returned strings
private func split(_ string: String, separator: Character, limit: Int? = nil)
    -> [String]
{
    guard (limit ?? 1) > 0 else { return [] }

    var count = 1
    return string.split(whereSeparator: { c -> Bool in
        guard c == separator else { return false }
        guard let limit = limit else { return true }
        guard count < limit else { return false }
        count += 1
        return true
    }).compactMap({ chars in
        let retval = String(chars).trimmingCharacters(in: .whitespacesAndNewlines)
        guard retval.count > 0 else { return nil }
        return retval
    })
}
