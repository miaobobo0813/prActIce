// getQuestion.swift

import WinSDK
import Foundation
import FoundationNetworking

enum InitIntelligenceError: Error {
    case pythonNotFound
    case unknownError
    case pyError(message: String)
}

func CallQues(unit: Unit, type: quesType) async -> String {
    let errorResult = "发生未知错误。输入OK以继续。"

    var components = URLComponents()
    components.scheme = "http"
    components.host = "127.0.0.1"
    components.port = 8000
    components.path = "/ques"
    components.queryItems = [
        URLQueryItem(name: "grade", value: unit.grade.rawValue),
        URLQueryItem(name: "subject", value: transSubject[unit.subject] ?? String(describing: unit.subject)),
        URLQueryItem(name: "unit", value: findUnitName(unit: unit)),
        URLQueryItem(name: "type", value: type.rawValue)
    ]

    guard let httpURL = components.url else {
        return errorResult
    }

    do {
        let (data, response) = try await URLSession.shared.data(from: httpURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return errorResult
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text
        }
    } catch {
        return errorResult
    }

    return errorResult
}

func CallGrade(ques: String, userAns: String) async -> Bool {
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
        return false
    }

    do {
        let (data, response) = try await URLSession.shared.data(from: httpURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return false
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text.lowercased().contains("true")
        }
    } catch {
        return false
    }

    return false
}

func InitIntelligence() async throws {
    let bundle = Bundle.main
    guard let servicePath = bundle.path(forResource: "modelService", ofType: "py"),
            let modelQuesPath = bundle.path(forResource: "outputQues", ofType: nil),
            let modelGradePath = bundle.path(forResource: "outputGrade", ofType: nil) 
    else {
        throw InitIntelligenceError.unknownError
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
        throw InitIntelligenceError.unknownError
    }
    if whereProcess.terminationStatus != 0 {
        throw InitIntelligenceError.pythonNotFound
    }
    let data = pyPath.fileHandleForReading.readDataToEndOfFile()
    guard let pyPathString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\r\n", maxSplits: 1)[0] else {
        throw InitIntelligenceError.unknownError
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
        throw InitIntelligenceError.unknownError
    }
    if pyProcess.terminationStatus != 0 {
        let errorData = pyError.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8) ?? String(data: errorData, encoding: .isoLatin1) ?? "未知错误。"
        throw InitIntelligenceError.pyError(message: errorMessage)
    }
}

func checkServiceStatus() async throws {
    let healthURL = URL(string: "http://127.0.0.1:8000/test")!
    let deadline = Date().addingTimeInterval(240)

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
 