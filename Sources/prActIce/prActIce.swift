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
            let options = ["做题", "回顾", "退出", "清空练习册并退出(危险)"]
            let choice = tui.List(options, title: "欢迎来到prActIce。选择一个选项以继续。")

            switch choice {
            case 0:
                let subjects = ["语文", "数学", "英语", "科学", "历史", "道德与法治", "地理"]
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
                    sub = .History
                case 5:
                    sub = .EthicsAndTheRuleOfLaw
                case 6:
                    sub = .Geography
                default:
                    sub = .Math
                }
                let grades = ["七年级上册", "七年级下册", "八年级上册", "八年级下册"]
                let choiceGrade = tui.List(grades, title: "选择年级")
                var grade: Grade
                switch choiceGrade {
                case 0:
                    grade = .A7
                case 1:
                    grade = .B7
                case 2:
                    grade = .A8
                case 3:
                    grade = .B8
                default:
                    grade = .A7
                }
                var units: [String] = []
                await tui.LoadingSpinner(title: "正在加载...", done: "✓ 加载完成", until: {
                    if let unitDict = unitDic[grade]?[sub] {
                        for (_, unitName) in unitDict.sorted(by: { $0.key < $1.key }) {
                            units.append(unitName)
                        }
                    }
                })
                let unit = tui.List(units, title: "选择单元")
                tui.Text("学科：\(subjects[choiceSub])", color: .info)
                tui.Text("年级：\(grades[choiceGrade])", color: .info)
                tui.Text("单元：\(units[unit])", color: .info)
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
                var ques: String = ""
                var ans: String = ""
                for i in 1...sum {
                    await tui.LoadingSpinner(title: "正在生成(\(i)/\(sum))...", done: "✓ 生成完成(\(i)/\(sum))", until: {
                        try? await Task.sleep(nanoseconds: 2000_000_000)
                        ques = "1+1=?"
                        ans = "2"
                        return
                    })
                    tui.Text("题目：\(ques)")
                    let userAns = tui.TextField("你的答案")
                    var isCorrect = false
                    await tui.LoadingSpinner(title: "正在批改...", done: "批改完成", until: {
                        try? await Task.sleep(nanoseconds: 5000_000_00)
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
                    practiceList.append(Question(question: ques, isWrong: !isCorrect, userAnswer: userAns, unit: Unit(grade: grade, subject: sub, unit: unit+1)))
                    practiceStore.save(practiceList)
                }
                tui.Text("按下任意键以回到开始页面...")
                tui.waitKey()
            case 1:
                tui.Text("回顾", color: .title)
                if !practiceList.isEmpty {
                    var isBack = true
                    while isBack {
                        var showPracticeList: [String] = []
                        await tui.LoadingSpinner(title: "正在加载...", done: "✓ 加载完成", until: {
                            for ques in practiceList {
                                switch ques.unit.subject {
                                case .Chinese:
                                    showPracticeList.append("语文 \(unitDic[ques.unit.grade]?[ques.unit.subject]?[ques.unit.unit] ?? "第\(ques.unit.unit)单元") \(ques.isWrong ? "     ! 在错题本中" : "")")
                                case .Math:
                                    showPracticeList.append("数学 \(unitDic[ques.unit.grade]?[ques.unit.subject]?[ques.unit.unit] ?? "第\(ques.unit.unit)单元") \(ques.isWrong ? "     ! 在错题本中" : "")")
                                case .English:
                                    showPracticeList.append("英语 \(unitDic[ques.unit.grade]?[ques.unit.subject]?[ques.unit.unit] ?? "第\(ques.unit.unit)单元") \(ques.isWrong ? "     ! 在错题本中" : "")")
                                case .Science:
                                    showPracticeList.append("科学 \(unitDic[ques.unit.grade]?[ques.unit.subject]?[ques.unit.unit] ?? "第\(ques.unit.unit)单元") \(ques.isWrong ? "     ! 在错题本中" : "")")
                                case .History:
                                    showPracticeList.append("历史 \(unitDic[ques.unit.grade]?[ques.unit.subject]?[ques.unit.unit] ?? "第\(ques.unit.unit)单元") \(ques.isWrong ? "     ! 在错题本中" : "")")
                                case .EthicsAndTheRuleOfLaw:
                                    showPracticeList.append("道德与法治 \(unitDic[ques.unit.grade]?[ques.unit.subject]?[ques.unit.unit] ?? "第\(ques.unit.unit)单元") \(ques.isWrong ? "     ! 在错题本中" : "")")
                                case .Geography:
                                    showPracticeList.append("地理 \(unitDic[ques.unit.grade]?[ques.unit.subject]?[ques.unit.unit] ?? "第\(ques.unit.unit)单元") \(ques.isWrong ? "     ! 在错题本中" : "")")
                                }
                            }
                        })
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
                                    practiceStore.save(practiceList)
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
                tui.Text("按下任意键以回到开始页面...")
                tui.waitKey()
            case 2:
                practiceStore.save(practiceList)
                return
            case 3:
                tui.Text("你真的要清空练习册吗？", color: .title)
                tui.Text("完整输入下方文字以继续。")
                let agree = "Yes, I want to clean my practice book."
                tui.Text(agree, color: .error)
                let check = tui.TextField("输入")
                if check == agree {
                    practiceStore.save([])
                    tui.Text("清空完成。", color: .success)
                } else {
                    tui.Text("输入有偏差。不会清空练习册。", color: .error)
                }
                return 
            default:
                return
            }
        }
        
    }
}
