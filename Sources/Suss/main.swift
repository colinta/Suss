////
///  main.swift
//

import ArgumentParser
import Ashen

struct Main: ParsableCommand {
    enum Error: Swift.Error {
        case unknownMethod(String)
    }

    @Argument()
    var url: String?

    @Option(name: [.customShort("X"), .customLong("request")])
    var method: String = "GET"

    @Option(name: [.customShort("p"), .customLong("param")])
    var params: [String] = []

    @Option(name: .shortAndLong)
    var data: [String] = []

    @Option(name: [.customShort("H"), .customLong("header")])
    var headers: [String] = []

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

        var params = self.params

        let url: String
        if let urlArg = self.url {
            let urlAndQuery = split(urlArg, separator: "?", limit: 2)
            url = urlAndQuery[0]
            if urlAndQuery.count == 2 {
                let urlParams = split(urlAndQuery[1], separator: "&")
                if params.isEmpty {
                    params += urlParams
                } else {
                    params = urlParams
                }
            }
        } else {
            url = ""
        }

        var urlParameters: String
        if params.isEmpty {
            urlParameters = ""
        } else {
            urlParameters = params.joined(separator: "\n") + "\n"
        }

        let model = Suss.Model(
            url: url,
            httpMethod: httpMethod,
            urlParameters: urlParameters,
            body: data.joined(separator: "\n"),
            headers: headers.joined(separator: "\n")
        )

        let app = App(program: Suss(model))
        try app.run()
    }
}

Main.main()
