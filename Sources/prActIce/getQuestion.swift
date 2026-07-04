// getQuestion.swift

import WinSDK
import Foundation
import FoundationNetworking

func callQues(unit: Unit, type: quesType) async -> String{
    let url = "http://127.0.0.1:8000/ques?grade=\(unit.grade.rawValue)&subject=\(unit.subject)&unit=\(findUnitName(unit: unit))&type=\(type.rawValue)"
    let httpURL = URL(string: url)
    print(url)

    do {
        let (data, _) = try await URLSession.shared.data(from: httpURL!)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String], let text=json["text"] {
            return text
        }
    } catch {
        return "error."
    }

    return "error."
}
