// question.swift

import Foundation

enum Subject: Codable {
    case Chinese
    case Math
    case English
    case Science
    case Social
}

struct Question: Codable, Identifiable {
    var id = UUID()

    var question: String
    var isWrong: Bool
    var userAnswer: String
    var subject: Subject
}
