// prActIce.swift

import Foundation
import WinSDK

@main
struct prActIce {
    static func main() async {
        let practiceStore = Persistance<[question]>(filename: "practice.json")
        let practiceList: [question] = practiceStore.read() ?? []
        let tui = SwiftTUI.shared
        while true {
            let options = ["做题", "回顾", "退出"]
            let choice = tui.List(options, title: "欢迎来到prActIce。选择一个选项以继续。")

            switch choice {
            case 0:
                let subjects = ["语文", "数学", "英语", "科学", "社会"]
                let choiceSub = tui.List(subjects, title: "选择学科")
                var sub: subject
                switch choiceSub {
                case 0:
                    sub = .Chinese
                case 1:
                    sub = .Math
                case 2:
                    sub = .English
                case 3:
                    sub = .Science
                case 4:
                    sub = .Social
                default:
                    sub = .Math
                }
                tui.Text("学科：\(subjects[choiceSub])", color: .info)
                var sum = tui.TextField("题量")
                tui.clean()
                tui.Text("学科：\(subjects[choiceSub])", color: .info)
                tui.Text("题量：\(sum)", color: .info)
                var ques: String = ""
                var ans: String = ""
                await tui.LoadingSpinner(title: "正在生成...", done: "✓ 完成", until: {
                    try? await Task.sleep(nanoseconds: 2000_000_000_0)
                    ques = "1+1=?"
                    ans = "2"
                    return
                })
                tui.Text("题目：\(ques)")
                let userAns = tui.TextField("你的答案")
                var isCorrect = false
                await tui.LoadingSpinner(title: "正在批改...", done: "批改完成", until: {
                    try? await Task.sleep(nanoseconds: 2000_000_000_0)
                    if userAns == ans {
                        isCorrect = true
                    }
                    return
                }, doneColor: .info)
                if isCorrect {
                    tui.Text("✓ 正确", color: .success)
                } else {
                    tui.Text("✕ 错误 ", color: .error, nextLine: false)
                    tui.Text("已加入错题本！", color: .info)
                }
                tui.Text("按下任意键继续...")
                tui.waitKey()
            case 1:
                tui.Text("回顾", color: .title)
                tui.Text("按下任意键继续...")
                tui.waitKey()
            case 2:
                return
            default:
                return
            }
        }
        
    }
}
