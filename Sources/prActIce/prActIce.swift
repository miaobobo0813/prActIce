// prActIce.swift

import Foundation
import WinSDK

@main
struct prActIce {
    static func main() async {
        let practiceStore = Persistance<[Question]>(filename: "practice.json")
        var practiceList: [Question] = practiceStore.read() ?? []
        let tui = SwiftTUI.shared

        var isError = false, errorMessage = ""
        await tui.LoadingSpinner(title: "正在加载QGIntelligence...首次加载可能花费数分钟...", done: "QGIntelligence加载完成。", until: {
            Task(priority: .background) {
                do {
                    try await InitIntelligence()
                } catch InitIntelligenceError.pythonNotFound {
                    isError = true
                    errorMessage = "尚未安装Python环境。运行'winget install python'以继续。"
                    return
                } catch InitIntelligenceError.pyError(message: let error) {
                    isError = true
                    errorMessage = "发生未知错误。以下是详细信息：\(error)"
                    return
                } catch {
                    isError = true
                    errorMessage = "加载QGIntelligence时发生未知错误。"
                    return
                }
            }
            do {
                try await checkServiceStatus()
            } catch {
                isError = true
                errorMessage = "QGIntelligence服务未能启动。"
                return
            }
        }, doneColor: .info)

        if isError {
            tui.Text(errorMessage, color: .error)
            return
        }
        
        while true {
            let options = ["做题", "回顾", "退出", "清空练习册并退出(危险)"]
            let choice = tui.List(options, title: "欢迎来到prActIce。选择一个选项以继续。")

            switch choice {
            case 0:
                let subjects = ["语文", "数学", "英语", "科学", "历史", "道德与法治", "地理"]
                let transSubjects: [Subject] = [.Chinese, .Math, .English, .Science, .History, .EthicsAndTheRuleOfLaw, .Geography]
                let choiceSub = tui.List(subjects, title: "选择学科")
                let sub = transSubjects[choiceSub]
                let grades = ["七年级上册", "七年级下册", "八年级上册", "八年级下册"]
                let transGrades: [Grade] = [.A7, .B7, .A8, .B8]
                let choiceGrade = tui.List(grades, title: "选择年级")
                let grade = transGrades[choiceGrade]
                var units: [String] = []
                await tui.LoadingSpinner(title: "正在加载...", done: "✓ 加载完成", until: {
                    units = unitDic[grade]?[sub]?
                        .sorted(by: { $0.key < $1.key })
                        .map { $0.value } ?? []
                })
                let unit = tui.List(units, title: "选择单元")
                let types = ["选择/判断", "填空", "解答/综合"]
                let transTypes: [quesType] = [.choose, .fillBlank, .answer]
                let typeChoice = tui.List(types, title: "选择题型")
                let type = transTypes[typeChoice]
                tui.Text("学科：\(subjects[choiceSub])", color: .info)
                tui.Text("年级：\(grades[choiceGrade])", color: .info)
                tui.Text("单元：\(units[unit])", color: .info)
                tui.Text("题型：\(types[typeChoice])", color: .info)
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
                for i in 1...sum {
                    await tui.LoadingSpinner(title: "正在生成(\(i)/\(sum))...", done: "✓ 生成完成(\(i)/\(sum))", until: {
                        ques = await getQues(subject: sub, unit: Unit(grade: grade, subject: sub, unit: unit+1), type: type)
                        return
                    })
                    tui.Text("题目：\(ques)")
                    let userAns = tui.TextField("你的答案")
                    var isCorrect = false
                    let questionQues = Question(question: ques, isWrong: !isCorrect, userAnswer: userAns, unit: Unit(grade: grade, subject: sub, unit: unit+1), type: type)
                    await tui.LoadingSpinner(title: "正在批改...", done: "批改完成", until: {
                        isCorrect = await gradeQues(ques: questionQues, answer: userAns)
                        return
                    }, doneColor: .info)
                    if isCorrect {
                        tui.Text("✓ 正确", color: .success)
                    } else {
                        tui.Text("✕ 错误 ", color: .error, nextLine: false)
                        tui.Text("已加入错题本！", color: .info)
                    }
                    if questionQues.question == "发生未知错误。输入OK以继续" {
                        tui.Text("由于发生未知错误，将不会加入练习册。")
                    } else {
                        practiceList.append(questionQues)
                        practiceStore.save(practiceList)
                    }
                }
                tui.Text("按下任意键以回到开始页面...", color: .info)
                tui.waitKey()
            case 1:
                tui.Text("回顾", color: .title)
                if !practiceList.isEmpty {
                    var isBack = true
                    while isBack {
                        var showPracticeList: [String] = []
                        await tui.LoadingSpinner(title: "正在加载...", done: "✓ 加载完成", until: {
                            for ques in practiceList {
                                showPracticeList.append("\(transSubject[ques.unit.subject] ?? "无法加载学科") \(unitDic[ques.unit.grade]?[ques.unit.subject]?[ques.unit.unit] ?? "无法加载单元名称") \(ques.isWrong ? "     ! 在错题本中" : "")")
                            }
                        })
                        let select = tui.List(showPracticeList, title: "选择要回顾的题目")
                        if practiceList[select].isWrong {
                            let option = tui.List(["攻击错题！", "返回列表", "回到开始页面"], title: "\(practiceList[select].question) ✕ 在错题本中")
                            switch option {
                            case 0:
                                tui.Text(practiceList[select].question, color: .title)
                                let ans = tui.TextField("订正")
                                var isCorrect = false
                                await tui.LoadingSpinner(title: "正在批改...", done: "批改完成", until: {
                                    isCorrect = await gradeQues(ques: practiceList[select], answer: ans)
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
                                    practiceList[select].userAnswer = ans
                                    practiceStore.save(practiceList)
                                }
                                isBack = false
                            case 1:
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
                    tui.Text("练习册中还没有任何题目。前往开始页面选择“做题”来开始练习。", color: .info)
                }
                tui.Text("按下任意键以回到开始页面...", color: .info)
                tui.waitKey()
            case 2:
                practiceStore.save(practiceList)
                return
            case 3:
                tui.Text("危险！此操作不可撤销。", color: .title)
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

    static func gradeQues(ques: Question, answer: String) async -> Bool {
        if ques.question == "发生未知错误。输入OK以继续。" && answer == "OK" {
            return true
        }
        return await CallGrade(ques: ques.question, userAns: answer)
    }

    static func getQues(subject: Subject, unit: Unit, type: quesType) async -> String {
        let ques = await CallQues(unit: unit, type: type)
        return ques
    }
}