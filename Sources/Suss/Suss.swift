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
        case focusInput(Model.Input)
        case nextMethod
        case prevMethod
        case clearError
        case received(Int, Http.Headers, TextType)
        case receivedError(String)
        case onChange(Model.Input, String)
        case scroll(Model.Input, Int, Int)
        case scrollTop(Model.Input)
        case responseHeadersSize(Size)
        case responseBodySize(Size)
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
        var bodyList: [String] { split(body, separator: "\n", trim: false) }
        var headers: String = ""
        var headersList: [String] { split(headers, separator: "\n") }

        var httpCommand: Http?
        var requestSent: Bool { httpCommand != nil }

        var response: (statusCode: Int, body: TextType, headers: Http.Headers)?
        var responseHeadersSize: Size?
        var responseBodySize: Size?
        var headersOffset = Point(x: 0, y: 0)
        var bodyOffset = Point(x: 0, y: 0)

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
                return try submit(model: &initialModel)
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
        -> Update<Model>
    {
        switch message {
        case .quit:
            let m = model
            return .quitAnd {
                    print("suss  '\(m.url)'", terminator: "")
                    if m.httpMethod != .get {
                        print(" -X \(m.httpMethod.rawValue)", terminator: "")
                    }
                    for header in m.headersList {
                        print(" \\\n -H '\(header)'", terminator: "")
                    }
                    for query in m.urlParametersList {
                        print(" \\\n -p '\(query)'", terminator: "")
                    }
                    for data in m.bodyList {
                        print(" \\\n --data '\(data)'", terminator: "")
                    }
                    print("")
                }
        case .submit:
            do {
                let (model, commands) = try submit(model: &model)
                return .update(model, commands)
            }
            catch {
                model.error = (error as? Error)?.description
                return .model(model)
            }
        case let .received(statusCode, headers, body):
            model.httpCommand = nil
            model.response = (statusCode: statusCode, body: body, headers: headers)
        case let .receivedError(error):
            model.httpCommand = nil
            model.error = error
        case .nextInput:
            model.active = model.active.next
        case .prevInput:
            model.active = model.active.prev
        case let .focusInput(input):
            model.active = input
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
        case let .scroll(input, dy, dx):
            guard let response = model.response else { return .noChange }

            let width: Int, height: Int
            let prevOffset: Point
            let lines: [String]
            switch input {
            case .responseHeaders:
                width = model.responseHeadersSize?.width ?? 0
                height = model.responseHeadersSize?.height ?? 0
                prevOffset = model.headersOffset

                lines = ["status-code: \(response.statusCode)", "EOF"]
                    + response.headers.map { "\($0.name)=\($0.value)" }
            case .responseBody:
                width = model.responseBodySize?.width ?? 0
                height = model.responseBodySize?.height ?? 0
                prevOffset = model.bodyOffset

                let body = response.body.chars.map { $0.char ?? "" }.joined(separator: "")
                lines = split(body, separator: "\n", trim: false) + ["EOF", "EOF"]
            default:
                width = 0
                height = 0
                prevOffset = .zero
                lines = []
            }

            let maxHorizontalOffset = lines.reduce(0) { maxLen, line in
                max(maxLen, line.count)
            } - width
            let maxVerticalOffset = lines.count - height
            let offset = Point(
                x: max(0, min(maxHorizontalOffset, prevOffset.x + dx)),
                y: max(0, min(maxVerticalOffset, prevOffset.y + dy))
            )

            switch input {
            case .responseHeaders:
                model.headersOffset = offset
            case .responseBody:
                model.bodyOffset = offset
            default:
                break
            }
        case let .scrollTop(input):
            switch input {
            case .responseHeaders:
                model.headersOffset = Point(x: 0, y: 0)
            case .responseBody:
                model.bodyOffset = Point(x: 0, y: 0)
            default:
                break
            }
        case let .responseBodySize(size):
            model.responseBodySize = size
        case let .responseHeadersSize(size):
            model.responseHeadersSize = size
        }

        return .model(model)
    }

    func submit(model: inout Model) throws
        -> (Model, [Command])
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
                let (statusCode, headers, data) = try result.get()
                guard let str = String(data: data, encoding: .utf8) else { throw Error.cannotDecode }

                var colorizer: Colorizer = DefaultColorizer()
                if let contentType = headers.first(where: { $0.is(.contentType) }) {
                    if contentType.value.hasPrefix("application/json") {
                        colorizer = JsonColorizer()
                    }
                    else if contentType.value.hasPrefix("text/html") {
                        colorizer = HtmlColorizer()
                    }
                }

                return Message.received(statusCode, headers, colorizer.process(str))
            }
            catch {
                let errorDescription = (error as? Error)?.description ?? "Unknown error"
                return Message.receivedError(errorDescription)
            }
        }

        model.httpCommand = cmd
        return (model, [cmd])
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

        var topLevelComponents: [Component] = []
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
        else {
            topLevelComponents = [
                OnKeyPress(.esc, { Message.quit }),
                OnKeyPress(.ctrl(.o), { Message.submit })
            ]
            if !model.requestSent {
                topLevelComponents += [
                    OnKeyPress(.tab, { Message.nextInput }),
                    OnKeyPress(.backtab, { Message.prevInput }),
                ]
            }
        }

        var responseHeaders: [Component] = [
            OnComponentResize(Message.responseHeadersSize),
        ]
        var responseContent: [Component] = [
            OnComponentResize(Message.responseBodySize),
        ]

        if let response = model.response {
            var headerString = AttrText(Text("Status-code: ", [.bold]))
            headerString.append(Text("\(response.statusCode)\n"))
            response.headers.forEach { header in
                headerString.append(Text(header.name, [.bold]))
                headerString.append(": \(header.value)\n")
            }
            headerString.append(Text("EOF\n", [.reverse]))
            responseHeaders.append(LabelView(text: headerString))
            responseContent.append(LabelView(text: response.body + Text("\nEOF", [.reverse])))
        }
        else if model.requestSent {
            responseContent.append(SpinnerView(at: .middleCenter()))
        }

        if activeInput == .responseHeaders || activeInput == .responseBody,
            let activeInput = activeInput
        {
            topLevelComponents += [
                OnKeyPress(.up, { Message.scroll(activeInput, -1, 0) }),
                OnKeyPress(.left, { Message.scroll(activeInput, 0, -1) }),
                OnKeyPress(.down, { Message.scroll(activeInput, +1, 0) }),
                OnKeyPress(.right, { Message.scroll(activeInput, 0, +1) }),
                OnKeyPress(.ctrl(.a), { Message.scroll(activeInput, 0, Int.min) }),
                OnKeyPress(.ctrl(.e), { Message.scroll(activeInput, 0, Int.max) }),
                OnKeyPress(.home, { Message.scrollTop(activeInput) }),
                OnKeyPress(.end, { Message.scroll(activeInput, Int.max, 0) }),
                OnKeyPress(.enter, { Message.submit }),
            ]

            if let size = model.responseBodySize {
                topLevelComponents += [
                    OnKeyPress(.pageUp, { Message.scroll(activeInput, -(size.height - 1), 0) }),
                    OnKeyPress(.pageDown, { Message.scroll(activeInput, size.height - 1, 0) }),
                    OnKeyPress(
                        .alt(.left),
                        { Message.scroll(activeInput, 0, -(size.width - 1)) }
                    ),
                    OnKeyPress(.alt(.right), { Message.scroll(activeInput, 0, size.width - 1) }),
                    OnKeyPress(.space, { Message.scroll(activeInput, size.height - 1, 0) }),
                ]
            }
        }

        return Window(
            components: [
                Clickable(
                    Box(
                        at: .topLeft(x: 0, y: 0),
                        size: DesiredSize(width: screenSize.width, height: 2),
                        border: fullBorder,
                        label: urlLabel,
                        components: [urlInput]
                    )
                ) { Message.focusInput(.url) },
                Clickable(
                    Box(
                        at: .topLeft(x: 0, y: 3),
                        size: DesiredSize(width: maxSideWidth, height: 2),
                        border: sideBorder,
                        label: methodLabel,
                        components: httpMethodInputs
                    )
                ) { Message.focusInput(.httpMethod) },
                GridLayout(
                    at: .topLeft(x: 0, y: 6),
                    size: Size(width: requestWidth, height: remainingHeight),
                    rows: [
                        .row([
                            Clickable(
                                Box(
                                    border: sideBorder,
                                    label: requestParametersLabel,
                                    components: [urlParametersInput]
                                )
                            ) { Message.focusInput(.urlParameters) }
                        ]),
                        .row([
                            Clickable(
                                Box(
                                    border: sideBorder,
                                    label: requestBodyLabel,
                                    components: [bodyInput]
                                )
                            ) { Message.focusInput(.body) }
                        ]),
                        .row([
                            Clickable(
                                Box(
                                    border: sideBorder,
                                    label: requestHeadersLabel,
                                    components: [headersInput]
                                )
                            ) { Message.focusInput(.headers) }
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
                                Clickable(
                                    Box(
                                        border: sideBorder,
                                        label: responseHeadersLabel,
                                        components: responseHeaders,
                                        scrollOffset: model.headersOffset
                                    )
                                ) { Message.focusInput(.responseHeaders) }
                            ]
                        ),
                        .row([
                            Clickable(
                                Box(
                                    border: sideBorder,
                                    label: responseBodyLabel,
                                    components: responseContent,
                                    scrollOffset: model.bodyOffset
                                )
                            ) { Message.focusInput(.responseBody) }
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
private func split(_ string: String, separator: Character, limit: Int? = nil, trim: Bool = true)
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
        if trim {
            let retval = String(chars).trimmingCharacters(in: .whitespacesAndNewlines)
            guard retval.count > 0 else { return nil }
            return retval
        }
        else {
            return String(chars)
        }
    })
}
