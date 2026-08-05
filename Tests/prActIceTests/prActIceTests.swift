// prActIceTests.swift

import Foundation
import Testing
@testable import prActIce

@Test func parseGradeScoreTextRecognizesFullAndPartialScores() throws {
    let fullScore = parseGradeScoreText("1/1")
    #expect(fullScore?.isFullScore == true)
    #expect(fullScore?.scoreText == "1/1")

    let partialScore = parseGradeScoreText("0/1")
    #expect(partialScore?.isFullScore == false)
    #expect(partialScore?.scoreText == "0/1")
}
