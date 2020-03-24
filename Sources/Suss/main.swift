////
///  main.swift
//

import Ashen
import ArgumentParser

struct Main: ParsableCommand {
    enum Error: Swift.Error {
        case exit
        case unknownMethod(String)
    }

    @Argument()
    var url: String?

    @Option(name: [.customShort("X"), .customLong("request")], default: "GET")
    var method: String

    @Option(name: [.customShort("p"), .customLong("param")])
    var params: [String]

    @Option(name: .shortAndLong)
    var data: [String]

    @Option(name: [.customShort("H"), .customLong("header")])
    var headers: [String]

    func run() throws {
        let httpMethod: Http.Method
        switch method.lowercased() {
        case "get":
            httpMethod = .get
        case "post":
            httpMethod = .post
        case "put":
            httpMethod = .put
        case "patch":
            httpMethod = .patch
        case "delete":
            httpMethod = .delete
        case "head":
            httpMethod = .head
        case "options":
            httpMethod = .options
        default:
            throw Error.unknownMethod(method)
        }

        let urlParameters: String
        if params.isEmpty {
            urlParameters = ""
        }
        else {
            urlParameters = params.joined(separator: "\n") + "\n"
        }

        let model = Suss.Model(
            url: url ?? "",
            httpMethod: httpMethod,
            urlParameters: urlParameters,
            body: data.joined(separator: "\n"),
            headers: headers.joined(separator: "\n")
        )

        let app = App(program: Suss(model), screen: TermboxScreen())
        switch app.run() {
        case .quit:
            break
        case .error:
            throw Error.exit
        }
    }
}

Main.main()
