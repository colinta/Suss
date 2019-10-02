////
///  main.swift
//

import Darwin
import Ashen

let args = Swift.CommandLine.arguments
let cmd: String = (args.count > 1 ? args[1] : "demo")

let app = App(program: Suss(), screen: TermboxScreen())
let exitState = app.run()

switch exitState {
case .quit: exit(EX_OK)
case .error: exit(EX_IOERR)
}
