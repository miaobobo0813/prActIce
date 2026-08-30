// getQuestion.swift

import WinSDK
import Foundation
import FoundationNetworking

enum InitIntelligenceError: Error, LocalizedError  {
    case pythonNotFound
    case fileNotFound(fileName: String)
    case unknownError
    case pyError(message: String)

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "未找到可用的 Python 解释器。"
        case .fileNotFound(let fileName):
            return "未能找到文件：\(fileName)。"
        case .unknownError:
            return "发生未知错误。"
        case .pyError(let message):
            return message.isEmpty ? "Python 服务启动失败。" : message
        }
    }
}

enum CallError: Error, LocalizedError {
    case invalidURL
    case requestFailed(details: String)
    case invalidResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "服务地址无效。"
        case .requestFailed(let details):
            return details.isEmpty ? "服务请求失败。" : "服务请求失败：\(details)"
        case .invalidResponse:
            return "服务返回了无效响应。"
        case .decodingFailed:
            return "服务响应无法解析。"
        }
    }
}

struct GradeScoreResult: Codable {
    let scoreText: String
    let isFullScore: Bool

    init(scoreText: String, isFullScore: Bool) {
        self.scoreText = scoreText
        self.isFullScore = isFullScore
    }
}

private let modelRequestTimeout: TimeInterval = 30 * 60

private let modelURLSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = modelRequestTimeout
    config.timeoutIntervalForResource = modelRequestTimeout
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: config)
}()

func parseGradeScoreText(_ text: String) -> GradeScoreResult? {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let pattern = #"(?<!\d)(\d+)\s*/\s*(\d+)(?!\d)"#

    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: trimmedText, range: NSRange(trimmedText.startIndex..., in: trimmedText)) {
        let earnedRange = Range(match.range(at: 1), in: trimmedText)
        let totalRange = Range(match.range(at: 2), in: trimmedText)
        if let earnedRange, let totalRange,
           let earned = Int(trimmedText[earnedRange]),
           let total = Int(trimmedText[totalRange]) {
            let normalizedScore = "\(earned)/\(total)"
            return GradeScoreResult(scoreText: normalizedScore, isFullScore: earned >= total)
        }
    }

    let normalizedText = trimmedText.lowercased()
    if normalizedText.contains("true") || normalizedText.contains("正确") || normalizedText.contains("对") {
        return GradeScoreResult(scoreText: "1/1", isFullScore: true)
    }
    if normalizedText.contains("false") || normalizedText.contains("错误") || normalizedText.contains("错") {
        return GradeScoreResult(scoreText: "0/1", isFullScore: false)
    }

    return nil
}

private func makeJSONRequest(url: URL, timeoutInterval: TimeInterval) -> URLRequest {
    var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    return request
}

func CallQues(unit: Unit, type: quesType) async throws -> String {
    guard let httpURL = URL(string: "http://127.0.0.1:8000/ques") else {
        throw CallError.invalidURL
    }

    let requestBody: [String: String] = [
        "grade": unit.grade.rawValue,
        "subject": transSubject[unit.subject] ?? String(describing: unit.subject),
        "unit": findUnitName(unit: unit),
        "type": type.rawValue,
        "scope": getScope(unit: unit)
    ]
    var request = makeJSONRequest(url: httpURL, timeoutInterval: modelRequestTimeout)
    request.httpBody = try JSONEncoder().encode(requestBody)

    do {
        let (data, response) = try await modelURLSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CallError.invalidResponse
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text
        }
    } catch let error as URLError where error.code == .timedOut {
        throw CallError.requestFailed(details: "模型生成超时。请稍后或在重启计算机后重试。")
    } catch {
        throw CallError.requestFailed(details: error.localizedDescription)
    }

    throw CallError.decodingFailed
}

func CallGrade(ques: String, userAns: String) async throws -> GradeScoreResult {
    guard let httpURL = URL(string: "http://127.0.0.1:8000/grade") else {
        throw CallError.invalidURL
    }

    let requestBody = ["ques": ques, "userAns": userAns]
    var request = makeJSONRequest(url: httpURL, timeoutInterval: modelRequestTimeout)
    request.httpBody = try JSONEncoder().encode(requestBody)

    do {
        let (data, response) = try await modelURLSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CallError.invalidResponse
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String,
           let scoreResult = parseGradeScoreText(text) {
            return scoreResult
        }
    } catch let error as URLError where error.code == .timedOut {
        throw CallError.requestFailed(details: "评分服务超时，请稍后再试。")
    } catch {
        throw CallError.requestFailed(details: error.localizedDescription)
    }

    throw CallError.decodingFailed
}

func InitIntelligence() async throws {
    let bundle = Bundle.module
    guard let servicePath = bundle.path(forResource: "modelService", ofType: "py")
    else {
        throw InitIntelligenceError.fileNotFound(fileName: "modelService.py")
    }
    guard let modelPath = bundle.path(forResource: "Qwen3.5-2B", ofType: nil)
    else {
        throw InitIntelligenceError.fileNotFound(fileName: "modelService.py")
    }
    guard let sysRoot = ProcessInfo.processInfo.environment["SystemRoot"] else { throw InitIntelligenceError.unknownError }
    let whereProcess = Process()
    whereProcess.executableURL = URL(fileURLWithPath: "\(sysRoot)\\System32\\WindowsPowerShell\\v1.0\\powershell.exe")
    whereProcess.arguments = ["-ExecutionPolicy", "Bypass", "-Command", "(Get-Command python).Source"]
    let pyPath = Pipe()
    whereProcess.standardOutput = pyPath
    whereProcess.standardError = pyPath
    do {
        try whereProcess.run()
        whereProcess.waitUntilExit()
    } catch {
        throw InitIntelligenceError.pythonNotFound
    }
    if whereProcess.terminationStatus != 0 {
        throw InitIntelligenceError.pythonNotFound
    }
    let data = pyPath.fileHandleForReading.readDataToEndOfFile()
    guard let pyPathString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\r\n", maxSplits: 1)[0] else {
        throw InitIntelligenceError.pythonNotFound
    }

    let pyLog = await MainActor.run { ServiceStatus.shared.pyLog }
    let pyProcess = Process()
    pyProcess.executableURL = URL(fileURLWithPath: String(pyPathString))
    pyProcess.arguments = [servicePath, modelPath]
    pyProcess.standardOutput = pyLog
    pyProcess.standardError = pyLog
    do {
        try pyProcess.run()
    } catch {
        throw InitIntelligenceError.pythonNotFound
    }

    if !pyProcess.isRunning {
        let errorData = await MainActor.run { pyLog.fileHandleForReading.readDataToEndOfFile() }
        let errorMessage = String(data: errorData, encoding: .utf8)
            ?? String(data: errorData, encoding: .windowsCP1252)
            ?? String(data: errorData, encoding: .isoLatin1)
            ?? "未知错误。"
        throw InitIntelligenceError.pyError(message: errorMessage)
    }
}

@MainActor
func checkServiceStatus() async throws {
    let healthURL = URL(string: "http://127.0.0.1:8000/test")!
    let deadline = Date().addingTimeInterval(480)

    while Date() < deadline {
        if ServiceStatus.shared.isError {
            return
        }
        print("Check! \(Date())")
        do {
            var request = URLRequest(url: healthURL, timeoutInterval: 8)
            print("Got your Pawn! \(Date())")
            request.httpMethod = "GET"
            let (data, _) = try await URLSession.shared.data(from: healthURL)
            print("And it's your queen! \(Date())")
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Bool]

            if json?["text"] ?? false {
                return
            }
        } catch let error as URLError where error.code == .timedOut {
            try await Task.sleep(nanoseconds: 500_000_000)
            continue
        } catch {
            try await Task.sleep(nanoseconds: 500_000_000)
            continue
        }
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    throw InitIntelligenceError.unknownError
}
 