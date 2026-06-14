// question.swift

import Foundation

struct question: Codable, Identifiable {
    var id = UUID()

    var question: String
    var correctAnswer: String
    var userAnswer: String
}
