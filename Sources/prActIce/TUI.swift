// TUI.swift

import WinSDK
import Foundation

struct Color {
    let ansiCode: String
    private init(ansiCode: String){
        self.ansiCode = ansiCode
    }
    
    public static let black = Color(ansiCode: "30")
    public static let red = Color(ansiCode: "31")
    public static let green = Color(ansiCode: "32")
    public static let yellow = Color(ansiCode: "33")
    public static let blue = Color(ansiCode: "34")
    public static let cyan = Color(ansiCode: "36")
    public static let white = Color(ansiCode: "37")
    public static let gray = Color(ansiCode: "90")
    public static let lightRed = Color(ansiCode: "91")
    public static let lightGreen = Color(ansiCode: "92")
    public static let lightYellow = Color(ansiCode: "93")
    public static let lightBlue = Color(ansiCode: "94")
    public static let lightMagenta = Color(ansiCode: "95")
    public static let lightCyan = Color(ansiCode: "96")
    public static let lightWhite = Color(ansiCode: "97")
    public static let backgroundBlack = Color(ansiCode: "40")
    public static let backgroundRed = Color(ansiCode: "41")
    public static let backgroundGreen = Color(ansiCode: "42")
    public static let backgroundYellow = Color(ansiCode: "43")
    public static let backgroundBlue = Color(ansiCode: "44")
    public static let backgroundMagenta = Color(ansiCode: "45")
    public static let backgroundCyan = Color(ansiCode: "46")
    public static let backgroundWhite = Color(ansiCode: "47")

    public static let error = Color.red
    public static let warning = Color.yellow
    public static let success = Color.green
    public static let info = Color.gray
    public static let title = Color.lightCyan
}

indirect enum Key {
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    case n0, n1, n2, n3, n4, n5, n6, n7, n8, n9
    case enter
    case esc
    case space
    case tab
    case backspace
    case delete
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight

    case ctrl(Key?)
    case alt(Key?)
    case shift(Key?)
    case fKey
}

@MainActor
class SwiftTUI {
    public static let shared = SwiftTUI()

    private let hStdout: HANDLE
    private let hStdin: HANDLE
    private var nowX: Int16 = 0
    private var nowY: Int16 = 0

    private init(){
        self.hStdout = GetStdHandle(STD_OUTPUT_HANDLE)
        self.hStdin = GetStdHandle(STD_INPUT_HANDLE)

        var mode: DWORD = 0
        GetConsoleMode(hStdout, &mode)
        mode |= DWORD(ENABLE_VIRTUAL_TERMINAL_PROCESSING)
        SetConsoleMode(hStdout, mode)

        GetConsoleMode(hStdin, &mode)
        mode &= ~DWORD(ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT)
        SetConsoleMode(hStdin, mode)

        clean()
    }

    public func getKey(_ character: Character) -> Key? {
        switch character {
        case "a"..."z":
            switch character {
            case "a": return .a
            case "b": return .b
            case "c": return .c
            case "d": return .d
            case "e": return .e
            case "f": return .f
            case "g": return .g
            case "h": return .h
            case "i": return .i
            case "j": return .j
            case "k": return .k
            case "l": return .l
            case "m": return .m
            case "n": return .n
            case "o": return .o
            case "p": return .p
            case "q": return .q
            case "r": return .r
            case "s": return .s
            case "t": return .t
            case "u": return .u
            case "v": return .v
            case "w": return .w
            case "x": return .x
            case "y": return .y
            case "z": return .z
            default: return nil
            }
        case "0"..."9":
            switch character {
            case "0": return .n0
            case "1": return .n1
            case "2": return .n2
            case "3": return .n3
            case "4": return .n4
            case "5": return .n5
            case "6": return .n6
            case "7": return .n7
            case "8": return .n8
            case "9": return .n9
            default: return nil
            }
        case " ": return .space
        default: return nil
        }
    }
    public func getCharacter(_ key: Key) -> Character? {
        switch key {
        case .a: return "a"
        case .b: return "b"
        case .c: return "c"
        case .d: return "d"
        case .e: return "e"
        case .f: return "f"
        case .g: return "g"
        case .h: return "h"
        case .i: return "i"
        case .j: return "j"
        case .k: return "k"
        case .l: return "l"
        case .m: return "m"
        case .n: return "n"
        case .o: return "o"
        case .p: return "p"
        case .q: return "q"
        case .r: return "r"
        case .s: return "s"
        case .t: return "t"
        case .u: return "u"
        case .v: return "v"
        case .w: return "w"
        case .x: return "x"
        case .y: return "y"
        case .z: return "z"
        case .n0: return "0"
        case .n1: return "1"
        case .n2: return "2"
        case .n3: return "3"
        case .n4: return "4"
        case .n5: return "5"
        case .n6: return "6"
        case .n7: return "7"
        case .n8: return "8"
        case .n9: return "9"
        default: return nil
        }
    }

    public func clean(){
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        fflush(stdout)
        nowX = 0
        nowY = 0
    }
    private func moveTo(x: Int16, y: Int16){
        print("\u{001B}[\(y+1);\(x+1)H", terminator: "")
        fflush(stdout)
        nowX = x
        nowY = y
    } 
    private func setColor(_ color: Color){
        print("\u{001B}[\(color.ansiCode)m", terminator: "")
        fflush(stdout)
    }
    private func resetColor(){
        print("\u{001B}[0m", terminator: "")
        fflush(stdout)
    }
    public func waitKey() {
        _ = readKey()
    }
    public func readKey() -> Key {
        var inputRecord = INPUT_RECORD()
        var eventsRead: DWORD = 0

        while true {
            ReadConsoleInputW(hStdin, &inputRecord, 1, &eventsRead)
            if inputRecord.EventType == KEY_EVENT {
                let keyEvent = inputRecord.Event.KeyEvent
                if keyEvent.bKeyDown == true && keyEvent.wRepeatCount > 0 {
                    let char = keyEvent.uChar.UnicodeChar
                    let vk = keyEvent.wVirtualKeyCode
                    var key: Key?
                    
                    if char != 0 {
                        let character = Character(UnicodeScalar(Int(char))!)
                        key = getKey(character)
                    }

                    switch vk {
                    case 0x25: key = .arrowLeft
                    case 0x26: key = .arrowUp
                    case 0x27: key = .arrowRight
                    case 0x28: key = .arrowDown
                    case 0x0D: key = .enter
                    case 0x1B: key = .esc
                    case 0x09: key = .tab
                    case 0x08: key = .backspace
                    case 0x2E: key = .delete
                    default: 
                        if key == nil {
                            key = .fKey
                        }
                    }
                    let controlState = keyEvent.dwControlKeyState
                    if controlState & DWORD(LEFT_CTRL_PRESSED) != 0 || controlState & DWORD(RIGHT_CTRL_PRESSED) != 0 {
                        key = .ctrl(key)
                    }
                    if controlState & DWORD(LEFT_ALT_PRESSED) != 0 || controlState & DWORD(RIGHT_ALT_PRESSED) != 0 {
                        key = .alt(key)
                    }
                    if controlState & DWORD(SHIFT_PRESSED) != 0 {
                        key = .shift(key)
                    }
                    return key ?? .space
                }
            }
        }
    }

    public func Text(_ content: String, x: Int16? = nil, y: Int16? = nil, color: Color = .white, nextLine: Bool = true){
        if let x=x, let y=y {
            moveTo(x: x, y: y)
        }
        setColor(color)
        print(content, terminator: "")
        fflush(stdout)
        resetColor()
        if nextLine {
            moveTo(x: 0, y: nowY+1)
        }
    }
    public func List(_ items: [String], title: String = "选择一个选项") -> Int {
        guard !items.isEmpty else { return -1 }
        clean()
        var selected = 0
        Text(title, color: .title)
        Text("")

        for item in items {
            if item == items[0]{
                Text(item, color: .cyan)
            } else {
                Text(item)
            }
        }
        Text("")
        Text("↑↓ 移动高亮项 | ↩ 选择", color: .info)
        moveTo(x: Int16(items[0].count+1), y: 2)

        while true {
            let key = readKey()

            switch key {
            case .arrowUp:
                if selected > 0 {
                    Text(items[selected], x: 0, y: Int16(selected+2), nextLine: false)
                    selected -= 1
                    Text(items[selected], x: 0, y: Int16(selected+2), color: .cyan, nextLine: false)
                }
            case .arrowDown:
                if selected < items.count-1 {
                    Text(items[selected], x: 0, y: Int16(selected+2), nextLine: false)
                    selected += 1
                    Text(items[selected], x: 0, y: Int16(selected+2), color: .cyan, nextLine: false)
                }
            case .enter:
                clean()
                return selected
            default:
                break
            }
        }
    }
    
    public func TextField(_ title: String, x: Int16? = nil, y: Int16? = nil, titleColor: Color = .white) -> String {
        if let x=x, let y=y{
            moveTo(x: x, y: y)
        }
        Text(title, color: titleColor, nextLine: false)
        Text(" | ", nextLine: false)
        Text("")
        Text("↩ 完成", color: .info)
        moveTo(x: Int16(title.count)+5, y: nowY-2)
        var mode: DWORD = 0
        GetConsoleMode(hStdin, &mode)
        mode |= DWORD(ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT)
        SetConsoleMode(hStdin, mode)
        let input = readLine() ?? ""
        GetConsoleMode(hStdin, &mode)
        mode &= ~DWORD(ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT)
        SetConsoleMode(hStdin, mode)
        return input
    }
}
