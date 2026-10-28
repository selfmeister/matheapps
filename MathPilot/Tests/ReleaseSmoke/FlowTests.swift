import XCTest
@testable import MathPilotReleaseSmoke

final class ReleaseFlowTests: XCTestCase {
    @MainActor
    func testAllMissionsHaveAvailableAnswersGuidedStepsAndThreeHitBoss() throws {
        for mission in SpecialMissionID.allCases {
            let manager = GameManager()
            manager.setupGame(size: CGSize(width: 390, height: 844))
            manager.configureSound(enabled: false)
            manager.startSpecialMission(mission)
            manager.completeStrategyIntroAndStartMission()
            var rounds = 0
            var bossPrompts = Set<String>()
            while !manager.missionCompleted && rounds < 30 {
                XCTAssertEqual(manager.flyingNumbers.count, 3)
                XCTAssertEqual(Set(manager.flyingNumbers.map(\.value)).count, 3)
                let correct = try XCTUnwrap(manager.flyingNumbers.first { $0.value == manager.correctAnswer })
                let phase = manager.activeSpecialMission?.phase
                if phase == .bossFight {
                    XCTAssertEqual(manager.bossEntity?.definition.maxHP, 3)
                    bossPrompts.insert(manager.currentProblem)
                } else {
                    XCTAssertNil(manager.bossEntity)
                }
                manager.tappedNumber(correct)
                XCTAssertTrue(manager.missionFeedbackVisible)
                XCTAssertFalse(manager.missionStrategyHint?.isEmpty ?? true)
                let attempts = manager.currentSessionAttempts
                manager.tappedNumber(correct)
                XCTAssertEqual(manager.currentSessionAttempts, attempts)
                XCTAssertEqual(manager.activeSpecialMission?.phase, phase, "Phase must wait for feedback")
                manager.continueMission()
                rounds += 1
            }
            XCTAssertTrue(manager.missionCompleted, "Mission failed to finish: \(mission)")
            XCTAssertEqual(rounds, 16, "14 final answers and two guided steps")
            XCTAssertEqual(bossPrompts.count, 3)
            XCTAssertEqual(manager.bossEntity?.currentHP, 0)
            XCTAssertLessThan(manager.specialMissionProgress[mission]?.averageResponseTimeMs ?? 99999, 1000)
            manager.resetGame()
        }
    }

    @MainActor
    func testMissionErrorRequiresGuidedRetryAndDoesNotAdvanceOrDamageBoss() throws {
        let manager = GameManager()
        manager.setupGame(size: CGSize(width: 390, height: 844))
        manager.configureSound(enabled: false)
        manager.startSpecialMission(.bridgingThrough10)
        manager.completeStrategyIntroAndStartMission()
        let wrong = try XCTUnwrap(manager.flyingNumbers.first { $0.value != manager.correctAnswer })
        manager.tappedNumber(wrong)
        XCTAssertEqual(manager.missionPhaseCorrect, 0)
        manager.continueMission()
        XCTAssertTrue(manager.currentProblem.contains("+ ? = 10"))
        manager.tappedNumber(try XCTUnwrap(manager.flyingNumbers.first { $0.value == manager.correctAnswer }))
        manager.continueMission()
        XCTAssertEqual(manager.currentProblem, "10 + 3 = ?")
        manager.tappedNumber(try XCTUnwrap(manager.flyingNumbers.first { $0.value == manager.correctAnswer }))
        XCTAssertEqual(manager.missionPhaseCorrect, 0, "Supported corrections aren't independent successes")
        manager.continueMission()
        XCTAssertEqual(manager.activeSpecialMission?.phase, .discoverPattern)
        manager.resetGame()
        manager.continueMission()
        XCTAssertFalse(manager.gameStarted)
        XCTAssertTrue(manager.flyingNumbers.isEmpty)
    }

    @MainActor
    func testBossMistakeAndBackgroundTime() async throws {
        let manager = GameManager()
        manager.setupGame(size: CGSize(width: 390, height: 844))
        manager.configureSound(enabled: false)
        manager.startSpecialMission(.bridgingThrough10)
        manager.completeStrategyIntroAndStartMission()
        manager.pauseForAppBackground()
        try await Task.sleep(nanoseconds: 1_100_000_000)
        manager.pauseForAppBackground() // inactive -> background must preserve the original pause time
        manager.resumeFromAppBackground()
        manager.tappedNumber(try XCTUnwrap(manager.flyingNumbers.first { $0.value == manager.correctAnswer }))
        XCTAssertLessThan(try XCTUnwrap(manager.analyticsRecords.last).responseTimeMs, 500)
        manager.continueMission()
        for _ in 0..<20 {
            if manager.activeSpecialMission?.phase == .bossFight { break }
            manager.tappedNumber(try XCTUnwrap(manager.flyingNumbers.first { $0.value == manager.correctAnswer }))
            manager.continueMission()
        }
        XCTAssertEqual(manager.bossEntity?.currentHP, 3)
        manager.tappedNumber(try XCTUnwrap(manager.flyingNumbers.first { $0.value != manager.correctAnswer }))
        XCTAssertEqual(manager.bossEntity?.currentHP, 3)
        manager.continueMission()
        // The first boss transfer problem is an ordinary fact: it retries directly.
        manager.tappedNumber(try XCTUnwrap(manager.flyingNumbers.first { $0.value == manager.correctAnswer }))
        manager.continueMission()
        XCTAssertEqual(manager.bossEntity?.currentHP, 3)
        manager.setupGame(size: CGSize(width: 844, height: 390))
        XCTAssertEqual(manager.flyingNumbers.count, 3)
        XCTAssertTrue(manager.flyingNumbers.allSatisfy { $0.position.x < 844 && $0.position.y < 390 })
        manager.tappedNumber(try XCTUnwrap(manager.flyingNumbers.first { $0.value == manager.correctAnswer }))
        XCTAssertEqual(manager.bossEntity?.currentHP, 2)
        manager.resetGame()
        try await Task.sleep(nanoseconds: 2_600_000_000)
        XCTAssertNil(manager.activeSpecialMission)
        XCTAssertTrue(manager.flyingNumbers.isEmpty)
        XCTAssertFalse(manager.missionFeedbackVisible)
    }

    @MainActor
    func testFiveProblemPracticeRetriesCompletionAndPersistence() async throws {
        for mode in GameMode.allCases {
            UserDefaults.standard.removeObject(forKey: "analyticsRecords")
            let manager = GameManager()
            manager.setupGame(size: CGSize(width: 390, height: 844))
            let prompt: String
            let answer: Int
            let stage: DifficultyStage
            switch mode {
            case .addition: (prompt, answer, stage) = ("8 + 5 = ?", 13, .crossing10)
            case .subtraction: (prompt, answer, stage) = ("14 - 6 = ?", 8, .crossing10)
            case .multiplication: (prompt, answer, stage) = ("4 × 3 = ?", 12, .multiplicationTable)
            case .division: (prompt, answer, stage) = ("24 ÷ 6 = ?", 4, .multiplicationTable)
            }
            let seed = AnalyticsRecord(timestamp: Date(), mode: mode, stage: stage,
                patternPhase: nil, problem: prompt, correctAnswer: answer, chosenAnswer: -1,
                isCorrect: false, wasRetry: false, responseTimeMs: 2000)
            manager.startFeedbackPractice(from: seed)
            XCTAssertEqual(manager.currentProblem, prompt)
            XCTAssertEqual(manager.feedbackPracticeProgress?.total, 5)
            let wrong = FlyingNumber(id: UUID(), value: answer + 1, position: CGPoint(x: 180, y: 400), isCorrect: false, speed: 0, lane: 0)
            manager.flyingNumbers.append(wrong)
            manager.tappedNumber(wrong)
            try await Task.sleep(nanoseconds: 1_800_000_000)
            XCTAssertFalse(manager.gameOver)
            XCTAssertEqual(manager.remainingLives, GameManager.maximumLives)
            var prompts = Set<String>()
            for index in 1...5 {
                XCTAssertEqual(manager.feedbackPracticeProgress?.current, index)
                prompts.insert(manager.currentProblem)
                manager.flyingNumbers.removeAll()
                let correct = FlyingNumber(id: UUID(), value: manager.correctAnswer, position: CGPoint(x: 180, y: 400), isCorrect: true, speed: 0, lane: 0)
                manager.flyingNumbers.append(correct)
                manager.tappedNumber(correct)
                // Duplicate taps while the successful shot is travelling must not advance twice.
                manager.tappedNumber(correct)
                for _ in 0..<50 {
                    if manager.gameOver || manager.feedbackPracticeProgress?.current != index { break }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                if index < 5 { XCTAssertFalse(manager.gameOver) }
            }
            XCTAssertTrue(manager.gameOver)
            XCTAssertEqual(manager.feedbackPracticeResult?.problemCount, 5)
            XCTAssertEqual(manager.feedbackPracticeResult?.firstTryCorrect, 4)
            XCTAssertEqual(manager.feedbackPracticeResult?.awardedPoints, 100)
            XCTAssertGreaterThan(prompts.count, 1)
            XCTAssertEqual(manager.analyticsRecords.filter { !$0.wasRetry }.count, 5)
            XCTAssertEqual(manager.analyticsRecords.filter(\.wasRetry).count, 1)
            manager.resetGame()
            let restored = GameManager()
            XCTAssertEqual(restored.analyticsRecords.count, 6)
            XCTAssertEqual(restored.analyticsStageSummaries(in: .english).first?.correctFirstAttempts, 4)
            manager.startFeedbackPractice(from: seed)
            XCTAssertEqual(manager.feedbackPracticeProgress?.current, 1)
            XCTAssertNil(manager.feedbackPracticeResult)
            manager.resetGame()
        }
    }
}
