// question.swift

import Foundation

enum subject: Codable {
    case Chinese
    case Math
    case English
    case Science
    case Social
}

struct question: Codable, Identifiable {
    var id = UUID()

    var question: String
    var correctAnswer: String
    var userAnswer: String
    var subject: subject

    func isWrong() -> Bool {
        return !(self.correctAnswer == self.userAnswer)
    }
}
