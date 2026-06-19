// question.swift

import Foundation

enum Subject: Codable {
    case Chinese
    case Math
    case English
    case Science
    case History
    case EthicsAndTheRuleOfLaw
    case Geography
}

enum Grade: Codable {
    case A7
    case B7
    case A8
    case B8
}

enum quesType: Codable {
    case choose
    case fillBlank
    case answer
}

struct Unit: Codable {
    let grade: Grade
    let subject: Subject
    let unit: Int
    public init(grade: Grade, subject: Subject, unit: Int){
        self.grade = grade
        self.subject = subject
        self.unit = unit
    }
    

    public static let A7U1CH = Unit(grade: .A7, subject: .Chinese, unit: 1)
    
}

struct Question: Codable, Identifiable {
    var id = UUID()

    var question: String
    var isWrong: Bool
    var userAnswer: String
    var unit: Unit
}

let unitDic: [Grade: [Subject: [Int: String]]] = [
    .A7: [
        .Chinese: [
            1: "第一单元", 
            2: "第二单元", 
            3: "第三单元", 
            4: "第四单元", 
            5: "第五单元", 
            6: "第六单元"
        ], 
        .Math: [
            1: "第1章 有理数", 
            2: "第2章 有理数的运算", 
            3: "第3章 实数", 
            4: "第4章 代数式", 
            5: "第5章 一元一次方程", 
            6: "第6章 图形的初步知识"
        ], 
        .English: [
            1: "Starter Welcome to junior high!", 
            2: "Unit 1 A new start", 
            3: "Unit 2 More than fun", 
            4: "Unit 3 Family ties", 
            5: "Unit 4 Time to celebrate", 
            6: "Unit 5 The power of plants", 
            7: "Unit 6 Fantastic friends"
        ]
    ], 
    .B7: [

    ], 
    .A8: [

    ], 
    .B8: [

    ]
]