// getQuestion.swift

import WinSDK
import Foundation
import FoundationNetworking

enum InitIntelligenceError: Error {
    case pythonNotFound
    case fileNotFound(fileName: String)
    case unknownError
    case pyError(message: String)
}

enum CallError: Error {
    case invalidURL
    case requestFailed
    case invalidResponse
    case decodingFailed
}

struct GradeScoreResult: Codable {
    let scoreText: String
    let isFullScore: Bool

    init(scoreText: String, isFullScore: Bool) {
        self.scoreText = scoreText
        self.isFullScore = isFullScore
    }
}

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

    let lowercasedText = trimmedText.lowercased()
    if lowercasedText.contains("true") {
        return GradeScoreResult(scoreText: "1/1", isFullScore: true)
    }
    if lowercasedText.contains("false") {
        return GradeScoreResult(scoreText: "0/1", isFullScore: false)
    }

    return nil
}

func CallQues(unit: Unit, type: quesType) async throws -> String {
    var components = URLComponents()
    components.scheme = "http"
    components.host = "127.0.0.1"
    components.port = 8000
    components.path = "/ques"
    components.queryItems = [
        URLQueryItem(name: "grade", value: unit.grade.rawValue),
        URLQueryItem(name: "subject", value: transSubject[unit.subject] ?? String(describing: unit.subject)),
        URLQueryItem(name: "unit", value: findUnitName(unit: unit)),
        URLQueryItem(name: "type", value: type.rawValue), 
        URLQueryItem(name: "scope", value: getScope(unit: unit))
    ]

    guard let httpURL = components.url else {
        throw CallError.invalidURL
    }

    do {
        let (data, response) = try await URLSession.shared.data(from: httpURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CallError.invalidResponse
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text
        }
    } catch {
        throw CallError.requestFailed
    }

    throw CallError.decodingFailed
}

func CallGrade(ques: String, userAns: String) async throws -> GradeScoreResult {
    var components = URLComponents()
    components.scheme = "http"
    components.host = "127.0.0.1"
    components.port = 8000
    components.path = "/grade"
    components.queryItems = [
        URLQueryItem(name: "ques", value: ques),
        URLQueryItem(name: "userAns", value: userAns)
    ]

    guard let httpURL = components.url else {
        throw CallError.invalidURL
    }

    do {
        let (data, response) = try await URLSession.shared.data(from: httpURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CallError.invalidResponse
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String,
           let scoreResult = parseGradeScoreText(text) {
            return scoreResult
        }
    } catch {
        throw CallError.requestFailed
    }

    throw CallError.decodingFailed
}

func InitIntelligence() async throws {
    let bundle = Bundle.module
    guard let servicePath = bundle.path(forResource: "modelService", ofType: "py")
    else {
        throw InitIntelligenceError.fileNotFound(fileName: "modelService.py")
    }
    guard let modelQuesPath = bundle.path(forResource: "outputQues", ofType: nil)
    else {
        throw InitIntelligenceError.fileNotFound(fileName: "outputQues")
    }
    guard let modelGradePath = bundle.path(forResource: "outputGrade", ofType: nil)
    else {
        throw InitIntelligenceError.fileNotFound(fileName: "outputGrade")
    }

    guard let sysRoot = ProcessInfo.processInfo.environment["SystemRoot"] else { throw InitIntelligenceError.unknownError }
    let whereProcess = Process()
    whereProcess.executableURL = URL(fileURLWithPath: "\(sysRoot)\\System32\\where.exe")
    whereProcess.arguments = ["python"]
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

    let pyProcess = Process()
    pyProcess.executableURL = URL(fileURLWithPath: String(pyPathString))
    pyProcess.arguments = [servicePath, modelQuesPath, modelGradePath]
    let pyError = Pipe()
    pyProcess.standardOutput = pyError
    pyProcess.standardError = pyError
    do {
        try pyProcess.run()
        pyProcess.waitUntilExit()
    } catch {
        throw InitIntelligenceError.pythonNotFound
    }
    if pyProcess.terminationStatus != 0 {
        let errorData = pyError.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8) ?? String(data: errorData, encoding: .isoLatin1) ?? "未知错误。"
        throw InitIntelligenceError.pyError(message: errorMessage)
    }
}

func checkServiceStatus() async throws {
    let healthURL = URL(string: "http://127.0.0.1:8000/test")!
    let deadline = Date().addingTimeInterval(360)

    while Date() < deadline {
        if await ServiceStatus.shared.isError {
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: healthURL)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                try await Task.sleep(nanoseconds: 500_000_000)
                continue
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Bool], json["text"] == true {
                return
            }
        } catch {
            try await Task.sleep(nanoseconds: 500_000_000)
            continue
        }
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    throw InitIntelligenceError.unknownError
}
 