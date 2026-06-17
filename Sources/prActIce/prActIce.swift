// prActIce.swift

import Foundation
import WinSDK

@main
struct prActIce {
    static func main() async {
        let practiceStore = Persistance<[Question]>(filename: "practice.json")
        var practiceList: [Question] = practiceStore.read() ?? []
        let tui = SwiftTUI.shared
        while true {
            let options = ["做题", "回顾", "退出"]
            let choice = tui.List(options, title: "欢迎来到prActIce。选择一个选项以继续。")

            switch choice {
            case 0:
                let subjects = ["语文", "数学", "英语", "科学", "社会"]
                let choiceSub = tui.List(subjects, title: "选择学科")
                var sub: Subject
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
                var sum = 1
                var input = ""
                while true {
                    input = tui.TextField("题量")
                    if let ans = Int(input) {
                        sum = ans
                        break
                    } else {
                        tui.Text("无效的输入，请重试", color: .error)
                    }
                }
                tui.clean()
                tui.Text("学科：\(subjects[choiceSub])", color: .info)
                tui.Text("题量：\(sum)", color: .info)
                var ques: String = ""
                var ans: String = ""
                for i in 1...sum {
                    await tui.LoadingSpinner(title: "正在生成(\(i)/\(sum))...", done: "✓ 生成完成(\(i)/\(sum))", until: {
                        try? await Task.sleep(nanoseconds: 2000_000_000_0)
                        ques = "1+1=?"
                        ans = "2"
                        return
                    })
                    tui.Text("题目：\(ques)")
                    let userAns = tui.TextField("你的答案")
                    var isCorrect = false
                    await tui.LoadingSpinner(title: "正在批改...", done: "批改完成", until: {
                        try? await Task.sleep(nanoseconds: 5000_000_000)
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
                    practiceList.append(Question(question: ques, isWrong: !isCorrect, userAnswer: userAns, subject: sub))
                }
                tui.Text("按下任意键以回到开始页面...")
                tui.waitKey()
            case 1:
                tui.Text("回顾", color: .title)
                if !practiceList.isEmpty {
                    var isBack = true
                    while isBack {
                        var showPracticeList: [String] = []
                        for ques in practiceList {
                            switch ques.subject {
                            case .Chinese:
                                showPracticeList.append("语文 \(ques.question) \(ques.isWrong ? "在错题本中" : "")")
                            case .Math:
                                showPracticeList.append("数学 \(ques.question) \(ques.isWrong ? "在错题本中" : "")")
                            case .English:
                                showPracticeList.append("英语 \(ques.question) \(ques.isWrong ? "在错题本中" : "")")
                            case .Science:
                                showPracticeList.append("科学 \(ques.question) \(ques.isWrong ? "在错题本中" : "")")
                            case .Social:
                                showPracticeList.append("社会 \(ques.question) \(ques.isWrong ? "在错题本中" : "")")
                            }
                        }
                        let select = tui.List(showPracticeList, title: "选择要回顾的题目")
                        if practiceList[select].isWrong {
                            let option = tui.List(["攻击错题！", "我真的不会啊...", "返回列表", "回到开始页面"], title: "\(practiceList[select].question) ✕ 在错题本中")
                            switch option {
                            case 0:
                                tui.Text(practiceList[select].question, color: .title)
                                let ans = tui.TextField("订正")
                                var isCorrect = false
                                await tui.LoadingSpinner(title: "正在批改...", done: "批改完成", until: {
                                    try? await Task.sleep(nanoseconds: 5000_000_000)
                                    if ans == "2" {
                                        isCorrect = true
                                    }
                                    return
                                }, doneColor: .info)
                                if isCorrect {
                                    tui.Text("✓ 正确", color: .success)
                                    tui.Text("错题被击败", color: .info)
                                    practiceList[select].isWrong = false
                                } else {
                                    tui.Text("✕ 错误", color: .error)
                                    tui.Text("攻击失败", color: .info)
                                }
                                isBack = false
                            case 1:
                                let promise = "I can't do this. Please tell me the answer."
                                tui.Text("你真的不会吗？", color: .title)
                                tui.Text("完整输入下方的承诺以继续。")
                                tui.Text(promise, color: .error)
                                let check = tui.TextField("输入", titleColor: .warning)
                                if check == promise {
                                    tui.Text("正确答案是： 2")
                                } else {
                                    tui.Text("输入有偏差。不会显示答案。", color: .error)
                                }
                                isBack = false
                            case 2:
                                isBack = true
                            default:
                                isBack = false
                            }
                        } else {
                            let option = tui.List(["返回列表", "回到开始页面"], title: "\(practiceList[select].question) ✓ 正确/订正对")
                            switch option {
                            case 0:
                                isBack = true
                            default:
                                isBack = false
                            }
                        }
                    }
                } else {
                    tui.Text("练习册中还没有任何题目。前往开始页面选择“做题”来开始练习。")
                }
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
