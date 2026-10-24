import XCTest
@testable import MathCore

final class FactFamilyProblemEngineTests: XCTestCase {
    func testDivisionProblemUsesExactFactFamily() {
        let engine = FactFamilyProblemEngine()

        let problem = engine.divisionProblem(table: 7, factor: 8)

        XCTAssertEqual(problem.prompt, "56 / 7 = ?")
        XCTAssertEqual(problem.result, 8)
        XCTAssertEqual(problem.table, 7)
        XCTAssertEqual(problem.factor, 8)
    }

    func testDivisionDistractorsNeverContainCorrectAnswerOrNonPositiveValues() {
        let engine = FactFamilyProblemEngine()
        let problem = engine.divisionProblem(table: 4, factor: 2)

        let distractors = engine.divisionDistractors(for: problem)

        XCTAssertFalse(distractors.contains(problem.result))
        XCTAssertTrue(distractors.allSatisfy { $0 > 0 })
        XCTAssertEqual(Set(distractors).count, distractors.count)
    }

    func testMultiplicationCanRepresentReversedPromptWithoutChangingResult() {
        let engine = FactFamilyProblemEngine()

        let problem = engine.multiplicationProblem(table: 3, factor: 9, reversed: true)

        XCTAssertEqual(problem.prompt, "9 x 3 = ?")
        XCTAssertEqual(problem.result, 27)
    }
}
