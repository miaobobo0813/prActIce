// getQuestion.swift

import WinSDK
import Foundation
import FoundationNetworking

enum initIntelligenceError: Error {
    case pythonNotFound
    case unknownError
    case pyError(message: String)
}

func callQues(unit: Unit, type: quesType) async -> String {
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
        return "error."
    }

    do {
        let (data, response) = try await URLSession.shared.data(from: httpURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return "error."
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text
        }
    } catch {
        return "error."
    }

    return "error."
}

func callGrade(ques: String, userAns: String) async -> Bool {
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

func initIntelligence() async throws {
    try await Task.detached {
        let bundle = Bundle.module
        guard let servicePath = bundle.path(forResource: "modelService", ofType: "py"),
              let modelQuesPath = bundle.path(forResource: "outputQues", ofType: nil),
              let modelGradePath = bundle.path(forResource: "outputGrade", ofType: nil) else {
            throw initIntelligenceError.unknownError
        }

        guard let sysRoot = ProcessInfo.processInfo.environment["SystemRoot"] else { throw initIntelligenceError.unknownError }
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
            throw initIntelligenceError.unknownError
        }
        if whereProcess.terminationStatus != 0 {
            throw initIntelligenceError.pythonNotFound
        }
        let data = pyPath.fileHandleForReading.readDataToEndOfFile()
        guard let pyPathString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw initIntelligenceError.unknownError
        }

        let pyProcess = Process()
        pyProcess.executableURL = URL(fileURLWithPath: pyPathString)
        pyProcess.arguments = [servicePath, modelQuesPath, modelGradePath]
        let pyError = Pipe()
        pyProcess.standardOutput = FileHandle.nullDevice
        pyProcess.standardError = pyError
        do {
            try pyProcess.run()
        } catch {
            throw initIntelligenceError.unknownError
        }
    }.value
}

func checkServiceStatus() async throws {
    let healthURL = URL(string: "http://127.0.0.1:8000/test")!
    let deadline = Date().addingTimeInterval(180)

    while Date() < deadline {
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

    throw initIntelligenceError.unknownError
}
 