// prActIceTests.swift

import Testing
@testable import prActIce

@MainActor
@Test func tui() async throws {
    let tui = SwiftTUI.shared
    let options = ["新建", "打开", "保存", "退出"]
    let choice = tui.List(options)

    switch choice {
    case 0:
        tui.Text("You selected New!")
    case 1:
        tui.Text("You selected Open!")
    case 2:
        tui.Text("You selected Save!")
    case 3:
        tui.Text("You selected Exit!")
    default:
        tui.Text("No choice.")
    }
}
