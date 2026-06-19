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
        ], 
        .Science: [
            1: "第1章 探索自然的科学", 
            2: "第2章 科学并不神秘", 
            3: "第3章 广袤浩瀚的宇宙", 
            4: "第4章 多种多样的运动", 
            5: "第5章 探索技术与工程的世界"
        ], 
        .History: [
            1: "第一单元 史前时期：原始社会与中华文明的起源", 
            2: "第二单元 夏商周时期：奴隶制王朝的更替和向封建社会的过渡", 
            3: "第三单元 秦汉时期：统一多民族封建国家的建立和巩固", 
            4: "第四单元 三国两晋南北朝时期：政权分立与民族交融"
        ], 
        .EthicsAndTheRuleOfLaw: [
            1: "第一单元 少年有梦", 
            2: "第二单元 成长的时空", 
            3: "第三单元 珍爱我们的生命", 
            4: "第四单元 追求美好人生"
        ], 
        .Geography: [
            1: "第一章 地球", 
            2: "第二章 地图", 
            3: "第三章 陆地和海洋", 
            4: "第四章 天气与气候", 
            5: "第五章 居民与文化", 
            6: "第六章 发展与合作"
        ]
    ], 
    .B7: [
        .Chinese: [
            1: "第一单元", 
            2: "第二单元", 
            3: "第三单元", 
            4: "第四单元", 
            5: "第五单元", 
            6: "第六单元"
        ], 
        .Math: [
            1: "第1章 相交线与平行线", 
            2: "第2章 二元一次方程组", 
            3: "第3章 整式的乘除", 
            4: "第4章 因式分解", 
            5: "第5章 分式", 
            6: "第6章 数据与统计图表"
        ], 
        .English: [
            1: "Unit 1 The secrets of happiness", 
            2: "Unit 2 Go for it!", 
            3: "Unit 3 Food matters", 
            4: "Unit 4 The art of having fun", 
            5: "Unit 5 Amazing nature", 
            6: "Unit 6 Hitting the road"
        ], 
        .Science: [
            1: "第1章 生物的结构与生殖", 
            2: "第2章 物质的微观结构", 
            3: "第3章 物质的特性", 
            4: "第4章 我们生活的大地", 
            5: "第5章 制造技术与工程"
        ], 
        .History: [
            1: "第一单元 隋唐时期：繁荣与开放的时代", 
            2: "第二单元 辽宋夏金元时期：民族关系发展与社会变化", 
            3: "第三单元 明清时期(至鸦片战争前)：统一多民族封建国家的巩固与发展"
        ], 
        .EthicsAndTheRuleOfLaw: [
            1: "第一单元 珍惜青春时光", 
            2: "第二单元 焕发青春活力", 
            3: "第三单元 传承中华优秀传统文化", 
            4: "第四单元 生活在法治社会"
        ], 
        .Geography: [
            1: "第七章 我们生活的大洲——亚洲", 
            2: "第八章 我们邻近的地区和国家", 
            3: "第九章 东半球其他的地区和国家", 
            4: "第十章 西半球的国家", 
            5: "第十一章 极地地区"
        ]
    ], 
    .A8: [
        .Chinese: [
            1: "第一单元", 
            2: "第二单元", 
            3: "第三单元", 
            4: "第四单元", 
            5: "第五单元", 
            6: "第六单元"
        ], 
        .Math: [
            1: "第1章 三角形", 
            2: "第2章 特殊三角形", 
            3: "第3章 一元一次不等式", 
            4: "第4章 图形与坐标", 
            5: "第5章 一次函数"
        ], 
        .English: [
            1: "Unit 1 This is me", 
            2: "Unit 2 Getting along", 
            3: "Unit 3 Make it happen!", 
            4: "Unit 4 Digital life", 
            5: "Unit 5 Play by the rules?", 
            6: "Unit 6 When disaster strikes"
        ], 
        .Science: [
            1: "第1章 对环境的察觉", 
            2: "第2章 力与空间探索", 
            3: "第3章 电路探秘", 
            4: "第4章 水与人类", 
            5: "第5章 建筑结构与工程"
        ], 
        .History: [
            1: "第一单元 中国开始沦为半殖民地半封建社会", 
            2: "第二单元 早期现代化的初步探索和民族危机加剧", 
            3: "第三单元 资产阶级民主革命与中华民国的建立", 
            4: "第四单元 新民主主义革命的兴起", 
            5: "第五单元 从国共合作到农村革命根据地的建立", 
            6: "第六单元 中华民族的抗日战争", 
            7: "第七单元 人民解放战争"
        ], 
        .EthicsAndTheRuleOfLaw: [
            1: "第一单元 走进社会生活", 
            2: "第二单元 维护社会秩序", 
            3: "第三单元 勇担社会责任", 
            4: "第四单元 维护国家利益"
        ], 
        .Geography: [
            1: "第一章 从世界看中国", 
            2: "第二章 中国的自然环境", 
            3: "第三章 中国的自然资源", 
            4: "第四章 中国的经济发展", 
            5: "第五章 建设美丽中国"
        ]
    ], 
    .B8: [
        .Chinese: [
            1: "第一单元", 
            2: "第二单元", 
            3: "第三单元", 
            4: "第四单元", 
            5: "第五单元", 
            6: "第六单元"
        ], 
        .Math: [
            1: "第1章 二次根式", 
            2: "第2章 一元二次方程", 
            3: "第3章 数据分析初步", 
            4: "第4章 平行四边形", 
            5: "第5章 特殊平行四边形"
        ], 
        .English: [
            1: "Unit 1 Career talks", 
            2: "Unit 2 Growing pains and gains", 
            3: "Unit 3 What makes a great team?", 
            4: "Unit 4 Helping out", 
            5: "Unit 5 Looking into nature", 
            6: "Unit 6 Living with nature"
        ], 
        .Science: [
            1: "第1章 我们呼吸的空气", 
            2: "第2章 大气与气候变化", 
            3: "第3章 电磁及其应用", 
            4: "第4章 人体的系统", 
            5: "第5章 控制系统与工程"
        ], 
        .History: [
            1: "第一单元 中华人民共和国成立和社会主义制度建设", 
            2: "第二单元 社会主义建设道路的探索", 
            3: "第三单元 改革开放与中国特色社会主义的开创", 
            4: "第四单元 中国特色社会主义迈向21世纪", 
            5: "第五单元 在新形势下坚持和发展中国特色社会主义", 
            6: "第六单元 中国特色社会主义进入新时代", 
            7: "第七单元 全面建设社会主义现代化国家"
        ], 
        .EthicsAndTheRuleOfLaw: [
            1: "第一单元 坚持宪法至上", 
            2: "第二单元 理解权利义务", 
            3: "第三单元 认识国家制度", 
            4: "第四单元 走近国家机构"
        ], 
        .Geography: [
            1: "第六章 中国的地理差异", 
            2: "第七章 北方地区", 
            3: "第八章 南方地区", 
            4: "第九章 西北地区", 
            5: "第十章 青藏地区", 
            6: "第十一章 奋进中的中国"
        ]
    ]
]