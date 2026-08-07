// prActIce.swift

import Foundation
import WinSDK
import Observation

@Observable @MainActor
final class ServiceStatus {
    static let shared = ServiceStatus()
    var isError: Bool = false
    var errorMessage: String = ""
}

@main
struct prActIce {
    static func main() async {
        let practiceStore = Persistance<[Question]>(filename: "practice.json")
        var practiceList: [Question] = practiceStore.read() ?? []
        let tui = SwiftTUI.shared
        await tui.LoadingSpinner(title: "正在加载QGIntelligence...这可能花费数分钟...", done: "QGIntelligence加载完成。", until: {
            Task.detached(priority: .background) {
                do {
                    try await InitIntelligence()
                } catch InitIntelligenceError.pythonNotFound {
                    await MainActor.run {
                        ServiceStatus.shared.isError = true
                        ServiceStatus.shared.errorMessage = "未能找到Python。请确保已安装Python，并添加到系统PATH中。"
                    }
                } catch InitIntelligenceError.unknownError {
                    await MainActor.run {
                        ServiceStatus.shared.isError = true
                        ServiceStatus.shared.errorMessage = "发生未知错误。请检查网络连接或稍后重试。"
                    }
                } catch InitIntelligenceError.pyError(let message) {
                    await MainActor.run {
                        ServiceStatus.shared.isError = true
                        ServiceStatus.shared.errorMessage = "QGIntelligence服务启动失败。\(message)\n这可能是因为网络引起的问题。"
                    }
                } catch InitIntelligenceError.fileNotFound(let fileName) {
                    await MainActor.run {
                        ServiceStatus.shared.isError = true
                        ServiceStatus.shared.errorMessage = "未能找到文件：\(fileName)。重新安装prActIce可能会解决此问题。"
                    }
                } catch {
                    await MainActor.run {
                        ServiceStatus.shared.isError = true
                        ServiceStatus.shared.errorMessage = "发生未知错误：\(error.localizedDescription)"
                    }
                }
            }
            do {
                try await checkServiceStatus()
            } catch {
                ServiceStatus.shared.isError = true
                ServiceStatus.shared.errorMessage = "QGIntelligence服务未能启动。"
                return
            }
        }, doneColor: .info)

        if ServiceStatus.shared.isError {
            tui.Text(ServiceStatus.shared.errorMessage, color: .error)
            return
        }
        
        while true {
            let options = ["做题", "回顾", "退出(你可能需要再手动关闭窗口)", "清空练习册并退出(危险)"]
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
                    var isError = false, errorMessage = ""
                    await tui.LoadingSpinner(title: "正在生成(\(i)/\(sum))...", done: "✓ 生成完成(\(i)/\(sum))", until: {
                        do {
                            ques = try await getQues(subject: sub, unit: Unit(grade: grade, subject: sub, unit: unit+1), type: type)
                        } catch CallError.requestFailed {
                            isError = true
                            errorMessage = "服务请求失败。请稍后重试。"
                        } catch CallError.invalidURL {
                            isError = true
                            errorMessage = "无法配置URL。"
                        } catch CallError.invalidResponse {
                            isError = true
                            errorMessage = "无效的响应。"
                        } catch CallError.decodingFailed {
                            isError = true
                            errorMessage = "解码失败。这可能是因为QGIntelligence胡言乱语。"
                        } catch {
                            isError = true
                            errorMessage = "未知错误：\(error.localizedDescription)"
                        }
                        return
                    })
                    if isError {
                        tui.Text("由于发生未知错误，请稍后重试。详细信息：\(errorMessage)", color: .error)
                        continue
                    }
                    tui.Text("题目：\(ques)")
                    let userAns = tui.TextField("你的答案")
                    var scoreResult = GradeScoreResult(scoreText: "0/1", isFullScore: false)
                    await tui.LoadingSpinner(title: "正在批改...", done: "批改完成", until: {
                        do {
                            scoreResult = try await gradeQues(ques: ques, answer: userAns)
                        } catch CallError.requestFailed {
                            isError = true
                            errorMessage = "服务请求失败。请稍后重试。"
                        } catch CallError.invalidURL {
                            isError = true
                            errorMessage = "无法配置URL。"
                        } catch CallError.invalidResponse {
                            isError = true
                            errorMessage = "无效的响应。"
                        } catch CallError.decodingFailed {
                            isError = true
                            errorMessage = "解码失败。这可能是因为QGIntelligence胡言乱语。"
                        } catch {
                            isError = true
                            errorMessage = "未知错误：\(error.localizedDescription)"
                        }
                        return
                    }, doneColor: .info)
                    if isError {
                        tui.Text("由于发生未知错误，请稍后重试。详细信息：\(errorMessage)", color: .error)
                        continue
                    }
                    let questionQues = Question(question: ques, isWrong: !scoreResult.isFullScore, userAnswer: userAns, unit: Unit(grade: grade, subject: sub, unit: unit+1), type: type)
                    if scoreResult.isFullScore {
                        tui.Text("✓ 正确（\(scoreResult.scoreText)）", color: .success)
                    } else {
                        tui.Text("✕ 错误（\(scoreResult.scoreText)）", color: .error, nextLine: false)
                        tui.Text("已加入错题本！", color: .info)
                    }
                    if questionQues.question == "发生未知错误。输入OK以继续。" {
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
                            let option = tui.List(["攻击错题！", "这超纲了啊……", "返回列表", "回到开始页面"], title: "\(practiceList[select].question) ✕ 在错题本中")
                            switch option {
                            case 0:
                                tui.Text(practiceList[select].question, color: .title)
                                let ans = tui.TextField("订正")
                                var scoreResult = GradeScoreResult(scoreText: "0/1", isFullScore: false)
                                var isError = false, errorMessage = ""
                                await tui.LoadingSpinner(title: "正在批改...", done: "批改完成", until: {
                                    do {
                                        scoreResult = try await gradeQues(ques: practiceList[select].question, answer: ans)
                                    } catch CallError.requestFailed {
                                        isError = true
                                        errorMessage = "服务请求失败。请稍后重试。"
                                    } catch CallError.invalidURL {
                                        isError = true
                                        errorMessage = "无法配置URL。"
                                    } catch CallError.invalidResponse {
                                        isError = true
                                        errorMessage = "无效的响应。"
                                    } catch CallError.decodingFailed {
                                        isError = true
                                        errorMessage = "解码失败。这可能是因为QGIntelligence胡言乱语。"
                                    } catch {
                                        isError = true
                                        errorMessage = "未知错误：\(error.localizedDescription)"
                                    }
                                    return
                                }, doneColor: .info)
                                if isError {
                                    tui.Text("由于发生未知错误，请稍后重试。详细信息：\(errorMessage)", color: .error)
                                    break
                                }
                                if scoreResult.isFullScore {
                                    tui.Text("✓ 正确（\(scoreResult.scoreText)）", color: .success)
                                    tui.Text("错题被击败", color: .info)
                                    practiceList[select].isWrong = false
                                    practiceStore.save(practiceList)
                                } else {
                                    tui.Text("✕ 错误（\(scoreResult.scoreText)）", color: .error)
                                    tui.Text("攻击失败", color: .info)
                                    practiceList[select].userAnswer = ans
                                    practiceStore.save(practiceList)
                                }
                                isBack = false
                            case 1:
                                tui.Text("完整输入下方文字以将这题移出练习册。", color: .title)
                                let agree = "Yes, this question is too difficult to me."
                                tui.Text(agree, color: .error)
                                let check = tui.TextField("输入")
                                if (check == agree){
                                    practiceList.remove(at: select)
                                    practiceStore.save(practiceList)
                                    tui.Text("成功将这题移出练习册。", color: .success)
                                } else {
                                    tui.Text("输入有偏差。不会移出练习册。", color: .error)
                                }
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

    static func gradeQues(ques: String, answer: String) async throws -> GradeScoreResult {
        do {
            return try await CallGrade(ques: ques, userAns: answer)
        } catch {
            throw error
        }
    }

    static func getQues(subject: Subject, unit: Unit, type: quesType) async throws -> String {
        do {
            return try await CallQues(unit: unit, type: type)
        } catch {
            throw error
        }
    }
}