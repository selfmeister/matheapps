import SwiftUI
import Foundation

class GameManager: ObservableObject {
    static let maximumLives = 8
    static let missileWidth: CGFloat = 103
    static let missileHeight: CGFloat = 131
    private static let highScoreKey = "highScore"
    private static let analyticsRecordsKey = "analyticsRecords"
    private static let multiplicationProgressKey = "multiplicationProgress"
    private static let divisionProgressKey = "divisionProgress"
    private static let adaptiveLearningProgressKey = "adaptiveLearningProgress"
    private static let specialMissionProgressKey = "specialMissionProgress"
    private let maximumFlyingNumbers = 6
    private let singleDigitProblemDuration: TimeInterval = 30
    private let baseProblemDuration: TimeInterval = 60
    private let baseMinimumCorrectVisibility: TimeInterval = 60
    private let twoDigitTimeMultiplier: TimeInterval = 1.3
    private let retrySpawnDelay: TimeInterval = 3
    private let laneCount = 3
    private let spawnClearanceHeightMultiplier: CGFloat = 1.45

    @Published var score = 0 {
        didSet {
            updateHighScoreIfNeeded()
        }
    }
    @Published var level = 1
    @Published var highScore = UserDefaults.standard.integer(forKey: highScoreKey)
    @Published var analyticsRecords: [AnalyticsRecord] = AnalyticsRecord.loadStored(
        forKey: analyticsRecordsKey
    )
    @Published var multiplicationProgress: MultiplicationProgress = MultiplicationProgress.loadStored(
        forKey: multiplicationProgressKey
    )
    @Published var divisionProgress: MultiplicationProgress = MultiplicationProgress.loadStored(
        forKey: divisionProgressKey
    )
    @Published private var adaptiveLearningProgress: AdaptiveLearningProgress = AdaptiveLearningProgress.loadStored(
        forKey: adaptiveLearningProgressKey
    )
    @Published var remainingLives = maximumLives
    @Published var gameStarted = false
    @Published var gameOver = false
    @Published var missionCompleted = false
    @Published var currentProblem = ""
    @Published var correctAnswer = 0
    @Published var currentSessionAttempts = 0
    @Published var currentSessionCorrectAnswers = 0
    @Published var gameMode: GameMode = .addition
    @Published var vehicleType: VehicleType = AppBrand.defaultVehicle
    @Published var flyingNumbers: [FlyingNumber] = []
    @Published var explosions: [Explosion] = []
    @Published var projectiles: [Projectile] = []
    @Published var activeCelebration: CelebrationEvent?
    @Published var activeSpecialMission: SpecialMissionSession?
    @Published var strategyIntroMission: SpecialMissionID?
    @Published var missionStrategyHint: String?
    @Published var recommendedMission: SpecialMissionID?
    @Published var feedbackPracticeResult: FeedbackPracticeResult?
    @Published var bossEntity: BossEntity?
    @Published var bossFightState: BossFightState = .inactive
    @Published var specialMissionProgress: [SpecialMissionID: SpecialMissionProgress] = SpecialMissionProgress.loadStored(
        forKey: specialMissionProgressKey
    )
    
    private var screenSize: CGSize = .zero
    private var problemTimer: Timer?
    private var numberSpawnTimer: Timer?
    private var animationTimer: Timer?
    private var soundManager: SoundManager?
    private var soundEnabled = true
    private var bossShootingEnabled = true
    private var gameStartDate: Date?
    private var reservedTopAreaHeight: CGFloat = 0
    private var pendingCorrectSpawn = false
    private var earliestCorrectSpawnDate = Date()
    private var nextSpawnAllowedDate = Date()
    private var laneSpeeds: [Double] = [0.48, 0.54, 0.60]
    private var lastCorrectLane: Int?
    private var missedCorrectAnswerCount = 0
    private var currentProblemHasAttempt = false
    private var feedbackAnswerInFlight = false
    private var currentProblemPresentedAt = Date()
    private var recentProblemPrompts: [String] = []
    private var currentProblemStage: DifficultyStage = .singleDigit
    private var currentTargetStage: DifficultyStage = .singleDigit
    private var currentProblemPatternPhase: PatternPhase?
    private var currentTargetPatternPhase: PatternPhase?
    private var currentAdaptiveClusterKey = ""
    private var difficultProblemSolveCount = 0
    private var isPausedForCelebration = false
    private var isRecoveryPaused = false
    private var celebrationNeedsFreshProblem = true
    private var pendingMultiplicationUnlockTable: Int?
    private var pendingDivisionUnlockTable: Int?
    private var currentArithmeticProblem: ArithmeticProblem?
    private var curriculumSettings: CurriculumSettings = .default
    private var patternPhaseCursor = 0
    private var recoveryResumeWorkItem: DispatchWorkItem?
    private var multiplicationProblemDecks: [String: [MultiplicationFact]] = [:]
    private var divisionProblemDecks: [String: [MultiplicationFact]] = [:]
    private var missionProblemDeck: [SpecialMissionProblem] = []
    private var currentMissionProblem: SpecialMissionProblem?
    @Published private(set) var missionPhaseCorrect = 0
    @Published private(set) var missionFeedbackVisible = false
    private var missionContinuation: (() -> Void)?
    private var missionFeedbackWorkItem: DispatchWorkItem?
    private var missionGuidedStep = false
    private var missionQuestionHadError = false
    private var missionResponseTimes: [Int] = []
    private var missionBackgroundedAt: Date?

    var missionProgressText: String? {
        guard let session = activeSpecialMission else { return nil }
        let german = currentAppLanguage == .german
        let title: String
        switch session.phase {
        case .discoverPattern: title = german ? "Entdecken" : "Discover"
        case .unlockStrategy: title = german ? "Gemeinsam üben" : "Guided practice"
        case .focusedPractice: title = german ? "Üben" : "Practice"
        case .transferChallenge: title = german ? "Anwenden" : "Apply"
        case .bossFight: title = german ? "Boss" : "Boss"
        }
        return "\(title) · \(min(missionPhaseCorrect, session.phase.problemTarget))/\(session.phase.problemTarget)"
    }

    var missionPhaseIndex: Int {
        guard let phase = activeSpecialMission?.phase else { return 0 }
        return [.discoverPattern, .unlockStrategy, .focusedPractice, .transferChallenge, .bossFight]
            .firstIndex(of: phase) ?? 0
    }

    func continueMission() {
        guard missionFeedbackVisible, gameStarted, missionBackgroundedAt == nil else { return }
        missionFeedbackWorkItem?.cancel()
        missionFeedbackWorkItem = nil
        missionFeedbackVisible = false
        let continuation = missionContinuation
        missionContinuation = nil
        continuation?()
    }

    private func missionFeedback(_ text: String, automatic: Bool, next: @escaping () -> Void) {
        flyingNumbers.removeAll()
        missionStrategyHint = text
        missionFeedbackVisible = true
        missionContinuation = next
        if automatic {
            let work = DispatchWorkItem { [weak self] in self?.continueMission() }
            missionFeedbackWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: work)
        }
    }

    private var savedGameModeBeforeMission: GameMode?
    private var activeFeedbackPractice: FeedbackPracticeSession?
    
    func setupGame(size: CGSize, reservedTopArea: CGFloat = 0) {
        self.screenSize = size
        self.reservedTopAreaHeight = reservedTopArea
        if activeSpecialMission != nil {
            for index in flyingNumbers.indices {
                flyingNumbers[index].position = missionChoicePosition(lane: flyingNumbers[index].lane)
            }
        }
        if soundManager == nil {
            self.soundManager = SoundManager()
        }
        self.soundManager?.configure(soundEnabled: soundEnabled)
    }

    func configureSound(enabled: Bool) {
        soundEnabled = enabled
        soundManager?.configure(soundEnabled: enabled)
    }

    func configureBossShooting(enabled: Bool) {
        bossShootingEnabled = enabled

        if !enabled {
            projectiles.removeAll { $0.kind == .enemyShot }
        }
    }

    func pauseForAppBackground() {
        guard gameStarted, !gameOver else { return }
        stopTimers()
        missionFeedbackWorkItem?.cancel()
        missionFeedbackWorkItem = nil
        if activeSpecialMission != nil, missionBackgroundedAt == nil { missionBackgroundedAt = Date() }
        soundManager?.stopAllSounds()
    }

    func resumeFromAppBackground() {
        guard gameStarted, !gameOver, activeCelebration == nil else { return }
        if let pausedAt = missionBackgroundedAt {
            currentProblemPresentedAt = currentProblemPresentedAt.addingTimeInterval(Date().timeIntervalSince(pausedAt))
            missionBackgroundedAt = nil
        }
        if soundEnabled {
            soundManager?.startAmbientSound(for: vehicleType)
        }
        startTimers()
    }

    func setGameMode(_ mode: GameMode) {
        guard !gameStarted else { return }
        gameMode = mode
    }

    func setVehicleType(_ type: VehicleType) {
        guard !gameStarted else { return }
        vehicleType = type
        soundManager?.stopAmbientSound()
    }

    func startSpecialMission(_ mission: SpecialMissionID) {
        guard !gameStarted else { return }
        savedGameModeBeforeMission = gameMode
        activeSpecialMission = SpecialMissionSession(mission: mission, phase: .discoverPattern)
        strategyIntroMission = mission
        missionProblemDeck = []
        missionPhaseCorrect = 0
        missionCompleted = false
        recommendedMission = nil
        bossEntity = nil
        bossFightState = .inactive
        gameMode = mission.defaultGameMode
        missionResponseTimes.removeAll()
        markMissionStarted(mission)
    }

    func completeStrategyIntroAndStartMission() {
        guard activeSpecialMission != nil, strategyIntroMission != nil, !gameStarted else { return }
        strategyIntroMission = nil
        startGame()
    }

    func closeMissionCompletion() {
        missionCompleted = false
        activeSpecialMission = nil
        strategyIntroMission = nil
        bossEntity = nil
        bossFightState = .inactive
        missionStrategyHint = nil
        if let savedGameModeBeforeMission {
            gameMode = savedGameModeBeforeMission
        }
        savedGameModeBeforeMission = nil
        resetGame()
    }

    func applyCurriculumSettings(_ settings: CurriculumSettings) {
        curriculumSettings = settings.normalized
        synchronizeMultiplicationProgress()
        clampAdaptiveStageIndexes()
    }

    func analyticsStageSummaries(in language: AppLanguage) -> [AnalyticsStageSummary] {
        AnalyticsEngine(records: analyticsRecords).stageSummaries(in: language)
    }

    var feedbackPracticeProgress: (current: Int, total: Int)? {
        guard let session = activeFeedbackPractice else { return nil }
        return (session.completed + 1, session.problems.count)
    }

    func startFeedbackPractice(from record: AnalyticsRecord) {
        guard !gameStarted else { return }
        gameMode = record.mode
        activeFeedbackPractice = FeedbackPracticeSession(record: record, problems: makeFeedbackProblems(from: record))
        feedbackPracticeResult = nil
        startGame()
    }
    
    func startGame() {
        gameStarted = true
        gameOver = false
        missionCompleted = false
        score = 0
        level = 1
        remainingLives = Self.maximumLives
        currentSessionAttempts = 0
        currentSessionCorrectAnswers = 0
        flyingNumbers.removeAll()
        explosions.removeAll()
        projectiles.removeAll()
        gameStartDate = Date()
        pendingCorrectSpawn = false
        earliestCorrectSpawnDate = Date()
        nextSpawnAllowedDate = Date()
        laneSpeeds = makeLaneSpeeds()
        lastCorrectLane = nil
        missedCorrectAnswerCount = 0
        currentProblemHasAttempt = false
        recentProblemPrompts.removeAll()
        multiplicationProblemDecks.removeAll()
        divisionProblemDecks.removeAll()
        currentProblemStage = currentDifficultyStage
        currentTargetStage = currentProblemStage
        currentProblemPatternPhase = nil
        currentTargetPatternPhase = nil
        currentAdaptiveClusterKey = ""
        difficultProblemSolveCount = 0
        isPausedForCelebration = false
        isRecoveryPaused = false
        activeCelebration = nil
        celebrationNeedsFreshProblem = true
        pendingMultiplicationUnlockTable = nil
        pendingDivisionUnlockTable = nil
        currentArithmeticProblem = nil
        patternPhaseCursor = 0
        recoveryResumeWorkItem?.cancel()
        recoveryResumeWorkItem = nil
        
        soundManager?.startAmbientSound(for: vehicleType)
        generateNewProblem()
        startTimers()
    }
    
    func resetGame() {
        missionFeedbackWorkItem?.cancel()
        missionFeedbackWorkItem = nil
        missionContinuation = nil
        missionFeedbackVisible = false
        missionBackgroundedAt = nil
        missionResponseTimes.removeAll()
        if let savedGameModeBeforeMission {
            gameMode = savedGameModeBeforeMission
        }
        activeSpecialMission = nil
        strategyIntroMission = nil
        bossEntity = nil
        bossFightState = .inactive
        savedGameModeBeforeMission = nil
        missionProblemDeck.removeAll()
        currentMissionProblem = nil
        missionStrategyHint = nil
        missionPhaseCorrect = 0
        activeFeedbackPractice = nil
        feedbackPracticeResult = nil
        gameStarted = false
        gameOver = false
        missionCompleted = false
        score = 0
        level = 1
        remainingLives = Self.maximumLives
        currentProblem = ""
        correctAnswer = 0
        missionStrategyHint = nil
        currentSessionAttempts = 0
        currentSessionCorrectAnswers = 0
        flyingNumbers.removeAll()
        explosions.removeAll()
        projectiles.removeAll()
        gameStartDate = nil
        pendingCorrectSpawn = false
        earliestCorrectSpawnDate = Date()
        nextSpawnAllowedDate = Date()
        laneSpeeds = makeLaneSpeeds()
        lastCorrectLane = nil
        missedCorrectAnswerCount = 0
        currentProblemHasAttempt = false
        recentProblemPrompts.removeAll()
        divisionProblemDecks.removeAll()
        currentProblemStage = currentDifficultyStage
        currentTargetStage = currentProblemStage
        currentProblemPatternPhase = nil
        currentTargetPatternPhase = nil
        currentAdaptiveClusterKey = ""
        difficultProblemSolveCount = 0
        isPausedForCelebration = false
        isRecoveryPaused = false
        activeCelebration = nil
        celebrationNeedsFreshProblem = true
        pendingMultiplicationUnlockTable = nil
        pendingDivisionUnlockTable = nil
        currentArithmeticProblem = nil
        patternPhaseCursor = 0
        recoveryResumeWorkItem?.cancel()
        recoveryResumeWorkItem = nil
        
        soundManager?.stopAmbientSound()
        stopTimers()
    }

    func resetStatistics() {
        analyticsRecords.removeAll()
        multiplicationProgress = MultiplicationProgress()
        divisionProgress = MultiplicationProgress()
        adaptiveLearningProgress = AdaptiveLearningProgress()
        specialMissionProgress = [:]
        UserDefaults.standard.removeObject(forKey: Self.analyticsRecordsKey)
        UserDefaults.standard.removeObject(forKey: Self.multiplicationProgressKey)
        UserDefaults.standard.removeObject(forKey: Self.divisionProgressKey)
        UserDefaults.standard.removeObject(forKey: Self.adaptiveLearningProgressKey)
        UserDefaults.standard.removeObject(forKey: Self.specialMissionProgressKey)
    }
    
    private func startTimers() {
        stopTimers()
        // Update animations
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            self.updateAnimations()
        }
        
        scheduleProblemTimer()
    }
    
    private func stopTimers() {
        problemTimer?.invalidate()
        numberSpawnTimer?.invalidate()
        animationTimer?.invalidate()
        problemTimer = nil
        numberSpawnTimer = nil
        animationTimer = nil
    }
    
    private func generateNewProblem() {
        if activeFeedbackPractice != nil {
            generateFeedbackPracticeProblem()
            return
        }

        if activeSpecialMission != nil {
            generateNewMissionProblem()
            return
        }

        missedCorrectAnswerCount = 0
        currentProblemHasAttempt = false
        laneSpeeds = makeLaneSpeeds()
        nextSpawnAllowedDate = Date()

        let targetStage = currentDifficultyStage
        currentTargetStage = targetStage
        let selectedProblem = selectNextProblemPresentation(for: targetStage)
        currentProblemStage = selectedProblem.presentedStage
        currentTargetPatternPhase = selectedProblem.targetPatternPhase
        currentProblemPatternPhase = selectedProblem.presentedPatternPhase
        currentAdaptiveClusterKey = selectedProblem.targetClusterKey

        let problem = generateUniqueProblem(
            for: selectedProblem.presentedStage,
            mode: gameMode,
            forcedPatternPhase: selectedProblem.presentedPatternPhase
        )
        currentArithmeticProblem = problem
        correctAnswer = problem.result
        currentProblem = problem.prompt
        currentProblemPresentedAt = Date()
        scheduleProblemTimer()

        removeCurrentCorrectNumber()
        scheduleNextCorrectSpawn()
    }

    private func makeFeedbackProblems(from record: AnalyticsRecord) -> [ArithmeticProblem] {
        var problems: [ArithmeticProblem] = [.custom(prompt: record.problem, result: record.correctAnswer)]
        for _ in 0..<100 where problems.count < 5 {
            let numbers = record.problem.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
            let problem: ArithmeticProblem
            if numbers.count >= 2, record.mode == .multiplication {
                let factor = curriculumSettings.normalizedMultiplicationFactors.randomElement() ?? 2
                problem = makeMultiplicationProblem(table: numbers[0], factor: factor)
            } else if numbers.count >= 2, record.mode == .division {
                let factor = curriculumSettings.normalizedMultiplicationFactors.randomElement() ?? 2
                problem = makeDivisionProblem(table: numbers[1], factor: factor)
            } else {
                problem = generateProblem(for: record.stage, mode: record.mode, forcedPatternPhase: record.patternPhase)
            }
            if !problems.contains(where: { $0.prompt == problem.prompt }) {
                problems.append(problem)
            }
        }
        // Very small skills can have fewer than five distinct problems.
        while problems.count < 5 { problems.append(problems[0]) }
        return problems
    }

    private func generateFeedbackPracticeProblem() {
        guard let session = activeFeedbackPractice else { return }
        feedbackAnswerInFlight = false
        missedCorrectAnswerCount = 0
        currentProblemHasAttempt = false
        laneSpeeds = makeLaneSpeeds()
        nextSpawnAllowedDate = Date()
        gameMode = session.record.mode
        currentProblemStage = session.record.stage
        currentTargetStage = session.record.stage
        currentProblemPatternPhase = session.record.patternPhase
        currentTargetPatternPhase = session.record.patternPhase
        currentAdaptiveClusterKey = "feedback.\(session.record.id.uuidString)"
        let problem = session.problems[session.completed]
        currentArithmeticProblem = problem
        correctAnswer = problem.result
        currentProblem = problem.prompt
        currentProblemPresentedAt = Date()
        // Practice advances only after a correct answer.
        problemTimer?.invalidate()
        removeCurrentCorrectNumber()
        scheduleNextCorrectSpawn()
    }

    private func generateNewMissionProblem() {
        guard let session = activeSpecialMission else { return }
        missionStrategyHint = nil
        missionQuestionHadError = false
        currentProblemHasAttempt = false
        if missionProblemDeck.isEmpty {
            let phase: SpecialMissionPhase = session.phase == .bossFight ? .transferChallenge : session.phase
            var problems = SpecialMissionProblem.makeProblems(for: session.mission, phase: phase)
            // The boss tests later transfer examples, rather than repeating the preceding round.
            if session.phase == .bossFight { problems = Array(problems.suffix(3)) }
            missionProblemDeck = session.phase == .focusedPractice ? problems.shuffled() : problems.reversed()
        }
        guard let problem = missionProblemDeck.popLast() else { return }
        currentMissionProblem = problem
        gameMode = problem.mode
        currentProblemStage = problem.stage
        currentTargetStage = problem.stage
        currentProblemPatternPhase = nil
        currentTargetPatternPhase = nil
        currentAdaptiveClusterKey = "mission.\(session.mission.rawValue).\(session.phase.rawValue)"
        if session.phase == .bossFight, bossEntity == nil {
            startBossFight(for: session.mission)
        }
        presentMissionQuestion(guided: session.phase == .unlockStrategy)
    }

    private func presentMissionQuestion(guided: Bool, finishingGuide: Bool = false) {
        guard let problem = currentMissionProblem, let session = activeSpecialMission else { return }
        let step = guided ? problem.guidedStep(for: session.mission) : nil
        missionGuidedStep = step != nil
        currentProblem = step?.prompt ?? (finishingGuide ? problem.guidedFinish(for: session.mission) : problem.prompt)
        correctAnswer = step?.answer ?? problem.result
        currentArithmeticProblem = .custom(prompt: currentProblem, result: correctAnswer)
        missionStrategyHint = step == nil ? nil : (currentAppLanguage == .german ? "Erst den Hilfsschritt lösen." : "Solve the helping step first.")
        problemTimer?.invalidate()
        pendingCorrectSpawn = false
        flyingNumbers.removeAll()
        projectiles.removeAll()
        // All choices arrive together, away from the HUD and boss. No lane queue or speed tells.
        let distractors = [-10, -3, -2, -1, 1, 2, 3, 10]
            .map { correctAnswer + $0 }.filter { $0 >= 0 }.shuffled().prefix(2)
        let values = ([correctAnswer] + distractors).shuffled()
        flyingNumbers = values.enumerated().map { lane, value in
            FlyingNumber(id: UUID(), value: value,
                position: missionChoicePosition(lane: lane),
                isCorrect: value == correctAnswer, speed: 0, lane: lane)
        }
        // Measure only the interval during which the choices can actually be selected.
        currentProblemPresentedAt = Date()
        if session.phase == .bossFight { bossFightState = .active }
    }

    private func missionChoicePosition(lane: Int) -> CGPoint {
        CGPoint(x: screenSize.width * CGFloat(lane * 2 + 1) / 6,
                y: min(max(reservedTopAreaHeight + 150, screenSize.height * 0.62),
                       screenSize.height - Self.missileHeight / 2 - 20))
    }

    private func answerMission(_ number: FlyingNumber) {
        guard !missionFeedbackVisible, missionBackgroundedAt == nil, let session = activeSpecialMission,
              let problem = currentMissionProblem else { return }
        let correct = number.value == correctAnswer
        let elapsed = max(0, Int(Date().timeIntervalSince(currentProblemPresentedAt) * 1000))
        missionResponseTimes.append(elapsed)
        currentSessionAttempts += 1
        if correct { currentSessionCorrectAnswers += 1 }
        // Helping steps are scaffolding, not independent mastery evidence.
        if !missionGuidedStep {
            if session.phase == .unlockStrategy || missionQuestionHadError { currentProblemHasAttempt = true }
            logAnalyticsEvent(chosenAnswer: number.value, isCorrect: correct, responseTimeMs: elapsed)
        }
        if !correct {
            missionQuestionHadError = true
            if session.phase == .bossFight {
                bossFightState = .blocked
                fireBossShotEffect()
            }
            let explanation = problem.workedSolution(for: session.mission)
            missionFeedback(explanation, automatic: false) { [weak self] in
                self?.presentMissionQuestion(guided: true)
            }
            return
        }
        soundManager?.playExplosionSound()
        projectiles.append(Projectile(id: UUID(), startPosition: aircraftPosition,
            endPosition: session.phase == .bossFight
                ? CGPoint(x: screenSize.width / 2, y: max(150, screenSize.height * 0.26)) : number.position,
            currentPosition: aircraftPosition, progress: 0, speed: 0.11,
            kind: .playerShot, impact: .missionHit))
        if missionGuidedStep {
            missionFeedback(currentProblem.replacingOccurrences(of: "?", with: String(correctAnswer)), automatic: false) { [weak self] in
                self?.presentMissionQuestion(guided: false, finishingGuide: true)
            }
            return
        }
        let earnsProgress = !missionQuestionHadError
        if earnsProgress {
            missionPhaseCorrect += 1
            score += session.phase == .bossFight ? 20 * level : 10 * level
            if session.phase == .bossFight, var boss = bossEntity {
                boss.currentHP = max(0, boss.currentHP - 1)
                boss.animationToken = UUID()
                bossEntity = boss
                bossFightState = boss.currentHP == 0 ? .defeated : .damaged
                explosions.append(Explosion(id: UUID(), position: CGPoint(x: screenSize.width / 2, y: max(150, screenSize.height * 0.26)), scale: boss.currentHP == 0 ? 2.35 : 0.75, opacity: 1))
            }
        }
        let text = problem.workedSolution(for: session.mission) + (missionQuestionHadError
            ? (currentAppLanguage == .german ? "\nGut verbessert! Jetzt eine neue Aufgabe ohne Hilfe." : "\nGood correction! Now try a fresh question independently.") : "")
        missionFeedback(text, automatic: session.phase != .unlockStrategy && !missionQuestionHadError) { [weak self] in
            guard let self else { return }
            if self.missionPhaseCorrect >= session.phase.problemTarget {
                if let phase = session.phase.next {
                    self.activeSpecialMission = SpecialMissionSession(mission: session.mission, phase: phase)
                    self.missionPhaseCorrect = 0
                    self.missionProblemDeck.removeAll()
                } else {
                    self.bossFightState = .reward
                    self.score += 40 * self.level
                    self.completeSpecialMission()
                    return
                }
            }
            self.generateNewMissionProblem()
        }
    }

    private var isBossFightActive: Bool {
        activeSpecialMission?.phase == .bossFight &&
            bossFightState != .inactive &&
            bossFightState != .defeated &&
            bossFightState != .reward
    }

    private func startBossFight(for mission: SpecialMissionID) {
        bossEntity = BossEntity(definition: BossDefinition(vehicleTheme: vehicleType, strategyType: mission, maxHP: 3))
        bossFightState = .active
    }

    private func fireBossShotEffect() {
        guard isBossFightActive, bossShootingEnabled else { return }

        soundManager?.playBossShotSound()

        let bossPosition = CGPoint(
            x: screenSize.width / 2,
            y: max(150, screenSize.height * 0.28)
        )
        let targetPosition = CGPoint(
            x: aircraftPosition.x + CGFloat.random(in: -34...34),
            y: max(80, aircraftPosition.y - 28)
        )

        projectiles.append(
            Projectile(
                id: UUID(),
                startPosition: bossPosition,
                endPosition: targetPosition,
                currentPosition: bossPosition,
                progress: 0,
                speed: 0.055,
                kind: .enemyShot,
                impact: .bossDramaticShot
            )
        )
    }

    private func completeFeedbackPracticeIfNeeded(at position: CGPoint) -> Bool {
        guard var session = activeFeedbackPractice else { return false }

        let basePoints = 10 * level
        let awardedPoints = basePoints * 2
        explosions.append(
            Explosion(
                id: UUID(),
                position: position,
                scale: 0.75,
                opacity: 1.0
            )
        )
        score += awardedPoints
        session.completed += 1
        if !session.currentProblemHadError { session.firstTryCorrect += 1 }
        session.currentProblemHadError = false
        if session.completed < session.problems.count {
            activeFeedbackPractice = session
            flyingNumbers.removeAll()
            projectiles.removeAll()
            generateFeedbackPracticeProblem()
            return true
        }
        feedbackPracticeResult = FeedbackPracticeResult(
            problem: session.record.problem,
            basePoints: basePoints * session.completed,
            awardedPoints: awardedPoints * session.completed,
            firstTryCorrect: session.firstTryCorrect,
            problemCount: session.completed
        )
        activeFeedbackPractice = nil
        gameOver = true
        recommendedMission = nil
        soundManager?.playExplosionSound()
        soundManager?.stopAmbientSound()
        stopTimers()
        flyingNumbers.removeAll()
        projectiles.removeAll()
        return true
    }

    private var currentAppLanguage: AppLanguage {
        AppLanguage.storedMissionLanguage
    }

    private func completeSpecialMission(responseTimeMs: Int = 0) {
        guard let session = activeSpecialMission else { return }

        let elapsedMs = missionResponseTimes.reduce(0, +)
        let attempts = max(currentSessionAttempts, 1)
        let accuracy = Double(currentSessionCorrectAnswers) / Double(attempts)
        var progress = specialMissionProgress[session.mission] ?? SpecialMissionProgress(mission: session.mission)
        progress.missionUnlocked = true
        progress.missionCompleted = true
        progress.attempts += attempts
        progress.completionCount += 1
        progress.lastAccuracy = accuracy
        progress.averageResponseTimeMs = Double(elapsedMs) / Double(attempts)
        progress.recommendedByAnalysis = false
        progress.completionDate = Date()
        progress.rewardUnlocked = true
        progress.rewardId = BossDefinition(vehicleTheme: vehicleType, strategyType: session.mission).defeatRewardId
        specialMissionProgress[session.mission] = progress
        SpecialMissionProgress.store(specialMissionProgress, forKey: Self.specialMissionProgressKey)

        missionCompleted = true
        gameOver = false
        gameStarted = false
        stopTimers()
        soundManager?.stopAmbientSound()
        flyingNumbers.removeAll()
        projectiles.removeAll()
        explosions.removeAll()
        missionStrategyHint = session.mission.localizedUnlockHint(language: currentAppLanguage)
    }

    private func markMissionStarted(_ mission: SpecialMissionID) {
        var progress = specialMissionProgress[mission] ?? SpecialMissionProgress(mission: mission)
        progress.missionUnlocked = true
        progress.attempts += 1
        specialMissionProgress[mission] = progress
        SpecialMissionProgress.store(specialMissionProgress, forKey: Self.specialMissionProgressKey)
    }

    private func generateUniqueProblem(
        for stage: DifficultyStage,
        mode: GameMode,
        forcedPatternPhase: PatternPhase? = nil
    ) -> ArithmeticProblem {
        if mode == .multiplication {
            let problem = nextMultiplicationProblem(for: stage)
            rememberProblem(problem.prompt)
            return problem
        }

        if mode == .division {
            let problem = nextDivisionProblem(for: stage)
            rememberProblem(problem.prompt)
            return problem
        }

        var fallback = generateProblem(for: stage, mode: mode, forcedPatternPhase: forcedPatternPhase)
        
        let maxAttempts = 12
        var attempts = 0
        
        while attempts < maxAttempts {
            let candidate = generateProblem(for: stage, mode: mode, forcedPatternPhase: forcedPatternPhase)
            fallback = candidate
            attempts += 1

            if !recentProblemPrompts.contains(candidate.prompt) {
                rememberProblem(candidate.prompt)
                return candidate
            }
        }
        
        rememberProblem(fallback.prompt)
        return fallback
    }

    private func rememberProblem(_ prompt: String) {
        recentProblemPrompts.append(prompt)
        // For multiplication with small factor pools, track fewer recent problems
        // to avoid exhausting the candidate pool
        let maxTracked: Int
        if gameMode == .multiplication || gameMode == .division {
            maxTracked = max(6, currentFactFamilyCount)
        } else {
            maxTracked = 6
        }
        if recentProblemPrompts.count > maxTracked {
            recentProblemPrompts.removeFirst(recentProblemPrompts.count - maxTracked)
        }
    }

    private func scheduleProblemTimer() {
        problemTimer?.invalidate()
        guard activeFeedbackPractice == nil, activeSpecialMission == nil else { return }
        problemTimer = Timer.scheduledTimer(withTimeInterval: currentProblemDuration, repeats: false) { _ in
            self.generateNewProblem()
        }
    }

    private func clampAdaptiveStageIndexes() {
        adaptiveLearningProgress.clampStageIndex(for: .addition, maximum: arithmeticStagePath.count - 1)
        adaptiveLearningProgress.clampStageIndex(for: .subtraction, maximum: arithmeticStagePath.count - 1)
        persistAdaptiveLearningProgress()
    }

    private func persistAdaptiveLearningProgress() {
        AdaptiveLearningProgress.store(
            adaptiveLearningProgress,
            forKey: Self.adaptiveLearningProgressKey
        )
    }

    private func selectNextProblemPresentation(for targetStage: DifficultyStage) -> SelectedProblemPresentation {
        let targetPatternPhase = targetStage == .pattern ? nextPatternPhase() : nil
        let targetClusterKey = clusterKey(
            mode: gameMode,
            stage: targetStage,
            patternPhase: targetPatternPhase
        )

        guard gameMode != .multiplication,
              gameMode != .division,
              var focus = adaptiveLearningProgress.remediation(for: gameMode),
              focus.isActive else {
            return SelectedProblemPresentation(
                presentedStage: targetStage,
                presentedPatternPhase: targetPatternPhase,
                targetStage: targetStage,
                targetPatternPhase: targetPatternPhase,
                targetClusterKey: targetClusterKey
            )
        }

        let useRemediation = focus.shouldUseNow()
        focus.consumeSlot(useRemediation: useRemediation)
        adaptiveLearningProgress.setRemediation(focus.isActive ? focus : nil, for: gameMode)
        persistAdaptiveLearningProgress()

        return SelectedProblemPresentation(
            presentedStage: useRemediation ? focus.presentedStage : targetStage,
            presentedPatternPhase: useRemediation ? focus.presentedPatternPhase : targetPatternPhase,
            targetStage: targetStage,
            targetPatternPhase: targetPatternPhase,
            targetClusterKey: focus.targetClusterKey
        )
    }

    private func nextPatternPhase(preferred: PatternPhase? = nil) -> PatternPhase {
        if let preferred {
            return preferred
        }

        let sequence: [PatternPhase] = [.tensProgression, .onesProgression, .mixed]
        let phase = sequence[patternPhaseCursor % sequence.count]
        patternPhaseCursor += 1
        return phase
    }

    private func clusterKey(
        mode: GameMode,
        stage: DifficultyStage,
        patternPhase: PatternPhase?
    ) -> String {
        if mode == .multiplication || mode == .division {
            let progress = mode == .division ? divisionProgress : multiplicationProgress
            let table = currentArithmeticProblem?.multiplicationTable ?? progress.currentTable
            return "\(mode.rawValue).\(stage.storageKey).table\(table)"
        }

        if stage == .pattern {
            return "\(mode.rawValue).\(stage.storageKey).\(patternPhase?.storageKey ?? PatternPhase.mixed.storageKey)"
        }

        return "\(mode.rawValue).\(stage.storageKey)"
    }

    private var currentClusterStats: AdaptiveClusterStats? {
        adaptiveLearningProgress.clusterStats[currentAdaptiveClusterKey]
    }

    private var currentClusterIsStruggling: Bool {
        adaptiveLearningProgress.remediation(for: gameMode) != nil || (currentClusterStats?.isStruggling ?? false)
    }

    private var currentClusterIsConfident: Bool {
        !currentClusterIsStruggling && (currentClusterStats?.isConfident ?? false)
    }

    private var currentSpawnInterval: TimeInterval {
        if currentClusterIsStruggling {
            return 0.78
        }

        if currentClusterIsConfident {
            return 0.42
        }

        return 0.56
    }
    
    private func spawnFlyingNumber(forceCorrect: Bool = false) {
        guard forceCorrect || flyingNumbers.count < maximumFlyingNumbers else {
            return
        }

        let isCorrect = forceCorrect || shouldSpawnCorrectNumber
        guard let spawnSlot = nextSpawnSlot(
            preferredAvoidLane: isCorrect ? lastCorrectLane : nil
        ) else {
            return
        }
        let value = isCorrect ? correctAnswer : generateWrongAnswer()
        let startY = max(
            reservedTopAreaHeight - (Self.missileHeight / 2),
            -(Self.missileHeight / 2)
        )
        let speed = adjustedLaneSpeed(
            laneSpeed: laneSpeeds[spawnSlot.lane],
            isCorrect: isCorrect
        )
        
        let flyingNumber = FlyingNumber(
            id: UUID(),
            value: value,
            position: CGPoint(x: spawnSlot.x, y: startY),
            isCorrect: isCorrect,
            speed: speed,
            lane: spawnSlot.lane
        )
        
        flyingNumbers.append(flyingNumber)

        if isCorrect {
            pendingCorrectSpawn = false
            lastCorrectLane = spawnSlot.lane
            if missedCorrectAnswerCount > 0 {
                currentProblemPresentedAt = Date()
            }
        }
    }

    private var hasCorrectFlyingNumber: Bool {
        flyingNumbers.contains { $0.value == correctAnswer }
    }

    private var shouldSpawnCorrectNumber: Bool {
        pendingCorrectSpawn && !hasCorrectFlyingNumber && Date() >= earliestCorrectSpawnDate
    }

    private func removeCurrentCorrectNumber() {
        flyingNumbers.removeAll { $0.value == correctAnswer }
    }

    private func scheduleNextCorrectSpawn() {
        scheduleNextCorrectSpawn(after: currentSpawnInterval * Double.random(in: 0.6...4.2))
    }

    private func scheduleNextCorrectSpawn(after delay: TimeInterval) {
        pendingCorrectSpawn = true
        earliestCorrectSpawnDate = Date().addingTimeInterval(delay)
    }

    private func ensureCorrectMissileAppearsSoon() {
        guard !hasCorrectFlyingNumber else { return }

        if flyingNumbers.count < maximumFlyingNumbers {
            spawnFlyingNumber(forceCorrect: true)
            return
        }

        if Date() > earliestCorrectSpawnDate.addingTimeInterval(6),
           let wrongIndex = flyingNumbers.enumerated()
            .filter({ !$0.element.isCorrect })
            .max(by: { $0.element.position.y < $1.element.position.y })?
            .offset {
            flyingNumbers.remove(at: wrongIndex)
            spawnFlyingNumber(forceCorrect: true)
        }
    }

    private func spawnWrongAnswerMissile() {
        guard flyingNumbers.count < maximumFlyingNumbers else {
            return
        }

        guard let spawnSlot = nextSpawnSlot() else {
            return
        }

        let flyingNumber = FlyingNumber(
            id: UUID(),
            value: generateWrongAnswer(),
            position: CGPoint(
                x: spawnSlot.x,
                y: max(
                    reservedTopAreaHeight - (Self.missileHeight / 2),
                    -(Self.missileHeight / 2)
                )
            ),
            isCorrect: false,
            speed: adjustedLaneSpeed(
                laneSpeed: laneSpeeds[spawnSlot.lane],
                isCorrect: false
            ),
            lane: spawnSlot.lane
        )

        flyingNumbers.append(flyingNumber)
    }

    private func adjustedLaneSpeed(laneSpeed: Double, isCorrect: Bool) -> Double {
        // Use identical speed calculation for both correct and wrong answers
        // to prevent "speed tells" - the player should not be able to identify
        // the correct answer based on rocket speed
        
        // Both types use the same wide speed range for true randomization
        let speedRange: ClosedRange<Double> = 0.72...1.15
        
        let randomizedLaneSpeed = laneSpeed * Double.random(in: speedRange)
        let boundedLaneSpeed = min(max(randomizedLaneSpeed, 0.28), 0.88)

        // Apply visibility-based speed limiting to BOTH correct and wrong answers equally
        // This ensures the correct answer isn't identifiable by being consistently slower
        guard screenSize.height > 0 else { return boundedLaneSpeed }

        let travelDistance = screenSize.height + Self.missileHeight + 50
        let framesRequired = currentMinimumCorrectVisibility / 0.016
        guard framesRequired > 0 else { return boundedLaneSpeed }

        let maximumPixelsPerFrame = Double(travelDistance) / framesRequired
        let speedMultiplier = max(currentFallSpeedMultiplier, 0.01)
        let maximumBaseSpeed = maximumPixelsPerFrame / speedMultiplier

        // Apply the speed cap to both types equally
        return min(boundedLaneSpeed, maximumBaseSpeed)
    }

    private func generateWrongAnswer() -> Int {
        if (gameMode == .multiplication || gameMode == .division),
           let currentArithmeticProblem,
           let table = currentArithmeticProblem.multiplicationTable,
           let factor = currentArithmeticProblem.multiplicationFactor {
            if gameMode == .division {
                let candidates = [
                    correctAnswer - 2,
                    correctAnswer - 1,
                    correctAnswer + 1,
                    correctAnswer + 2,
                    table,
                    factor,
                    correctAnswer + table,
                    max(1, correctAnswer - table)
                ].filter { $0 > 0 && $0 != correctAnswer }

                if let candidate = candidates.randomElement() {
                    return candidate
                }
            }

            let candidates = [
                correctAnswer - table,
                correctAnswer + table,
                correctAnswer - factor,
                correctAnswer + factor,
                correctAnswer - 1,
                correctAnswer + 1,
                correctAnswer - 2,
                correctAnswer + 2
            ].filter { $0 > 0 && $0 != correctAnswer }

            if let candidate = candidates.randomElement() {
                return candidate
            }
        }

        let minimumAnswer = gameMode == .subtraction ? 0 : 1
        let lowerBound = max(minimumAnswer, correctAnswer - 14)
        let upperBound = max(lowerBound + 1, correctAnswer + 14)
        let nearbyCandidates = Array(lowerBound...upperBound)
            .filter { $0 != correctAnswer }
        let structuredCandidates = [
            correctAnswer - 10,
            correctAnswer + 10,
            correctAnswer - 5,
            correctAnswer + 5,
            correctAnswer - 2,
            correctAnswer + 2,
            correctAnswer - 1,
            correctAnswer + 1
        ].filter { $0 >= minimumAnswer && $0 != correctAnswer }

        let weightedPool = structuredCandidates + Array(nearbyCandidates.shuffled().prefix(10))

        if let wrongAnswer = weightedPool.randomElement() {
            return wrongAnswer
        }

        return max(minimumAnswer, correctAnswer + 1)
    }
    
    private func updateAnimations() {
        let speedMultiplier = currentFallSpeedMultiplier

        // Update flying numbers positions
        for i in flyingNumbers.indices {
            flyingNumbers[i].position.y += CGFloat(flyingNumbers[i].speed * speedMultiplier)
        }

        let dissolveHeight = aircraftPosition.y - (Self.missileHeight * 0.35)
        var remainingNumbers: [FlyingNumber] = []

        for number in flyingNumbers {
            if activeSpecialMission != nil {
                remainingNumbers.append(number)
                continue
            }
            if !number.isCorrect && number.position.y >= dissolveHeight {
                continue
            }

            if number.position.y > screenSize.height + 50 {
                if number.isCorrect {
                    handleMissedProblem()
                }
                continue
            }

            remainingNumbers.append(number)
        }
        flyingNumbers = remainingNumbers
        
        // Update explosions
        for i in explosions.indices {
            explosions[i].scale += 0.08
            explosions[i].opacity -= 0.03
        }
        
        // Remove faded explosions
        explosions.removeAll { $0.opacity <= 0 }

        updateProjectiles()
        maintainMissileFlow()
    }
    
    func tappedNumber(_ number: FlyingNumber) {
        if activeSpecialMission != nil {
            guard gameStarted, !missionCompleted,
                  flyingNumbers.contains(where: { $0.id == number.id }) else { return }
            answerMission(number)
            return
        }
        guard activeFeedbackPractice == nil || !feedbackAnswerInFlight else { return }
        guard let index = flyingNumbers.firstIndex(where: { $0.id == number.id }) else {
            return
        }

        let tappedNumber = flyingNumbers[index]
        flyingNumbers.remove(at: index)
        let isCorrectAnswer = tappedNumber.value == correctAnswer
        let responseTimeMs = Int(Date().timeIntervalSince(currentProblemPresentedAt) * 1000)
        currentSessionAttempts += 1
        if isCorrectAnswer {
            currentSessionCorrectAnswers += 1
        }
        logAnalyticsEvent(
            chosenAnswer: tappedNumber.value,
            isCorrect: isCorrectAnswer,
            responseTimeMs: responseTimeMs
        )
        recordAdaptiveOutcome(
            isCorrect: isCorrectAnswer,
            responseTimeMs: responseTimeMs
        )
        recordFactFamilyProgressIfNeeded(
            isCorrect: isCorrectAnswer,
            responseTimeMs: responseTimeMs
        )

        if isCorrectAnswer {
            if activeFeedbackPractice != nil {
                feedbackAnswerInFlight = true
                problemTimer?.invalidate()
            }
            projectiles.append(
                Projectile(
                    id: UUID(),
                    startPosition: aircraftPosition,
                    endPosition: tappedNumber.position,
                    currentPosition: aircraftPosition,
                    progress: 0,
                    speed: 0.11,
                    kind: .playerShot,
                    impact: .correctAnswer
                )
            )
        } else if isBossFightActive {
            projectiles.append(
                Projectile(
                    id: UUID(),
                    startPosition: aircraftPosition,
                    endPosition: CGPoint(x: screenSize.width / 2, y: max(150, screenSize.height * 0.26)),
                    currentPosition: aircraftPosition,
                    progress: 0,
                    speed: 0.08,
                    kind: .playerShot,
                    impact: .bossBlocked
                )
            )
        } else {
            projectiles.append(
                Projectile(
                    id: UUID(),
                    startPosition: tappedNumber.position,
                    endPosition: aircraftPosition,
                    currentPosition: tappedNumber.position,
                    progress: 0,
                    speed: 0.035,
                    kind: .enemyDive,
                    impact: .playerHit
                )
            )
        }
    }

    private func updateProjectiles() {
        var impacts: [(ProjectileImpact, CGPoint)] = []

        for i in projectiles.indices {
            projectiles[i].progress += projectiles[i].speed

            let progress = min(projectiles[i].progress, 1)
            projectiles[i].currentPosition = interpolate(
                from: projectiles[i].startPosition,
                to: projectiles[i].endPosition,
                progress: progress,
                kind: projectiles[i].kind
            )

            if progress >= 1 {
                impacts.append((projectiles[i].impact, projectiles[i].endPosition))
            }
        }

        projectiles.removeAll { $0.progress >= 1 }

        for impact in impacts {
            handleProjectileImpact(impact.0, at: impact.1)
        }
    }

    private func handleProjectileImpact(_ impact: ProjectileImpact, at position: CGPoint) {
        switch impact {
        case .correctAnswer:
            if completeFeedbackPracticeIfNeeded(at: position) {
                return
            }

            let explosion = Explosion(
                id: UUID(),
                position: position,
                scale: 0.6,
                opacity: 1.0
            )
            explosions.append(explosion)
            score += 10 * level

            if score % 50 == 0 {
                level += 1
            }

            if gameMode == .multiplication,
               let unlockedTable = pendingMultiplicationUnlockTable {
                soundManager?.playExplosionSound()
                generateNewProblem()

                if currentArithmeticProblem?.multiplicationTable == unlockedTable {
                    pendingMultiplicationUnlockTable = nil
                    celebrationNeedsFreshProblem = false
                    pauseForCelebration()
                    activeCelebration = CelebrationEvent()
                }
                return
            }

            if gameMode == .division,
               let unlockedTable = pendingDivisionUnlockTable {
                soundManager?.playExplosionSound()
                generateNewProblem()

                if currentArithmeticProblem?.multiplicationTable == unlockedTable {
                    pendingDivisionUnlockTable = nil
                    celebrationNeedsFreshProblem = false
                    pauseForCelebration()
                    activeCelebration = CelebrationEvent()
                }
                return
            }

            let triggersCelebration = shouldTriggerCelebration(for: currentProblemStage)

            if triggersCelebration {
                celebrationNeedsFreshProblem = true
                pauseForCelebration()
                activeCelebration = CelebrationEvent()
            } else {
                soundManager?.playExplosionSound()
                generateNewProblem()
            }

        case .playerHit:
            let explosion = Explosion(
                id: UUID(),
                position: aircraftPosition,
                scale: 1.15,
                opacity: 1.0
            )
            explosions.append(explosion)
            soundManager?.playExplosionSound()
            if activeSpecialMission == nil, activeFeedbackPractice == nil {
                loseLife()
            }
            pauseForRecovery()
        case .bossBlocked:
            break
        case .bossDramaticShot, .missionHit:
            let explosion = Explosion(
                id: UUID(),
                position: position,
                scale: 0.42,
                opacity: 0.85
            )
            explosions.append(explosion)
        }
    }

    private func loseLife() {
        remainingLives = max(remainingLives - 1, 0)

        if remainingLives == 0 {
            gameOver = true
            updateMissionRecommendationIfNeeded()
            soundManager?.stopAmbientSound()
            stopTimers()
        }
    }

    private func handleMissedProblem() {
        guard activeFeedbackPractice == nil || !feedbackAnswerInFlight else { return }
        let responseTimeMs = Int(Date().timeIntervalSince(currentProblemPresentedAt) * 1000)
        currentSessionAttempts += 1
        logAnalyticsEvent(
            chosenAnswer: -1,
            isCorrect: false,
            responseTimeMs: responseTimeMs
        )
        recordAdaptiveOutcome(
            isCorrect: false,
            responseTimeMs: responseTimeMs
        )
        recordFactFamilyProgressIfNeeded(
            isCorrect: false,
            responseTimeMs: responseTimeMs
        )

        if activeFeedbackPractice != nil {
            problemTimer?.invalidate()
            scheduleNextCorrectSpawn(after: retrySpawnDelay)
            maintainMissileFlow()
            return
        }

        if activeSpecialMission != nil {
            scheduleProblemTimer()
            scheduleNextCorrectSpawn(after: retrySpawnDelay)
            maintainMissileFlow()
            return
        }

        loseLife()
        pauseForRecovery()

        guard gameStarted, !gameOver else { return }

        if gameMode == .multiplication || gameMode == .division {
            generateNewProblem()
            return
        }

        if missedCorrectAnswerCount == 0 {
            missedCorrectAnswerCount = 1
            scheduleProblemTimer()
            scheduleNextCorrectSpawn(after: retrySpawnDelay)
            maintainMissileFlow()
            return
        }

        generateNewProblem()
    }

    private func pauseForRecovery() {
        guard gameStarted, !gameOver, !isPausedForCelebration else { return }

        isRecoveryPaused = true
        recoveryResumeWorkItem?.cancel()
        stopTimers()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.isRecoveryPaused = false

            guard self.gameStarted, !self.gameOver, !self.isPausedForCelebration else { return }
            self.startTimers()
        }

        recoveryResumeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func updateHighScoreIfNeeded() {
        guard score > highScore else { return }
        highScore = score
        UserDefaults.standard.set(score, forKey: Self.highScoreKey)
    }

    func finishCelebration() {
        activeCelebration = nil

        guard isPausedForCelebration else { return }

        isPausedForCelebration = false

        guard gameStarted, !gameOver else { return }

        if celebrationNeedsFreshProblem {
            generateNewProblem()
        }
        celebrationNeedsFreshProblem = true
        startTimers()
    }

    private func pauseForCelebration() {
        guard !isPausedForCelebration else { return }
        isPausedForCelebration = true
        stopTimers()
    }

    private func shouldTriggerCelebration(for stage: DifficultyStage) -> Bool {
        guard stage.isDifficult else { return false }

        difficultProblemSolveCount += 1

        guard difficultProblemSolveCount >= 5 else { return false }

        difficultProblemSolveCount = 0
        return true
    }

    private func logAnalyticsEvent(chosenAnswer: Int, isCorrect: Bool, responseTimeMs: Int) {
        let phase = currentProblemPatternPhase
        let record = AnalyticsRecord(
            timestamp: Date(),
            mode: gameMode,
            stage: currentProblemStage,
            patternPhase: phase,
            problem: currentProblem,
            correctAnswer: correctAnswer,
            chosenAnswer: chosenAnswer,
            isCorrect: isCorrect,
            wasRetry: currentProblemHasAttempt,
            responseTimeMs: max(responseTimeMs, 0)
        )

        currentProblemHasAttempt = true
        if !isCorrect { activeFeedbackPractice?.currentProblemHadError = true }
        analyticsRecords.append(record)

        if analyticsRecords.count > 600 {
            analyticsRecords.removeFirst(analyticsRecords.count - 600)
        }

        AnalyticsRecord.store(analyticsRecords, forKey: Self.analyticsRecordsKey)
    }

    func updateMissionRecommendationIfNeeded(
        automaticSuggestionsEnabled: Bool = true,
        missionEnabled: (SpecialMissionID) -> Bool = { _ in true }
    ) {
        guard automaticSuggestionsEnabled,
              activeSpecialMission == nil,
              !analyticsRecords.isEmpty else {
            recommendedMission = nil
            return
        }

        let sessionRecords = Array(analyticsRecords.suffix(max(currentSessionAttempts, 1)))
        let recommendation = SpecialMissionRecommendationEngine.recommendation(
            from: sessionRecords,
            missionEnabled: missionEnabled
        )
        recommendedMission = recommendation

        if let recommendation {
            var progress = specialMissionProgress[recommendation] ?? SpecialMissionProgress(mission: recommendation)
            progress.missionUnlocked = true
            progress.recommendedByAnalysis = true
            specialMissionProgress[recommendation] = progress
            SpecialMissionProgress.store(specialMissionProgress, forKey: Self.specialMissionProgressKey)
        }
    }

    private func recordFactFamilyProgressIfNeeded(isCorrect: Bool, responseTimeMs: Int) {
        guard let currentArithmeticProblem,
              let table = currentArithmeticProblem.multiplicationTable else {
            return
        }

        switch gameMode {
        case .multiplication:
            if let unlockedTable = multiplicationProgress.recordAttempt(
                for: table,
                responseTimeMs: max(responseTimeMs, 0),
                isCorrect: isCorrect,
                includeSwapPhase: curriculumSettings.multiplicationIncludeReversedFacts
            ) {
                pendingMultiplicationUnlockTable = unlockedTable
            }
            MultiplicationProgress.store(
                multiplicationProgress,
                forKey: Self.multiplicationProgressKey
            )
        case .division:
            if let unlockedTable = divisionProgress.recordAttempt(
                for: table,
                responseTimeMs: max(responseTimeMs, 0),
                isCorrect: isCorrect,
                includeSwapPhase: false
            ) {
                pendingDivisionUnlockTable = unlockedTable
            }
            MultiplicationProgress.store(
                divisionProgress,
                forKey: Self.divisionProgressKey
            )
        case .addition, .subtraction:
            break
        }
    }

    private func recordAdaptiveOutcome(isCorrect: Bool, responseTimeMs: Int) {
        guard !currentAdaptiveClusterKey.isEmpty else { return }

        adaptiveLearningProgress.recordAttempt(
            for: currentAdaptiveClusterKey,
            responseTimeMs: max(responseTimeMs, 0),
            isCorrect: isCorrect
        )

        if gameMode != .multiplication && gameMode != .division,
           let remediationPlan = remediationPlan(
                for: currentTargetStage,
                targetPatternPhase: currentTargetPatternPhase
           ),
           adaptiveLearningProgress.stats(for: currentAdaptiveClusterKey)?.isStruggling == true {
            adaptiveLearningProgress.setRemediation(
                remediationPlan,
                for: gameMode
            )
        }

        updateArithmeticMasteryIfNeeded()
        persistAdaptiveLearningProgress()
    }

    private func updateArithmeticMasteryIfNeeded() {
        guard gameMode != .multiplication && gameMode != .division else { return }
        guard let stats = adaptiveLearningProgress.stats(for: currentAdaptiveClusterKey) else { return }

        let currentIndex = adaptiveLearningProgress.stageIndex(for: gameMode)
        guard arithmeticStagePath.indices.contains(currentIndex) else { return }
        guard arithmeticStagePath[currentIndex] == currentTargetStage else { return }

        if stats.isPromotionReady, currentIndex < arithmeticStagePath.count - 1 {
            adaptiveLearningProgress.setStageIndex(currentIndex + 1, for: gameMode)
            adaptiveLearningProgress.setRemediation(nil, for: gameMode)
        } else if stats.isRegressionReady, currentIndex > 0 {
            adaptiveLearningProgress.setStageIndex(currentIndex - 1, for: gameMode)
        }
    }

    private func remediationPlan(
        for targetStage: DifficultyStage,
        targetPatternPhase: PatternPhase?
    ) -> RemediationFocus? {
        switch targetStage {
        case .crossing10:
            return RemediationFocus(
                targetClusterKey: currentAdaptiveClusterKey,
                presentedStage: .complementsTo10,
                presentedPatternPhase: nil
            )
        case .complementsTo20:
            return RemediationFocus(
                targetClusterKey: currentAdaptiveClusterKey,
                presentedStage: .crossing10,
                presentedPatternPhase: nil
            )
        case .digitPlusWholeTens:
            return RemediationFocus(
                targetClusterKey: currentAdaptiveClusterKey,
                presentedStage: .singleDigit,
                presentedPatternPhase: nil
            )
        case .doubleDigitPlusSingleNoCrossing:
            return RemediationFocus(
                targetClusterKey: currentAdaptiveClusterKey,
                presentedStage: .digitPlusWholeTens,
                presentedPatternPhase: nil
            )
        case .twoDigitNoCarryBorrow:
            return RemediationFocus(
                targetClusterKey: currentAdaptiveClusterKey,
                presentedStage: .doubleDigitPlusSingleNoCrossing,
                presentedPatternPhase: nil
            )
        case .twoDigitWithCarryBorrow:
            return RemediationFocus(
                targetClusterKey: currentAdaptiveClusterKey,
                presentedStage: .twoDigitNoCarryBorrow,
                presentedPatternPhase: nil
            )
        case .pattern:
            return RemediationFocus(
                targetClusterKey: currentAdaptiveClusterKey,
                presentedStage: targetPatternPhase == .onesProgression ? .doubleDigitPlusSingleNoCrossing : .digitPlusWholeTens,
                presentedPatternPhase: nil
            )
        default:
            return nil
        }
    }

    private func adjustedPacing(base: Double) -> Double {
        if currentClusterIsStruggling {
            return max(base * 0.82, 0.34)
        }

        if currentClusterIsConfident {
            return min(base * 1.12, 1.05)
        }

        return base
    }

    private func adjustedProblemDuration(base: TimeInterval) -> TimeInterval {
        if currentClusterIsStruggling {
            return base + 12
        }

        if currentClusterIsConfident {
            return max(base - 8, 20)
        }

        return base
    }

    private func adjustedVisibility(base: TimeInterval) -> TimeInterval {
        if currentClusterIsStruggling {
            return base + 12
        }

        if currentClusterIsConfident {
            return max(base - 8, 24)
        }

        return base
    }

    private var currentFallSpeedMultiplier: Double {
        if gameMode == .multiplication || gameMode == .division {
            let progress = gameMode == .division ? divisionProgress : multiplicationProgress
            let base: Double
            switch progress.phase {
            case .intro:
                base = 0.62
            case .fullTable:
                base = 0.68
            case .commutativeSwap:
                base = 0.74
            case .mastered:
                base = 0.82
            }
            return adjustedPacing(base: base)
        }

        let base: Double
        switch currentTargetStage {
        case .singleDigit, .complementsTo10:
            base = 0.92
        case .crossing10, .complementsTo20, .digitPlusWholeTens, .doubleDigitPlusSingleNoCrossing:
            base = 0.80
        case .twoDigitNoCarryBorrow, .twoDigitWithCarryBorrow:
            base = 0.70
        case .pattern, .mixed:
            base = 0.74
        case .multiplicationIntro, .multiplicationTable, .multiplicationSwap, .multiplicationMastered:
            base = 0.72
        }

        return adjustedPacing(base: base)
    }

    private var currentProblemDuration: TimeInterval {
        if gameMode == .multiplication || gameMode == .division {
            let progress = gameMode == .division ? divisionProgress : multiplicationProgress
            let base: TimeInterval
            switch progress.phase {
            case .intro:
                base = 45
            case .fullTable:
                base = 55
            case .commutativeSwap, .mastered:
                base = 60
            }
            return adjustedProblemDuration(base: base)
        }

        let base = currentTargetStage == .singleDigit
            ? singleDigitProblemDuration
            : (isTwoDigitStage ? (baseProblemDuration * twoDigitTimeMultiplier) : baseProblemDuration)
        return adjustedProblemDuration(base: base)
    }

    private var currentMinimumCorrectVisibility: TimeInterval {
        if gameMode == .multiplication || gameMode == .division {
            return adjustedVisibility(base: 75)
        }

        let base = isTwoDigitStage
            ? (baseMinimumCorrectVisibility * twoDigitTimeMultiplier)
            : baseMinimumCorrectVisibility
        return adjustedVisibility(base: base)
    }

    private var isTwoDigitStage: Bool {
        guard gameMode != .multiplication && gameMode != .division else { return false }

        switch currentTargetStage {
        case .digitPlusWholeTens, .doubleDigitPlusSingleNoCrossing, .twoDigitNoCarryBorrow, .twoDigitWithCarryBorrow:
            return true
        default:
            return false
        }
    }

    var aircraftPosition: CGPoint {
        CGPoint(x: screenSize.width / 2, y: max(132, screenSize.height - 76))
    }

    private func interpolate(from start: CGPoint, to end: CGPoint, progress: Double, kind: ProjectileKind) -> CGPoint {
        let adjustedProgress: Double

        switch kind {
        case .enemyDive:
            adjustedProgress = progress * progress
        case .playerShot, .enemyShot:
            adjustedProgress = 1 - pow(1 - progress, 3)
        }

        return CGPoint(
            x: start.x + ((end.x - start.x) * adjustedProgress),
            y: start.y + ((end.y - start.y) * adjustedProgress)
        )
    }

    private func nextSpawnSlot(preferredAvoidLane: Int? = nil) -> (lane: Int, x: CGFloat)? {
        guard screenSize.width > 0 else {
            return nil
        }

        let sideInset = max((Self.missileWidth / 2) + 44, 88)
        let usableWidth = max(screenSize.width - (sideInset * 2), Self.missileWidth * CGFloat(laneCount - 1))
        let laneSpacing = usableWidth / CGFloat(max(laneCount - 1, 1))
        let spawnBandHeight = Self.missileHeight * spawnClearanceHeightMultiplier
        let laneCenters = (0..<laneCount).map { lane in
            sideInset + (CGFloat(lane) * laneSpacing)
        }
        var laneOrder = (0..<laneCount).sorted { left, right in
            let leftCount = flyingNumbers.filter { $0.lane == left }.count
            let rightCount = flyingNumbers.filter { $0.lane == right }.count

            if leftCount == rightCount {
                let leftNearest = nearestMissileY(inLane: left)
                let rightNearest = nearestMissileY(inLane: right)
                return leftNearest > rightNearest
            }

            return leftCount < rightCount
        }

        if let preferredAvoidLane, laneOrder.count > 1,
           let avoidIndex = laneOrder.firstIndex(of: preferredAvoidLane) {
            let avoidedLane = laneOrder.remove(at: avoidIndex)
            laneOrder.append(avoidedLane)
        }

        for lane in laneOrder {
            let nearestY = nearestMissileY(inLane: lane)

            if nearestY >= spawnBandHeight {
                return (lane, laneCenters[lane])
            }
        }

        return nil
    }

    private func maintainMissileFlow() {
        guard gameStarted, !gameOver, activeSpecialMission == nil else { return }

        if shouldSpawnCorrectNumber {
            ensureCorrectMissileAppearsSoon()
        }

        guard flyingNumbers.count < maximumFlyingNumbers else { return }
        guard Date() >= nextSpawnAllowedDate else { return }

        if shouldSpawnCorrectNumber {
            spawnFlyingNumber(forceCorrect: true)
        } else {
            spawnWrongAnswerMissile()
        }

        nextSpawnAllowedDate = Date().addingTimeInterval(currentSpawnInterval)
    }

    private func nearestMissileY(inLane lane: Int) -> CGFloat {
        let laneNumbers = flyingNumbers.filter { $0.lane == lane }
        return laneNumbers.map(\.position.y).min() ?? .greatestFiniteMagnitude
    }

    private func makeLaneSpeeds() -> [Double] {
        let base = [0.46, 0.54, 0.61]
        let shuffledOffsets = [-0.02, 0.0, 0.03].shuffled()
        return zip(base, shuffledOffsets).map { min(max($0 + $1, 0.42), 0.66) }
    }

    private var arithmeticStagePath: [DifficultyStage] {
        curriculumSettings.arithmeticStages
    }

    private var currentDifficultyStage: DifficultyStage {
        if gameMode == .multiplication {
            return multiplicationProgress.currentStage
        }

        if gameMode == .division {
            return divisionProgress.currentStage
        }

        let stageIndex = adaptiveLearningProgress.stageIndex(for: gameMode)
        let safeIndex = min(max(stageIndex, 0), arithmeticStagePath.count - 1)
        return arithmeticStagePath[safeIndex]
    }

    private func generateProblem(
        for stage: DifficultyStage,
        mode: GameMode,
        forcedPatternPhase: PatternPhase? = nil
    ) -> ArithmeticProblem {
        switch (mode, stage) {
        case (.addition, .singleDigit):
            let left = Int.random(in: 1...8)
            let right = Int.random(in: 1...(9 - left))
            return .standard(left: left, symbol: "+", right: right, result: left + right)

        case (.addition, .complementsTo10):
            let left = Int.random(in: 1...9)
            return .custom(prompt: "\(left) + ? = 10", result: 10 - left)

        case (.addition, .crossing10):
            let left = Int.random(in: 5...9)
            let right = Int.random(in: (11 - left)...9)
            return .standard(left: left, symbol: "+", right: right, result: left + right)

        case (.addition, .complementsTo20):
            let left = Int.random(in: 11...19)
            return .custom(prompt: "\(left) + ? = 20", result: 20 - left)

        case (.addition, .digitPlusWholeTens):
            let left = Int.random(in: 1...9)
            let right = [10, 20, 30, 40, 50].randomElement() ?? 10
            return .standard(left: left, symbol: "+", right: right, result: left + right)

        case (.addition, .doubleDigitPlusSingleNoCrossing):
            let tens = Int.random(in: 1...8) * 10
            let leftOnes = Int.random(in: 0...8)
            let right = Int.random(in: 1...(9 - leftOnes))
            let left = tens + leftOnes
            return .standard(left: left, symbol: "+", right: right, result: left + right)

        case (.addition, .twoDigitNoCarryBorrow):
            let leftTens = Int.random(in: 1...6)
            let rightTens = Int.random(in: 1...(8 - leftTens))
            let leftOnes = Int.random(in: 1...8)
            let rightOnes = Int.random(in: 1...(9 - leftOnes))
            let left = (leftTens * 10) + leftOnes
            let right = (rightTens * 10) + rightOnes
            return .standard(left: left, symbol: "+", right: right, result: left + right)

        case (.addition, .twoDigitWithCarryBorrow):
            let tens = Int.random(in: 1...7) * 10
            let leftOnes = Int.random(in: 3...9)
            let right = Int.random(in: max(10 - leftOnes, 2)...9)
            let left = tens + leftOnes
            return .standard(left: left, symbol: "+", right: right, result: left + right)

        case (.addition, .pattern):
            let pair: (left: Int, right: Int)

            switch forcedPatternPhase ?? currentProblemPatternPhase ?? .tensProgression {
            case .tensProgression:
                let right = [6, 7, 8].randomElement() ?? 7
                let ones = [9, 8, 7].randomElement() ?? 9
                let tens = [2, 3, 4, 5, 6].randomElement() ?? 2
                pair = ((tens * 10) + ones, right)
            case .onesProgression:
                let tens = [20, 30, 40, 50].randomElement() ?? 20
                let right = [3, 4, 5].randomElement() ?? 4
                let leftOnes = Int.random(in: 1...(9 - right))
                pair = (tens + leftOnes, right)
            case .mixed:
                let options: [(Int, Int)] = [
                    (29, 7), (39, 7), (49, 7), (59, 7),
                    (24, 5), (25, 4), (32, 6), (43, 5), (54, 4)
                ]
                pair = options.randomElement() ?? (29, 7)
            }

            let left = pair.left
            let right = pair.right
            return .standard(left: left, symbol: "+", right: right, result: left + right)

        case (.addition, .mixed):
            let stage = [
                DifficultyStage.digitPlusWholeTens,
                .doubleDigitPlusSingleNoCrossing,
                DifficultyStage.twoDigitNoCarryBorrow,
                .twoDigitWithCarryBorrow,
                .pattern
            ].randomElement() ?? .twoDigitNoCarryBorrow
            return generateProblem(for: stage, mode: .addition, forcedPatternPhase: forcedPatternPhase)

        case (.subtraction, .singleDigit):
            let left = Int.random(in: 2...9)
            let right = Int.random(in: 1..<(left))
            return .standard(left: left, symbol: "-", right: right, result: left - right)

        case (.subtraction, .complementsTo10):
            let right = Int.random(in: 1...9)
            return .custom(prompt: "10 - ? = \(10 - right)", result: right)

        case (.subtraction, .crossing10):
            let left = Int.random(in: 11...18)
            let right = Int.random(in: (left % 10 + 1)...9)
            return .standard(left: left, symbol: "-", right: right, result: left - right)

        case (.subtraction, .complementsTo20):
            let right = Int.random(in: 11...19)
            return .custom(prompt: "20 - ? = \(20 - right)", result: right)

        case (.subtraction, .digitPlusWholeTens):
            let right = Int.random(in: 1...9)
            let tens = [10, 20, 30, 40, 50].randomElement() ?? 10
            let left = tens + right
            return .standard(left: left, symbol: "-", right: right, result: tens)

        case (.subtraction, .doubleDigitPlusSingleNoCrossing):
            let tens = Int.random(in: 2...8) * 10
            let leftOnes = Int.random(in: 1...9)
            let right = Int.random(in: 1...leftOnes)
            let left = tens + leftOnes
            return .standard(left: left, symbol: "-", right: right, result: left - right)

        case (.subtraction, .twoDigitNoCarryBorrow):
            let leftTens = Int.random(in: 2...8)
            let rightTens = Int.random(in: 1..<(leftTens))
            let leftOnes = Int.random(in: 1...9)
            let rightOnes = Int.random(in: 0...leftOnes)
            let left = (leftTens * 10) + leftOnes
            let right = (rightTens * 10) + rightOnes
            return .standard(left: left, symbol: "-", right: right, result: left - right)

        case (.subtraction, .twoDigitWithCarryBorrow):
            let tens = Int.random(in: 2...8) * 10
            let leftOnes = Int.random(in: 1...6)
            let right = Int.random(in: (leftOnes + 1)...9)
            let left = tens + leftOnes
            return .standard(left: left, symbol: "-", right: right, result: left - right)

        case (.subtraction, .pattern):
            let pair: (left: Int, right: Int)

            switch forcedPatternPhase ?? currentProblemPatternPhase ?? .tensProgression {
            case .tensProgression:
                let right = 9
                let tens = [5, 6, 7, 8].randomElement() ?? 5
                pair = ((tens * 10) + 2, right)
            case .onesProgression:
                let tens = [40, 50, 60, 70].randomElement() ?? 40
                let right = [2, 3, 4, 5].randomElement() ?? 3
                let leftOnes = Int.random(in: right...9)
                pair = (tens + leftOnes, right)
            case .mixed:
                let options: [(Int, Int)] = [
                    (52, 9), (62, 9), (72, 9), (82, 9),
                    (46, 3), (57, 4), (68, 5), (74, 2)
                ]
                pair = options.randomElement() ?? (52, 9)
            }

            let left = pair.left
            let right = pair.right
            return .standard(left: left, symbol: "-", right: right, result: left - right)

        case (.subtraction, .mixed):
            let stage = [
                DifficultyStage.digitPlusWholeTens,
                .doubleDigitPlusSingleNoCrossing,
                DifficultyStage.twoDigitNoCarryBorrow,
                .twoDigitWithCarryBorrow,
                .pattern
            ].randomElement() ?? .twoDigitNoCarryBorrow
            return generateProblem(for: stage, mode: .subtraction, forcedPatternPhase: forcedPatternPhase)

        case (.multiplication, .multiplicationIntro):
            return nextMultiplicationProblem(for: stage)

        case (.multiplication, .multiplicationTable):
            return nextMultiplicationProblem(for: stage)

        case (.multiplication, .multiplicationSwap):
            return nextMultiplicationProblem(for: stage)

        case (.multiplication, .multiplicationMastered):
            return nextMultiplicationProblem(for: stage)

        case (.division, .multiplicationIntro):
            return nextDivisionProblem(for: stage)

        case (.division, .multiplicationTable):
            return nextDivisionProblem(for: stage)

        case (.division, .multiplicationSwap):
            return nextDivisionProblem(for: stage)

        case (.division, .multiplicationMastered):
            return nextDivisionProblem(for: stage)

        default:
            return generateFallbackProblem(for: mode)
        }
    }

    private func makeMultiplicationProblem(table: Int, factor: Int, reversed: Bool = false) -> ArithmeticProblem {
        ArithmeticProblem.standard(
            left: reversed ? factor : table,
            symbol: "×",
            right: reversed ? table : factor,
            result: table * factor,
            multiplicationTable: table,
            multiplicationFactor: factor
        )
    }

    private func makeDivisionProblem(table: Int, factor: Int) -> ArithmeticProblem {
        ArithmeticProblem.standard(
            left: table * factor,
            symbol: "÷",
            right: table,
            result: factor,
            multiplicationTable: table,
            multiplicationFactor: factor
        )
    }

    private var currentFactFamilyCount: Int {
        switch gameMode {
        case .multiplication:
            return multiplicationFacts(for: multiplicationProgress.currentStage).count
        case .division:
            return multiplicationFacts(for: divisionProgress.currentStage).count
        case .addition, .subtraction:
            return 0
        }
    }

    private func nextMultiplicationProblem(for stage: DifficultyStage) -> ArithmeticProblem {
        let facts = multiplicationFacts(for: stage)
        guard !facts.isEmpty else {
            let fallbackFactor = curriculumSettings.normalizedMultiplicationFactors.first ?? 2
            return makeMultiplicationProblem(table: multiplicationProgress.currentTable, factor: fallbackFactor)
        }

        let key = multiplicationDeckKey(for: facts)
        var deck = multiplicationProblemDecks[key] ?? []

        if deck.isEmpty {
            deck = facts.shuffled()
        }

        if deck.count > 1,
           let currentPrompt = currentArithmeticProblem?.prompt,
           deck[0].prompt == currentPrompt,
           let alternateIndex = deck.firstIndex(where: { $0.prompt != currentPrompt }) {
            deck.swapAt(0, alternateIndex)
        }

        let fact = deck.removeFirst()
        multiplicationProblemDecks[key] = deck
        return makeMultiplicationProblem(table: fact.table, factor: fact.factor, reversed: fact.reversed)
    }

    private func nextDivisionProblem(for stage: DifficultyStage) -> ArithmeticProblem {
        let facts = multiplicationFacts(for: stage)
        guard !facts.isEmpty else {
            let fallbackFactor = curriculumSettings.normalizedMultiplicationFactors.first ?? 2
            return makeDivisionProblem(table: divisionProgress.currentTable, factor: fallbackFactor)
        }

        let key = multiplicationDeckKey(for: facts)
        var deck = divisionProblemDecks[key] ?? []

        if deck.isEmpty {
            deck = facts.shuffled()
        }

        if deck.count > 1,
           let currentPrompt = currentArithmeticProblem?.prompt,
           deck[0].divisionPrompt == currentPrompt,
           let alternateIndex = deck.firstIndex(where: { $0.divisionPrompt != currentPrompt }) {
            deck.swapAt(0, alternateIndex)
        }

        let fact = deck.removeFirst()
        divisionProblemDecks[key] = deck
        return makeDivisionProblem(table: fact.table, factor: fact.factor)
    }

    private func multiplicationFacts(for _: DifficultyStage) -> [MultiplicationFact] {
        let progress = gameMode == .division ? divisionProgress : multiplicationProgress
        let tables: [Int]
        switch progress.phase {
        case .intro, .fullTable, .commutativeSwap:
            tables = [progress.currentTable]
        case .mastered:
            tables = progress.availableTables
        }

        let includeReversed = gameMode == .multiplication &&
            curriculumSettings.multiplicationIncludeReversedFacts &&
            (progress.phase == .commutativeSwap || progress.phase == .mastered)

        return multiplicationFacts(
            tables: tables,
            factors: curriculumSettings.normalizedMultiplicationFactors,
            includeForward: true,
            includeReversed: includeReversed
        )
    }

    private func multiplicationFacts(
        tables: [Int],
        factors: [Int],
        includeForward: Bool,
        includeReversed: Bool
    ) -> [MultiplicationFact] {
        var seenPrompts: Set<String> = []
        var facts: [MultiplicationFact] = []

        for table in tables {
            for factor in factors {
                let candidates = [
                    includeForward ? MultiplicationFact(table: table, factor: factor, reversed: false) : nil,
                    includeReversed ? MultiplicationFact(table: table, factor: factor, reversed: true) : nil
                ].compactMap { $0 }

                for fact in candidates where !seenPrompts.contains(fact.prompt) {
                    seenPrompts.insert(fact.prompt)
                    facts.append(fact)
                }
            }
        }

        return facts
    }

    private func multiplicationDeckKey(for facts: [MultiplicationFact]) -> String {
        let factKey = facts.map(\.prompt).joined(separator: "|")
        return factKey
    }

    private func generateFallbackProblem(for mode: GameMode) -> ArithmeticProblem {
        switch mode {
        case .addition:
            return .standard(left: 2, symbol: "+", right: 3, result: 5)
        case .subtraction:
            return .standard(left: 6, symbol: "-", right: 2, result: 4)
        case .multiplication:
            let fallbackFactor = curriculumSettings.normalizedMultiplicationFactors.first ?? 2
            return makeMultiplicationProblem(table: multiplicationProgress.currentTable, factor: fallbackFactor)
        case .division:
            let fallbackFactor = curriculumSettings.normalizedMultiplicationFactors.first ?? 2
            return makeDivisionProblem(table: divisionProgress.currentTable, factor: fallbackFactor)
        }
    }

    private func synchronizeMultiplicationProgress() {
        var updatedProgress = multiplicationProgress
        updatedProgress.applyTableSequence(curriculumSettings.normalizedMultiplicationTables)
        var updatedDivisionProgress = divisionProgress
        updatedDivisionProgress.applyTableSequence(curriculumSettings.normalizedMultiplicationTables)

        if !curriculumSettings.multiplicationIncludeReversedFacts {
            updatedProgress.skipSwapPhaseIfNeeded()
        }
        updatedDivisionProgress.skipSwapPhaseIfNeeded()

        multiplicationProgress = updatedProgress
        divisionProgress = updatedDivisionProgress
        multiplicationProblemDecks.removeAll()
        divisionProblemDecks.removeAll()
        MultiplicationProgress.store(
            multiplicationProgress,
            forKey: Self.multiplicationProgressKey
        )
        MultiplicationProgress.store(
            divisionProgress,
            forKey: Self.divisionProgressKey
        )
    }
}

struct FlyingNumber: Identifiable {
    let id: UUID
    let value: Int
    var position: CGPoint
    let isCorrect: Bool
    let speed: Double
    let lane: Int
}

enum SpecialMissionPhase: String, Codable {
    case discoverPattern
    case unlockStrategy
    case focusedPractice
    case transferChallenge
    case bossFight

    var problemTarget: Int {
        switch self {
        case .discoverPattern:
            return 2
        case .unlockStrategy:
            return 2
        case .focusedPractice:
            return 4
        case .transferChallenge:
            return 3
        case .bossFight:
            return 3
        }
    }

    var next: SpecialMissionPhase? {
        switch self {
        case .discoverPattern:
            return .unlockStrategy
        case .unlockStrategy:
            return .focusedPractice
        case .focusedPractice:
            return .transferChallenge
        case .transferChallenge:
            return .bossFight
        case .bossFight:
            return nil
        }
    }
}

struct SpecialMissionSession: Equatable {
    let mission: SpecialMissionID
    var phase: SpecialMissionPhase
}

enum BossFightState: Equatable {
    case inactive
    case intro
    case active
    case damaged
    case blocked
    case defeated
    case reward
}

struct BossDefinition: Equatable {
    let id: String
    let name: String
    let vehicleTheme: VehicleType
    let strategyType: SpecialMissionID
    let spriteName: String
    let maxHP: Int
    let introText: String
    let defeatRewardId: String

    init(vehicleTheme: VehicleType, strategyType: SpecialMissionID, maxHP: Int = 3) {
        self.id = "\(vehicleTheme.rawValue)-\(strategyType.rawValue)-boss"
        self.name = "Mission Boss"
        self.vehicleTheme = vehicleTheme
        self.strategyType = strategyType
        self.maxHP = maxHP
        self.introText = "Boss incoming!"
        self.defeatRewardId = "\(strategyType.rawValue)-badge"

        switch vehicleTheme {
        case .tank:
            self.spriteName = "EvilTank"
        case .jet:
            self.spriteName = "EvilJet"
        case .unicorn:
            self.spriteName = "EvilDragon"
        }
    }
}

struct BossEntity: Equatable {
    let id = UUID()
    let definition: BossDefinition
    var currentHP: Int
    var animationToken = UUID()

    init(definition: BossDefinition) {
        self.definition = definition
        self.currentHP = definition.maxHP
    }
}

struct SpecialMissionProgress: Codable {
    let mission: SpecialMissionID
    var missionUnlocked = true
    var missionCompleted = false
    var attempts = 0
    var completionCount = 0
    var lastAccuracy = 0.0
    var averageResponseTimeMs = 0.0
    var recommendedByAnalysis = false
    var completionDate: Date?
    var rewardUnlocked = false
    var rewardId: String?

    static func loadStored(forKey key: String) -> [SpecialMissionID: SpecialMissionProgress] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let storedProgress = try? JSONDecoder().decode([String: SpecialMissionProgress].self, from: data) else {
            return Dictionary(
                uniqueKeysWithValues: SpecialMissionID.allCases.map {
                    ($0, SpecialMissionProgress(mission: $0, missionUnlocked: $0 == .friendsOf10))
                }
            )
        }

        let decoded = Dictionary(
            uniqueKeysWithValues: storedProgress.compactMap { key, value in
                SpecialMissionID(rawValue: key).map { ($0, value) }
            }
        )
        return decoded.merging(Dictionary(uniqueKeysWithValues: SpecialMissionID.allCases.map {
            ($0, SpecialMissionProgress(mission: $0, missionUnlocked: $0 == .friendsOf10))
        })) { stored, _ in stored }
    }

    static func store(_ progress: [SpecialMissionID: SpecialMissionProgress], forKey key: String) {
        let storedProgress = Dictionary(uniqueKeysWithValues: progress.map { ($0.key.rawValue, $0.value) })
        guard let data = try? JSONEncoder().encode(storedProgress) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct SpecialMissionProblem {
    let prompt: String
    let result: Int
    let mode: GameMode
    let stage: DifficultyStage
    let role: MissionProblemRole
    let hint: String?

    init(
        prompt: String,
        result: Int,
        mode: GameMode,
        stage: DifficultyStage,
        role: MissionProblemRole = .strategyUseful,
        hint: String? = nil
    ) {
        self.prompt = prompt
        self.result = result
        self.mode = mode
        self.stage = stage
        self.role = role
        self.hint = hint
    }

    func guidedStep(for mission: SpecialMissionID) -> (prompt: String, answer: Int)? {
        guard role != .ordinary else { return nil }
        let operands = prompt.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        guard operands.count >= 2 else { return nil }
        let left = operands[0], right = operands[1]
        switch mission {
        case .friendsOf10:
            return prompt.contains("+ ?") ? ("10 − \(left) = ?", 10 - left) : ("\(left) + ? = 10", 10 - left)
        case .bridgingThrough10:
            return ("\(left) + ? = 10", 10 - left)
        case .doublesNearDoubles:
            return ("\(left) + \(left) = ?", left * 2)
        case .countingUp:
            let nextTen = min(left, ((right / 10) + 1) * 10)
            return ("\(right) + ? = \(nextTen)", nextTen - right)
        case .bridgeDownThrough10:
            let ten = (left / 10) * 10
            return ("\(left) − ? = \(ten)", left - ten)
        case .subtractTensOnes:
            let tens = (right / 10) * 10
            return ("\(left) − \(tens) = ?", left - tens)
        case .subtractionCompensation:
            let lower = (right / 10) * 10
            let rounded = lower > 0 && right - lower <= lower + 10 - right ? lower : lower + 10
            return ("\(left) − \(rounded) = ?", left - rounded)
        case .nineTrick:
            let rounded = right + 1
            return mode == .addition ? ("\(left) + \(rounded) = ?", left + rounded) : ("\(left) − \(rounded) = ?", left - rounded)
        }
    }

    func guidedFinish(for mission: SpecialMissionID) -> String {
        guard let step = guidedStep(for: mission) else { return prompt }
        let operands = prompt.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        let left = operands[0], right = operands[1]
        switch mission {
        case .friendsOf10: return prompt.contains("+ ?") ? prompt : "10 + \(right - step.answer) = ?"
        case .bridgingThrough10: return "10 + \(right - step.answer) = ?"
        case .doublesNearDoubles: return "\(step.answer) + \(right - left) = ?"
        case .countingUp: return "\(step.answer) + \(result - step.answer) = ?"
        case .bridgeDownThrough10: return "\(left - step.answer) − \(right - step.answer) = ?"
        case .subtractTensOnes: return "\(step.answer) − \(right % 10) = ?"
        case .subtractionCompensation:
            let correction = result - step.answer
            return "\(step.answer) \(correction >= 0 ? "+" : "−") \(abs(correction)) = ?"
        case .nineTrick: return "\(step.answer) \(mode == .addition ? "−" : "+") 1 = ?"
        }
    }

    func workedSolution(for mission: SpecialMissionID) -> String {
        let solved = prompt.replacingOccurrences(of: "?", with: String(result))
        guard let step = guidedStep(for: mission) else { return solved }
        let helping = step.prompt.replacingOccurrences(of: "?", with: String(step.answer))
        let finish = guidedFinish(for: mission).replacingOccurrences(of: "?", with: String(result))
        return helping + "\n" + finish
    }

    static func makeProblems(for mission: SpecialMissionID, phase: SpecialMissionPhase) -> [SpecialMissionProblem] {
        switch mission {
        case .friendsOf10:
            return friendsOf10(phase: phase)
        case .bridgingThrough10:
            return bridgingThrough10(phase: phase)
        case .doublesNearDoubles:
            return doublesNearDoubles(phase: phase)
        case .countingUp:
            return countingUp(phase: phase)
        case .bridgeDownThrough10:
            return bridgeDownThrough10(phase: phase)
        case .subtractTensOnes:
            return subtractTensOnes(phase: phase)
        case .subtractionCompensation:
            return subtractionCompensation(phase: phase)
        case .nineTrick:
            return nineTrick(phase: phase)
        }
    }

    private static func friendsOf10(phase: SpecialMissionPhase) -> [SpecialMissionProblem] {
        switch phase {
        case .discoverPattern:
            return [2, 8, 3, 7, 4, 6].map { bondProblem($0) }
        case .unlockStrategy:
            return [1, 9].map { bondProblem($0, hint: localized(english: "? + partner = 10", german: "? + Partner = 10")) }
        case .focusedPractice, .bossFight:
            return [6, 4, 8, 2, 7, 3, 9, 1, 5, 2].map { bondProblem($0) }
        case .transferChallenge:
            return [
                bondProblem(8),
                p(8, "+", 5, hint: thenHint("8 + 2 = 10", "+3")),
                p(4, "+", 3, role: .ordinary, hint: localized(english: "No 10 needed.", german: "Keine 10 noetig.")),
                p(7, "+", 6, hint: thenHint("7 + 3 = 10", "+3")),
                p(9, "+", 4, hint: thenHint("9 + 1 = 10", "+3")),
                p(5, "+", 2, role: .ordinary, hint: localized(english: "Small fact.", german: "Kleine Aufgabe.")),
                bondProblem(3),
                p(6, "+", 7, hint: thenHint("6 + 4 = 10", "+3"))
            ]
        }
    }

    private static func bridgingThrough10(phase: SpecialMissionPhase) -> [SpecialMissionProblem] {
        let focused = [(8, 5), (7, 6), (9, 8), (6, 7), (8, 6), (9, 5), (7, 8), (6, 9), (8, 7), (9, 4)]
        switch phase {
        case .discoverPattern:
            return [(8, 5), (7, 6), (9, 4), (8, 7), (6, 5), (9, 8)].map { bridgeProblem($0.0, $0.1) }
        case .unlockStrategy:
            return [(8, 5), (7, 6)].map { bridgeProblem($0.0, $0.1, guided: true) }
        case .focusedPractice, .bossFight:
            return focused.map { bridgeProblem($0.0, $0.1) }
        case .transferChallenge:
            return [
                bridgeProblem(8, 5),
                p(4, "+", 5, role: .ordinary, hint: localized(english: "This stays below 10.", german: "Das bleibt unter 10.")),
                bridgeProblem(7, 6),
                p(12, "+", 3, role: .ordinary, hint: localized(english: "Already past 10.", german: "Schon ueber 10.")),
                bridgeProblem(9, 8),
                p(20, "+", 7, role: .ordinary, hint: placeValueHint),
                bridgeProblem(6, 7),
                bridgeProblem(9, 5)
            ]
        }
    }

    private static func doublesNearDoubles(phase: SpecialMissionPhase) -> [SpecialMissionProblem] {
        let focused = [(6, 6), (7, 7), (8, 8), (7, 8), (8, 9), (6, 7), (5, 6), (9, 9), (9, 10), (4, 5)]
        switch phase {
        case .discoverPattern:
            return [(6, 6), (7, 7), (7, 8), (8, 8), (8, 9), (5, 6)].map { doubleProblem($0.0, $0.1) }
        case .unlockStrategy:
            return [(7, 8), (8, 9)].map { doubleProblem($0.0, $0.1, guided: true) }
        case .focusedPractice, .bossFight:
            return focused.map { doubleProblem($0.0, $0.1) }
        case .transferChallenge:
            return [
                doubleProblem(7, 8),
                p(3, "+", 8, role: .ordinary, hint: localized(english: "Not near twins.", german: "Keine Nachbar-Zwillinge.")),
                doubleProblem(8, 9),
                p(12, "+", 4, role: .ordinary, hint: localized(english: "Use tens and ones.", german: "Nutze Zehner und Einer.")),
                doubleProblem(6, 7),
                doubleProblem(9, 10),
                p(20, "+", 5, role: .ordinary, hint: placeValueHint),
                doubleProblem(4, 5)
            ]
        }
    }

    private static func countingUp(phase: SpecialMissionPhase) -> [SpecialMissionProblem] {
        let focused = [(13, 8), (15, 9), (12, 7), (14, 8), (42, 38), (31, 27), (16, 9), (52, 48), (18, 11), (73, 68)]
        switch phase {
        case .discoverPattern:
            return [(13, 8), (15, 9), (12, 7), (42, 38), (31, 27), (16, 9)].map { countUpProblem($0.0, $0.1) }
        case .unlockStrategy:
            return [(13, 8), (42, 38)].map { countUpProblem($0.0, $0.1, guided: true) }
        case .focusedPractice, .bossFight:
            return focused.map { countUpProblem($0.0, $0.1) }
        case .transferChallenge:
            return [
                countUpProblem(13, 8),
                p(9, "-", 4, role: .ordinary, hint: localized(english: "Small subtraction fact.", german: "Kleine Minusaufgabe.")),
                countUpProblem(42, 38),
                p(30, "-", 10, role: .ordinary, hint: localized(english: "Whole tens are direct.", german: "Ganze Zehner gehen direkt.")),
                countUpProblem(15, 9),
                countUpProblem(52, 48),
                p(44, "-", 2, role: .ordinary, hint: localized(english: "Take away 2.", german: "Ziehe 2 ab.")),
                countUpProblem(18, 11)
            ]
        }
    }

    private static func nineTrick(phase: SpecialMissionPhase) -> [SpecialMissionProblem] {
        let focused = [(24, 9, true), (45, 9, false), (36, 9, true), (52, 9, false), (18, 9, true), (67, 9, false), (41, 9, true), (83, 9, false)]
        switch phase {
        case .discoverPattern:
            return [(24, 9, true), (45, 9, false), (36, 9, true), (52, 9, false), (18, 9, true), (67, 9, false)].map { nineProblem($0.0, $0.1, isAddition: $0.2) }
        case .unlockStrategy:
            return [(24, 9, true), (45, 9, false)].map { nineProblem($0.0, $0.1, isAddition: $0.2, guided: true) }
        case .focusedPractice, .bossFight:
            return focused.map { nineProblem($0.0, $0.1, isAddition: $0.2) }
        case .transferChallenge:
            return [
                nineProblem(24, 9, isAddition: true),
                p(33, "+", 8, role: .ordinary, hint: localized(english: "This is not a 9 trick.", german: "Das ist kein 9er-Trick.")),
                nineProblem(45, 9, isAddition: false),
                p(58, "-", 7, role: .ordinary, hint: localized(english: "This is not a 9 trick.", german: "Das ist kein 9er-Trick.")),
                nineProblem(24, 19, isAddition: true),
                nineProblem(45, 19, isAddition: false),
                p(20, "+", 5, role: .ordinary, hint: placeValueHint),
                nineProblem(41, 9, isAddition: true)
            ]
        }
    }

    private static func bridgeDownThrough10(phase: SpecialMissionPhase) -> [SpecialMissionProblem] {
        let focused = [(13, 8), (12, 7), (14, 6), (15, 8), (16, 9), (11, 4), (17, 9), (18, 9), (42, 26), (53, 27)]
        switch phase {
        case .discoverPattern:
            return [(13, 8), (12, 7), (14, 6), (15, 8), (16, 9), (11, 4)].map { bridgeDownProblem($0.0, $0.1) }
        case .unlockStrategy:
            return [(13, 8), (42, 26)].map { bridgeDownProblem($0.0, $0.1, guided: true) }
        case .focusedPractice, .bossFight:
            return focused.map { bridgeDownProblem($0.0, $0.1) }
        case .transferChallenge:
            return [
                bridgeDownProblem(13, 8),
                p(9, "-", 4, role: .ordinary, hint: localized(english: "This stays below 10.", german: "Das bleibt unter 10.")),
                bridgeDownProblem(42, 26),
                p(30, "-", 10, role: .ordinary, hint: localized(english: "Whole tens are direct.", german: "Ganze Zehner gehen direkt.")),
                bridgeDownProblem(15, 8),
                bridgeDownProblem(53, 27),
                p(44, "-", 2, role: .ordinary, hint: localized(english: "Take away 2.", german: "Ziehe 2 ab.")),
                bridgeDownProblem(18, 9)
            ]
        }
    }

    private static func subtractTensOnes(phase: SpecialMissionPhase) -> [SpecialMissionProblem] {
        let focused = [(47, 23), (58, 34), (69, 25), (76, 42), (84, 31), (95, 54), (67, 26), (89, 45), (73, 21), (56, 32)]
        switch phase {
        case .discoverPattern:
            return [(47, 23), (58, 34), (69, 25), (76, 42), (84, 31), (67, 26)].map { splitSubtractProblem($0.0, $0.1) }
        case .unlockStrategy:
            return [(47, 23), (76, 42)].map { splitSubtractProblem($0.0, $0.1, guided: true) }
        case .focusedPractice, .bossFight:
            return focused.map { splitSubtractProblem($0.0, $0.1) }
        case .transferChallenge:
            return [
                splitSubtractProblem(47, 23),
                p(40, "-", 7, role: .ordinary, hint: localized(english: "No tens-and-ones split needed.", german: "Keine Zehner-Einer-Zerlegung noetig.")),
                splitSubtractProblem(76, 42),
                p(12, "-", 5, role: .ordinary, hint: localized(english: "Bridge through 10 instead.", german: "Nutze lieber den Weg ueber 10.")),
                splitSubtractProblem(89, 45),
                splitSubtractProblem(67, 26),
                p(20, "-", 5, role: .ordinary, hint: localized(english: "Small place-value fact.", german: "Kleine Stellenwertaufgabe.")),
                splitSubtractProblem(56, 32)
            ]
        }
    }

    private static func subtractionCompensation(phase: SpecialMissionPhase) -> [SpecialMissionProblem] {
        let focused = [(45, 19), (52, 8), (67, 11), (83, 29), (74, 18), (61, 9), (95, 39), (46, 21), (58, 12), (72, 28)]
        switch phase {
        case .discoverPattern:
            return [(45, 19), (52, 8), (67, 11), (83, 29), (74, 18), (61, 9)].map { subtractNearTenProblem($0.0, $0.1) }
        case .unlockStrategy:
            return [(45, 19), (52, 8)].map { subtractNearTenProblem($0.0, $0.1, guided: true) }
        case .focusedPractice, .bossFight:
            return focused.map { subtractNearTenProblem($0.0, $0.1) }
        case .transferChallenge:
            return [
                subtractNearTenProblem(45, 19),
                p(58, "-", 7, role: .ordinary, hint: localized(english: "This is not near a 10.", german: "Das liegt nicht nah an einem Zehner.")),
                subtractNearTenProblem(52, 8),
                p(44, "-", 22, role: .ordinary, hint: localized(english: "Tens and ones are cleaner.", german: "Zehner und Einer passen besser.")),
                subtractNearTenProblem(83, 29),
                subtractNearTenProblem(67, 11),
                p(30, "-", 10, role: .ordinary, hint: localized(english: "Already an easy 10.", german: "Schon ein leichter Zehner.")),
                subtractNearTenProblem(72, 28)
            ]
        }
    }

    static func easierRetryProblems(for mission: SpecialMissionID) -> [SpecialMissionProblem] {
        switch mission {
        case .friendsOf10:
            return [bondProblem(8), bondProblem(7), bondProblem(6)]
        case .bridgingThrough10:
            return [bridgeProblem(8, 5, guided: true), bridgeProblem(7, 6, guided: true)]
        case .doublesNearDoubles:
            return [doubleProblem(6, 6, guided: true), doubleProblem(7, 8, guided: true)]
        case .countingUp:
            return [countUpProblem(13, 8, guided: true), countUpProblem(15, 9, guided: true)]
        case .bridgeDownThrough10:
            return [bridgeDownProblem(13, 8, guided: true), bridgeDownProblem(12, 7, guided: true)]
        case .subtractTensOnes:
            return [splitSubtractProblem(47, 23, guided: true), splitSubtractProblem(58, 34, guided: true)]
        case .subtractionCompensation:
            return [subtractNearTenProblem(45, 19, guided: true), subtractNearTenProblem(52, 8, guided: true)]
        case .nineTrick:
            return [nineProblem(24, 9, isAddition: true, guided: true), nineProblem(45, 9, isAddition: false, guided: true)]
        }
    }

    private static func p(
        _ left: Int,
        _ symbol: String,
        _ right: Int,
        role: MissionProblemRole = .strategyUseful,
        hint: String? = nil
    ) -> SpecialMissionProblem {
        let mode: GameMode = symbol == "-" ? .subtraction : .addition
        let result = symbol == "-" ? left - right : left + right
        return SpecialMissionProblem(
            prompt: "\(left) \(symbol) \(right) = ?",
            result: result,
            mode: mode,
            stage: role == .ordinary ? .mixed : .crossing10,
            role: role,
            hint: hint
        )
    }

    private static func bondProblem(_ left: Int, hint: String? = nil) -> SpecialMissionProblem {
        SpecialMissionProblem(
            prompt: "\(left) + ? = 10",
            result: 10 - left,
            mode: .addition,
            stage: .complementsTo10,
            hint: hint ?? "\(left) + \(10 - left) = 10"
        )
    }

    private static func bridgeProblem(_ left: Int, _ right: Int, guided: Bool = false) -> SpecialMissionProblem {
        let toTen = 10 - left
        return p(left, "+", right, hint: guided ? thenHint("\(left) + \(toTen) = 10", "+\(right - toTen)") : "-> 10 -> \(left + right)")
    }

    private static func doubleProblem(_ left: Int, _ right: Int, guided: Bool = false) -> SpecialMissionProblem {
        let low = min(left, right)
        let high = max(left, right)
        let hint = low == high
            ? "\(low) + \(low)"
            : "\(low) + \(low) + \(high - low)"
        return p(left, "+", right, hint: guided ? hint : localized(english: "Twin helps.", german: "Zwilling hilft."))
    }

    private static func countUpProblem(_ left: Int, _ right: Int, guided: Bool = false) -> SpecialMissionProblem {
        let toNextTen = ((right + 9) / 10) * 10
        let firstJump = max(toNextTen - right, 0)
        let secondJump = left - toNextTen
        let hint = guided && secondJump > 0
            ? thenHint("\(right) -> \(toNextTen) (+\(firstJump))", "+\(secondJump)")
            : localized(english: "Distance = \(left - right)", german: "Abstand = \(left - right)")
        return p(left, "-", right, hint: hint)
    }

    private static func bridgeDownProblem(_ left: Int, _ right: Int, guided: Bool = false) -> SpecialMissionProblem {
        let landingTen = (left / 10) * 10
        let firstStep = left - landingTen
        let remaining = right - firstStep
        let hint = guided && remaining > 0
            ? thenHint("-\(firstStep) -> \(landingTen)", "-\(remaining)")
            : localized(english: "Land on \(landingTen), then finish.", german: "Lande bei \(landingTen), dann weiter.")
        return p(left, "-", right, hint: hint)
    }

    private static func splitSubtractProblem(_ left: Int, _ right: Int, guided: Bool = false) -> SpecialMissionProblem {
        let tens = (right / 10) * 10
        let ones = right - tens
        let afterTens = left - tens
        let hint = guided
            ? thenHint("-\(tens) = \(afterTens)", "-\(ones)")
            : localized(english: "Subtract tens, then ones.", german: "Erst Zehner, dann Einer abziehen.")
        return p(left, "-", right, hint: hint)
    }

    private static func subtractNearTenProblem(_ left: Int, _ right: Int, guided: Bool = false) -> SpecialMissionProblem {
        let lowerTen = (right / 10) * 10
        let upperTen = lowerTen + 10
        let neighbor = abs(right - lowerTen) <= abs(upperTen - right) && lowerTen > 0 ? lowerTen : upperTen
        let correction = neighbor - right
        let afterNeighbor = left - neighbor
        let correctionText = correction >= 0 ? "+\(correction)" : "\(correction)"
        let hint = guided
            ? thenHint("-\(neighbor) = \(afterNeighbor)", correctionText)
            : localized(english: "Use \(neighbor), then correct.", german: "Nutze \(neighbor), dann ausgleichen.")
        return p(left, "-", right, hint: hint)
    }

    private static func nineProblem(_ left: Int, _ amount: Int, isAddition: Bool, guided: Bool = false) -> SpecialMissionProblem {
        let symbol = isAddition ? "+" : "-"
        let hint: String
        if amount == 19 {
            hint = isAddition ? "+20, -1" : "-20, +1"
        } else {
            hint = isAddition ? "+10, -1" : "-10, +1"
        }
        return p(left, symbol, amount, hint: guided ? hint : hint)
    }

    private static var placeValueHint: String {
        localized(english: "Place value helps.", german: "Stellenwert hilft.")
    }

    private static func thenHint(_ first: String, _ second: String) -> String {
        localized(english: "\(first), then \(second)", german: "\(first), dann \(second)")
    }

    private static func localized(english: String, german: String) -> String {
        switch AppLanguage.storedMissionLanguage {
        case .english:
            return english
        case .german:
            return german
        }
    }
}

private enum MissionProblemRole {
    case strategyUseful
    case ordinary
}

private extension AppLanguage {
    static var storedMissionLanguage: AppLanguage {
        if let stored = UserDefaults.standard.string(forKey: "appLanguage"),
           let language = AppLanguage(rawValue: stored) {
            return language
        }
        return .english
    }
}

private extension SpecialMissionID {
    var defaultGameMode: GameMode {
        switch self {
        case .countingUp, .bridgeDownThrough10, .subtractTensOnes, .subtractionCompensation:
            return .subtraction
        case .friendsOf10, .bridgingThrough10, .doublesNearDoubles, .nineTrick:
            return .addition
        }
    }

    func localizedUnlockHint(language: AppLanguage) -> String {
        switch (language, self) {
        case (.english, .friendsOf10):
            return "? + partner = 10"
        case (.english, .bridgingThrough10):
            return "-> 10 ->"
        case (.english, .doublesNearDoubles):
            return "twin + 1"
        case (.english, .countingUp):
            return "small -> big"
        case (.english, .bridgeDownThrough10):
            return "first land on 10"
        case (.english, .subtractTensOnes):
            return "tens, then ones"
        case (.english, .subtractionCompensation):
            return "near 10, then correct"
        case (.english, .nineTrick):
            return "+/-10, then step back"
        case (.german, .friendsOf10):
            return "? + Partner = 10"
        case (.german, .bridgingThrough10):
            return "-> 10 ->"
        case (.german, .doublesNearDoubles):
            return "Zwilling + 1"
        case (.german, .countingUp):
            return "klein -> gross"
        case (.german, .bridgeDownThrough10):
            return "erst bis zur 10"
        case (.german, .subtractTensOnes):
            return "Zehner, dann Einer"
        case (.german, .subtractionCompensation):
            return "naher Zehner, dann Ausgleich"
        case (.german, .nineTrick):
            return "+/-10, dann zurueck"
        }
    }

    func strategyVisualization(for prompt: String, answer: Int, language: AppLanguage) -> String {
        switch self {
        case .friendsOf10:
            return "-> 10"
        case .bridgingThrough10:
            return "-> 10 -> \(answer)"
        case .doublesNearDoubles:
            return "\(max(answer - 1, 0)) + 1 = \(answer)"
        case .countingUp:
            switch language {
            case .english:
                return "Distance = \(answer)"
            case .german:
                return "Abstand = \(answer)"
            }
        case .bridgeDownThrough10:
            return prompt.contains("13") ? "13 - 3 = 10, then -5" : "land on 10, then finish"
        case .subtractTensOnes:
            return "subtract tens, then ones"
        case .subtractionCompensation:
            if prompt.contains("- 8") || prompt.contains("- 9") || prompt.contains("- 18") || prompt.contains("- 19") || prompt.contains("- 28") || prompt.contains("- 29") || prompt.contains("- 39") {
                return "-10/-20, then add back"
            }
            return "-10/-20, then correct"
        case .nineTrick:
            if prompt.contains("+") {
                return "+10, -1"
            }
            return "-10, +1"
        }
    }
}

private enum SpecialMissionRecommendationEngine {
    static func recommendation(
        from records: [AnalyticsRecord],
        missionEnabled: (SpecialMissionID) -> Bool
    ) -> SpecialMissionID? {
        let misses = records.filter { !$0.isCorrect }
        guard misses.count >= 2 else { return nil }

        let nineMisses = misses.filter { $0.problem.contains("+ 9") || $0.problem.contains("- 9") }
        if nineMisses.count >= 2, missionEnabled(.nineTrick) {
            return .nineTrick
        }

        let subtractionMisses = misses.filter { $0.mode == .subtraction }
        let subtractionNearTenMisses = subtractionMisses.filter { record in
            guard let amount = parsedOperands(from: record.problem).last else { return false }
            let remainder = amount % 10
            return [1, 2, 8, 9].contains(remainder)
        }
        if subtractionNearTenMisses.count >= 2, missionEnabled(.subtractionCompensation) {
            return .subtractionCompensation
        }

        let subtractionTwoDigitMisses = subtractionMisses.filter { record in
            let numbers = parsedOperands(from: record.problem)
            guard numbers.count >= 2 else { return false }
            return numbers[0] >= 40 && numbers[1] >= 20 && numbers[1] % 10 != 0 && numbers[0] % 10 >= numbers[1] % 10
        }
        if subtractionTwoDigitMisses.count >= 2, missionEnabled(.subtractTensOnes) {
            return .subtractTensOnes
        }

        let subtractionCrossingMisses = subtractionMisses.filter { record in
            let numbers = parsedOperands(from: record.problem)
            guard numbers.count >= 2 else { return false }
            return numbers[0] % 10 < numbers[1] % 10 || record.stage == .twoDigitWithCarryBorrow
        }
        if subtractionCrossingMisses.count >= 2, missionEnabled(.bridgeDownThrough10) {
            return .bridgeDownThrough10
        }

        if subtractionMisses.count >= 2, missionEnabled(.countingUp) {
            return .countingUp
        }

        let crossingMisses = misses.filter { $0.stage == .crossing10 || $0.stage == .complementsTo20 }
        if crossingMisses.count >= 2, missionEnabled(.bridgingThrough10) {
            return .bridgingThrough10
        }

        let complementMisses = misses.filter { $0.stage == .complementsTo10 || $0.problem.contains("? = 10") }
        if complementMisses.count >= 2, missionEnabled(.friendsOf10) {
            return .friendsOf10
        }

        let nearDoubleMisses = misses.filter { record in
            let numbers = record.problem
                .split(whereSeparator: { !$0.isNumber })
                .compactMap { Int($0) }
            guard numbers.count >= 2 else { return false }
            return abs(numbers[0] - numbers[1]) <= 1 && record.mode == .addition
        }
        if nearDoubleMisses.count >= 2, missionEnabled(.doublesNearDoubles) {
            return .doublesNearDoubles
        }

        return nil
    }

    private static func parsedOperands(from problem: String) -> [Int] {
        problem
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }
}

struct Explosion: Identifiable {
    let id: UUID
    let position: CGPoint
    var scale: Double
    var opacity: Double
}

struct Projectile: Identifiable {
    let id: UUID
    let startPosition: CGPoint
    let endPosition: CGPoint
    var currentPosition: CGPoint
    var progress: Double
    let speed: Double
    let kind: ProjectileKind
    let impact: ProjectileImpact
}

struct CelebrationEvent: Identifiable, Equatable {
    let id = UUID()
}

enum ProjectileKind {
    case playerShot
    case enemyShot
    case enemyDive
}

enum ProjectileImpact {
    case correctAnswer
    case playerHit
    case bossBlocked
    case bossDramaticShot
    case missionHit
}

enum GameMode: String, CaseIterable, Identifiable, Codable {
    case addition
    case subtraction
    case multiplication
    case division

    var id: String { rawValue }

    var title: String { title(in: .english) }

    func title(in language: AppLanguage) -> String {
        switch (language, self) {
        case (.english, .addition):
            return "Addition"
        case (.english, .subtraction):
            return "Subtraction"
        case (.english, .multiplication):
            return "Multiplication"
        case (.english, .division):
            return "Division"
        case (.german, .addition):
            return "Addition"
        case (.german, .subtraction):
            return "Subtraktion"
        case (.german, .multiplication):
            return "Multiplikation"
        case (.german, .division):
            return "Division"
        }
    }

    var symbol: String {
        switch self {
        case .addition:
            return "+"
        case .subtraction:
            return "-"
        case .multiplication:
            return "×"
        case .division:
            return "÷"
        }
    }
}

enum DifficultyStage: Codable {
    case singleDigit
    case complementsTo10
    case crossing10
    case complementsTo20
    case digitPlusWholeTens
    case doubleDigitPlusSingleNoCrossing
    case twoDigitNoCarryBorrow
    case twoDigitWithCarryBorrow
    case pattern
    case mixed
    case multiplicationIntro
    case multiplicationTable
    case multiplicationSwap
    case multiplicationMastered

    var isDifficult: Bool {
        switch self {
        case .twoDigitNoCarryBorrow, .twoDigitWithCarryBorrow, .pattern, .mixed, .multiplicationMastered:
            return true
        case .singleDigit, .complementsTo10, .crossing10, .complementsTo20, .digitPlusWholeTens, .doubleDigitPlusSingleNoCrossing, .multiplicationIntro, .multiplicationTable, .multiplicationSwap:
            return false
        }
    }

    var storageKey: String {
        switch self {
        case .singleDigit:
            return "singleDigit"
        case .complementsTo10:
            return "complementsTo10"
        case .crossing10:
            return "crossing10"
        case .complementsTo20:
            return "complementsTo20"
        case .digitPlusWholeTens:
            return "digitPlusWholeTens"
        case .doubleDigitPlusSingleNoCrossing:
            return "doubleDigitPlusSingleNoCrossing"
        case .twoDigitNoCarryBorrow:
            return "twoDigitNoCarryBorrow"
        case .twoDigitWithCarryBorrow:
            return "twoDigitWithCarryBorrow"
        case .pattern:
            return "pattern"
        case .mixed:
            return "mixed"
        case .multiplicationIntro:
            return "multiplicationIntro"
        case .multiplicationTable:
            return "multiplicationTable"
        case .multiplicationSwap:
            return "multiplicationSwap"
        case .multiplicationMastered:
            return "multiplicationMastered"
        }
    }
}

enum PatternPhase: Codable {
    case tensProgression
    case onesProgression
    case mixed

    var storageKey: String {
        switch self {
        case .tensProgression:
            return "tens"
        case .onesProgression:
            return "ones"
        case .mixed:
            return "mixed"
        }
    }
}

enum MultiplicationLearningPhase: String, Codable {
    case intro
    case fullTable
    case commutativeSwap
    case mastered

    var title: String {
        switch self {
        case .intro:
            return "First number facts"
        case .fullTable:
            return "Full Table"
        case .commutativeSwap:
            return "Swap Order"
        case .mastered:
            return "Mixed Mastery"
        }
    }
}

struct MultiplicationProgress: Codable {
    static let defaultTableSequence = [2, 3, 4, 5, 10, 6, 7, 8, 9]

    var tableSequence: [Int] = defaultTableSequence
    var currentTableIndex = 0
    var phase: MultiplicationLearningPhase = .intro
    var statsByTable: [String: MultiplicationTableStats] = [:]

    var currentTable: Int {
        guard !tableSequence.isEmpty else { return 2 }
        let index = min(currentTableIndex, tableSequence.count - 1)
        return tableSequence[index]
    }

    var currentStage: DifficultyStage {
        switch phase {
        case .intro:
            return .multiplicationIntro
        case .fullTable:
            return .multiplicationTable
        case .commutativeSwap:
            return .multiplicationSwap
        case .mastered:
            return .multiplicationMastered
        }
    }

    var availableTables: [Int] {
        if phase == .mastered {
            return tableSequence
        }

        return Array(tableSequence.prefix(max(currentTableIndex + 1, 1)))
    }

    var masteredTables: [Int] {
        if phase == .mastered {
            return tableSequence
        }

        guard currentTableIndex > 0 else { return [] }
        return Array(tableSequence.prefix(currentTableIndex))
    }

    mutating func recordAttempt(
        for table: Int,
        responseTimeMs: Int,
        isCorrect: Bool,
        includeSwapPhase: Bool
    ) -> Int? {
        let previousTable = currentTable
        var tableStats = stats(for: table)
        let phaseToRecord: MultiplicationLearningPhase = table == currentTable ? phase : .commutativeSwap
        tableStats.recordAttempt(
            in: phaseToRecord,
            responseTimeMs: responseTimeMs,
            isCorrect: isCorrect
        )
        statsByTable[storageKey(for: table)] = tableStats

        guard table == currentTable else { return nil }

        advanceIfNeeded(using: tableStats, includeSwapPhase: includeSwapPhase)
        return currentTable != previousTable ? currentTable : nil
    }

    private mutating func advanceIfNeeded(
        using tableStats: MultiplicationTableStats,
        includeSwapPhase: Bool
    ) {
        switch phase {
        case .intro:
            guard tableStats.intro.attempts >= 8,
                  tableStats.intro.accuracy >= 0.75 else { return }
            phase = .fullTable

        case .fullTable:
            guard tableStats.fullTable.attempts >= 12,
                  tableStats.fullTable.accuracy >= 0.75 else { return }
            phase = includeSwapPhase ? .commutativeSwap : nextPhaseAfterSwap()

        case .commutativeSwap:
            guard tableStats.swapOrder.attempts >= 6,
                  tableStats.swapOrder.accuracy >= 0.75,
                  tableStats.swapOrder.averageResponseTimeMs <= 5000 else { return }

            phase = nextPhaseAfterSwap()

        case .mastered:
            break
        }
    }

    private func stats(for table: Int) -> MultiplicationTableStats {
        statsByTable[storageKey(for: table)] ?? MultiplicationTableStats(table: table)
    }

    private func storageKey(for table: Int) -> String {
        "table-\(table)"
    }

    mutating func applyTableSequence(_ tables: [Int]) {
        tableSequence = tables.isEmpty ? [2] : tables
        currentTableIndex = min(currentTableIndex, tableSequence.count - 1)
    }

    mutating func skipSwapPhaseIfNeeded() {
        guard phase == .commutativeSwap else { return }
        phase = nextPhaseAfterSwap()
    }

    private mutating func nextPhaseAfterSwap() -> MultiplicationLearningPhase {
        if currentTableIndex < tableSequence.count - 1 {
            currentTableIndex += 1
            return .intro
        }

        return .mastered
    }

    static func loadStored(forKey key: String) -> MultiplicationProgress {
        guard let data = UserDefaults.standard.data(forKey: key),
              let progress = try? JSONDecoder().decode(MultiplicationProgress.self, from: data) else {
            return MultiplicationProgress()
        }

        return progress
    }

    static func store(_ progress: MultiplicationProgress, forKey key: String) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct MultiplicationTableStats: Codable {
    let table: Int
    var intro = MultiplicationPhaseStats()
    var fullTable = MultiplicationPhaseStats()
    var swapOrder = MultiplicationPhaseStats()

    mutating func recordAttempt(
        in phase: MultiplicationLearningPhase,
        responseTimeMs: Int,
        isCorrect: Bool
    ) {
        switch phase {
        case .intro:
            intro.recordAttempt(responseTimeMs: responseTimeMs, isCorrect: isCorrect)
        case .fullTable:
            fullTable.recordAttempt(responseTimeMs: responseTimeMs, isCorrect: isCorrect)
        case .commutativeSwap, .mastered:
            swapOrder.recordAttempt(responseTimeMs: responseTimeMs, isCorrect: isCorrect)
        }
    }
}

struct MultiplicationPhaseStats: Codable {
    var attempts = 0
    var correct = 0
    var recentResponseTimes: [Int] = []

    var accuracy: Double {
        guard attempts > 0 else { return 0 }
        return Double(correct) / Double(attempts)
    }

    var averageResponseTimeMs: Double {
        guard !recentResponseTimes.isEmpty else { return .infinity }
        return Double(recentResponseTimes.reduce(0, +)) / Double(recentResponseTimes.count)
    }

    mutating func recordAttempt(responseTimeMs: Int, isCorrect: Bool) {
        attempts += 1

        if isCorrect {
            correct += 1
        }

        recentResponseTimes.append(responseTimeMs)
        if recentResponseTimes.count > 12 {
            recentResponseTimes.removeFirst(recentResponseTimes.count - 12)
        }
    }
}

private struct SelectedProblemPresentation {
    let presentedStage: DifficultyStage
    let presentedPatternPhase: PatternPhase?
    let targetStage: DifficultyStage
    let targetPatternPhase: PatternPhase?
    let targetClusterKey: String
}

private struct MultiplicationFact: Hashable {
    let table: Int
    let factor: Int
    let reversed: Bool

    var prompt: String {
        reversed ? "\(factor) × \(table) = ?" : "\(table) × \(factor) = ?"
    }

    var divisionPrompt: String {
        "\(table * factor) ÷ \(table) = ?"
    }
}

struct AdaptiveLearningProgress: Codable {
    var stageIndexByMode: [String: Int] = [:]
    var clusterStats: [String: AdaptiveClusterStats] = [:]
    var remediationByMode: [String: RemediationFocus] = [:]

    func stageIndex(for mode: GameMode) -> Int {
        stageIndexByMode[mode.rawValue] ?? 0
    }

    mutating func setStageIndex(_ index: Int, for mode: GameMode) {
        stageIndexByMode[mode.rawValue] = max(index, 0)
    }

    mutating func clampStageIndex(for mode: GameMode, maximum: Int) {
        let clampedIndex = min(max(stageIndex(for: mode), 0), max(maximum, 0))
        setStageIndex(clampedIndex, for: mode)
    }

    func remediation(for mode: GameMode) -> RemediationFocus? {
        remediationByMode[mode.rawValue]
    }

    mutating func setRemediation(_ focus: RemediationFocus?, for mode: GameMode) {
        remediationByMode[mode.rawValue] = focus
    }

    mutating func recordAttempt(for clusterKey: String, responseTimeMs: Int, isCorrect: Bool) {
        var stats = clusterStats[clusterKey] ?? AdaptiveClusterStats()
        stats.recordAttempt(responseTimeMs: responseTimeMs, isCorrect: isCorrect)
        clusterStats[clusterKey] = stats
    }

    func stats(for clusterKey: String) -> AdaptiveClusterStats? {
        clusterStats[clusterKey]
    }

    static func loadStored(forKey key: String) -> AdaptiveLearningProgress {
        guard let data = UserDefaults.standard.data(forKey: key),
              let progress = try? JSONDecoder().decode(AdaptiveLearningProgress.self, from: data) else {
            return AdaptiveLearningProgress()
        }

        return progress
    }

    static func store(_ progress: AdaptiveLearningProgress, forKey key: String) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct AdaptiveClusterStats: Codable {
    var recentResults: [Bool] = []
    var recentResponseTimes: [Int] = []

    var attempts: Int {
        recentResults.count
    }

    var accuracy: Double {
        guard !recentResults.isEmpty else { return 0 }
        return Double(recentResults.filter { $0 }.count) / Double(recentResults.count)
    }

    var isStruggling: Bool {
        guard attempts >= 3 else { return false }
        let recentSlice = Array(recentResults.suffix(5))
        let missCount = recentSlice.filter { !$0 }.count
        return accuracy < 0.65 || missCount >= 2
    }

    var isConfident: Bool {
        attempts >= 6 && accuracy >= 0.85
    }

    var isPromotionReady: Bool {
        guard attempts >= 8 else { return false }
        let recentSlice = Array(recentResults.suffix(8))
        let recentAccuracy = Double(recentSlice.filter { $0 }.count) / Double(recentSlice.count)
        return accuracy >= 0.78 && recentAccuracy >= 0.75
    }

    var isRegressionReady: Bool {
        guard attempts >= 5 else { return false }
        let recentSlice = Array(recentResults.suffix(5))
        let missCount = recentSlice.filter { !$0 }.count
        return accuracy < 0.60 || missCount >= 3
    }

    mutating func recordAttempt(responseTimeMs: Int, isCorrect: Bool) {
        recentResults.append(isCorrect)
        if recentResults.count > 12 {
            recentResults.removeFirst(recentResults.count - 12)
        }

        recentResponseTimes.append(responseTimeMs)
        if recentResponseTimes.count > 12 {
            recentResponseTimes.removeFirst(recentResponseTimes.count - 12)
        }
    }
}

struct RemediationFocus: Codable {
    let targetClusterKey: String
    let presentedStage: DifficultyStage
    let presentedPatternPhase: PatternPhase?
    var remainingBoostedProblems: Int = 2
    var remainingWindowProblems: Int = 5

    var isActive: Bool {
        remainingBoostedProblems > 0 && remainingWindowProblems > 0
    }

    func shouldUseNow() -> Bool {
        guard isActive else { return false }
        if remainingBoostedProblems >= remainingWindowProblems {
            return true
        }

        return Double.random(in: 0...1) <= (Double(remainingBoostedProblems) / Double(remainingWindowProblems))
    }

    mutating func consumeSlot(useRemediation: Bool) {
        remainingWindowProblems = max(remainingWindowProblems - 1, 0)
        if useRemediation {
            remainingBoostedProblems = max(remainingBoostedProblems - 1, 0)
        }
    }
}

struct AnalyticsRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let mode: GameMode
    let stage: DifficultyStage
    let patternPhase: PatternPhase?
    let problem: String
    let correctAnswer: Int
    let chosenAnswer: Int
    let isCorrect: Bool
    let wasRetry: Bool
    let responseTimeMs: Int
    var measurementVersion: Int?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        mode: GameMode,
        stage: DifficultyStage,
        patternPhase: PatternPhase?,
        problem: String,
        correctAnswer: Int,
        chosenAnswer: Int,
        isCorrect: Bool,
        wasRetry: Bool,
        responseTimeMs: Int
    ) {
        self.measurementVersion = 2
        self.id = id
        self.timestamp = timestamp
        self.mode = mode
        self.stage = stage
        self.patternPhase = patternPhase
        self.problem = problem
        self.correctAnswer = correctAnswer
        self.chosenAnswer = chosenAnswer
        self.isCorrect = isCorrect
        self.wasRetry = wasRetry
        self.responseTimeMs = responseTimeMs
    }

    static func loadStored(forKey key: String) -> [AnalyticsRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([AnalyticsRecord].self, from: data) else {
            return []
        }
        return records
    }

    static func store(_ records: [AnalyticsRecord], forKey key: String) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct FeedbackPracticeSession {
    let record: AnalyticsRecord
    let problems: [ArithmeticProblem]
    var completed = 0
    var firstTryCorrect = 0
    var currentProblemHadError = false
}

struct FeedbackPracticeResult: Equatable {
    let problem: String
    let basePoints: Int
    let awardedPoints: Int
    let firstTryCorrect: Int
    let problemCount: Int
}

struct AnalyticsStageSummary: Identifiable {
    let id: String
    let title: String
    let accuracy: Double
    let averageResponseTimeMs: Double
    let retrySuccessRate: Double
    let attempts: Int
    let feedbackTarget: AnalyticsRecord?
    let correctFirstAttempts: Int
    let retryAttempts: Int
    let previousAccuracy: Double?
}

private struct AnalyticsEngine {
    static let minimumAttemptsForSummary = 4

    let records: [AnalyticsRecord]

    func stageSummaries(in language: AppLanguage) -> [AnalyticsStageSummary] {
        let buckets = stageBuckets

        return AnalyticsBucketKey.displayOrder.compactMap { key in
            guard let history = buckets[key] else { return nil }
            let firstAttempts = history.filter { !$0.wasRetry }
            guard firstAttempts.count >= Self.minimumAttemptsForSummary else { return nil }
            let recent = Array(firstAttempts.suffix(20))
            let bucketRecords = history.filter { $0.timestamp >= recent[0].timestamp }
            let previous = Array(firstAttempts.dropLast(recent.count).suffix(20))
            let correctCount = recent.filter(\.isCorrect).count
            let retryRecords = bucketRecords.filter(\.wasRetry)
            let retrySuccessCount = retryRecords.filter(\.isCorrect).count
            let averageResponseTime = Double(recent.map(\.responseTimeMs).reduce(0, +)) / Double(recent.count)
            let retrySuccessRate = retryRecords.isEmpty ? 0 : Double(retrySuccessCount) / Double(retryRecords.count)
            let feedbackTarget = bucketRecords.reversed().first { !$0.isCorrect } ??
                bucketRecords.max(by: { $0.responseTimeMs < $1.responseTimeMs })

            return AnalyticsStageSummary(
                id: key.id,
                title: key.title(in: language),
                accuracy: Double(correctCount) / Double(recent.count),
                averageResponseTimeMs: averageResponseTime,
                retrySuccessRate: retrySuccessRate,
                attempts: recent.count,
                feedbackTarget: feedbackTarget,
                correctFirstAttempts: correctCount,
                retryAttempts: retryRecords.count,
                previousAccuracy: previous.count >= 6 && recent.count >= 6
                    ? Double(previous.filter(\.isCorrect).count) / Double(previous.count) : nil
            )
        }
    }

    private var stageBuckets: [AnalyticsBucketKey: [AnalyticsRecord]] {
        Dictionary(grouping: records.filter { $0.measurementVersion == 2 }) { AnalyticsBucketKey(record: $0) }
    }
}

private enum AnalyticsBucketCategory: Hashable {
    case singleDigit
    case complementsTo10
    case crossing10
    case complementsTo20
    case digitPlusWholeTens
    case doubleDigitPlusSingleNoCrossing
    case twoDigitNoCarryBorrow
    case twoDigitWithCarryBorrow
    case patternTens
    case patternOnes
    case patternMixed
    case mixed
    case multiplicationIntro
    case multiplicationTable
    case multiplicationSwap
    case multiplicationMastered
}

private struct AnalyticsBucketKey: Hashable {
    let mode: GameMode
    let category: AnalyticsBucketCategory

    init(mode: GameMode, category: AnalyticsBucketCategory) {
        self.mode = mode
        self.category = category
    }

    init(record: AnalyticsRecord) {
        mode = record.mode

        switch record.stage {
        case .pattern:
            switch record.patternPhase ?? .mixed {
            case .tensProgression:
                category = .patternTens
            case .onesProgression:
                category = .patternOnes
            case .mixed:
                category = .patternMixed
            }
        case .singleDigit:
            category = .singleDigit
        case .complementsTo10:
            category = .complementsTo10
        case .crossing10:
            category = .crossing10
        case .complementsTo20:
            category = .complementsTo20
        case .digitPlusWholeTens:
            category = .digitPlusWholeTens
        case .doubleDigitPlusSingleNoCrossing:
            category = .doubleDigitPlusSingleNoCrossing
        case .twoDigitNoCarryBorrow:
            category = .twoDigitNoCarryBorrow
        case .twoDigitWithCarryBorrow:
            category = .twoDigitWithCarryBorrow
        case .mixed:
            category = .mixed
        case .multiplicationIntro:
            category = .multiplicationIntro
        case .multiplicationTable:
            category = .multiplicationTable
        case .multiplicationSwap:
            category = .multiplicationSwap
        case .multiplicationMastered:
            category = .multiplicationMastered
        }
    }

    var id: String {
        "\(mode.rawValue)-\(category.title)"
    }

    var title: String {
        "\(mode.title): \(category.title)"
    }

    func title(in language: AppLanguage) -> String {
        let skill: String
        switch (mode, category, language) {
        case (.subtraction, .digitPlusWholeTens, .english): skill = "Subtracting ones to reach a ten"
        case (.subtraction, .digitPlusWholeTens, .german): skill = "Einer bis zum Zehner abziehen"
        case (.subtraction, .doubleDigitPlusSingleNoCrossing, .english): skill = "Subtracting ones without crossing a ten"
        case (.subtraction, .doubleDigitPlusSingleNoCrossing, .german): skill = "Einer ohne Zehnerübergang abziehen"
        default: skill = category.title(in: language)
        }
        return "\(mode.title(in: language)): \(skill)"
    }

    static let displayOrder: [AnalyticsBucketKey] = [
        .init(mode: .addition, category: .singleDigit),
        .init(mode: .addition, category: .complementsTo10),
        .init(mode: .addition, category: .crossing10),
        .init(mode: .addition, category: .complementsTo20),
        .init(mode: .addition, category: .digitPlusWholeTens),
        .init(mode: .addition, category: .doubleDigitPlusSingleNoCrossing),
        .init(mode: .addition, category: .twoDigitNoCarryBorrow),
        .init(mode: .addition, category: .twoDigitWithCarryBorrow),
        .init(mode: .addition, category: .patternTens),
        .init(mode: .addition, category: .patternOnes),
        .init(mode: .addition, category: .patternMixed),
        .init(mode: .addition, category: .mixed),
        .init(mode: .subtraction, category: .singleDigit),
        .init(mode: .subtraction, category: .complementsTo10),
        .init(mode: .subtraction, category: .crossing10),
        .init(mode: .subtraction, category: .complementsTo20),
        .init(mode: .subtraction, category: .digitPlusWholeTens),
        .init(mode: .subtraction, category: .doubleDigitPlusSingleNoCrossing),
        .init(mode: .subtraction, category: .twoDigitNoCarryBorrow),
        .init(mode: .subtraction, category: .twoDigitWithCarryBorrow),
        .init(mode: .subtraction, category: .patternTens),
        .init(mode: .subtraction, category: .patternOnes),
        .init(mode: .subtraction, category: .patternMixed),
        .init(mode: .subtraction, category: .mixed),
        .init(mode: .multiplication, category: .multiplicationIntro),
        .init(mode: .multiplication, category: .multiplicationTable),
        .init(mode: .multiplication, category: .multiplicationSwap),
        .init(mode: .multiplication, category: .multiplicationMastered),
        .init(mode: .division, category: .multiplicationIntro),
        .init(mode: .division, category: .multiplicationTable),
        .init(mode: .division, category: .multiplicationSwap),
        .init(mode: .division, category: .multiplicationMastered)
    ]
}

private extension AnalyticsBucketCategory {
    var title: String {
        title(in: .english)
    }

    func title(in language: AppLanguage) -> String {
        switch (language, self) {
        case (.english, .singleDigit):
            return "Small numbers"
        case (.english, .complementsTo10):
            return "Missing numbers to 10"
        case (.english, .crossing10):
            return "Crossing 10"
        case (.english, .complementsTo20):
            return "Missing numbers to 20"
        case (.english, .digitPlusWholeTens):
            return "Adding whole tens"
        case (.english, .doubleDigitPlusSingleNoCrossing):
            return "Adding ones without crossing a ten"
        case (.english, .twoDigitNoCarryBorrow):
            return "Two-digit numbers without crossing a ten"
        case (.english, .twoDigitWithCarryBorrow):
            return "Two-digit numbers across tens"
        case (.english, .patternTens):
            return "Pattern: Tens Progression"
        case (.english, .patternOnes):
            return "Pattern: Ones Progression"
        case (.english, .patternMixed):
            return "Pattern: Mixed"
        case (.english, .mixed):
            return "Mixed Advanced"
        case (.english, .multiplicationIntro):
            return "First number facts"
        case (.english, .multiplicationTable):
            return "Full Table"
        case (.english, .multiplicationSwap):
            return "Swap Order"
        case (.english, .multiplicationMastered):
            return "Mixed Facts"
        case (.german, .singleDigit):
            return "Einstellig"
        case (.german, .complementsTo10):
            return "Ergänzungen bis 10"
        case (.german, .crossing10):
            return "Über die 10"
        case (.german, .complementsTo20):
            return "Ergänzungen bis 20"
        case (.german, .digitPlusWholeTens):
            return "Volle Zehner addieren"
        case (.german, .doubleDigitPlusSingleNoCrossing):
            return "Einer ohne Zehnerübergang addieren"
        case (.german, .twoDigitNoCarryBorrow):
            return "Zweistellig ohne Übertrag"
        case (.german, .twoDigitWithCarryBorrow):
            return "Zweistellig mit Übertrag"
        case (.german, .patternTens):
            return "Muster: Zehnerfolge"
        case (.german, .patternOnes):
            return "Muster: Einerfolge"
        case (.german, .patternMixed):
            return "Muster: Gemischt"
        case (.german, .mixed):
            return "Fortgeschritten gemischt"
        case (.german, .multiplicationIntro):
            return "Erste Aufgaben"
        case (.german, .multiplicationTable):
            return "Ganze Reihe"
        case (.german, .multiplicationSwap):
            return "Faktorentausch"
        case (.german, .multiplicationMastered):
            return "Gemischte Aufgaben"
        }
    }

}

enum VehicleType: String, CaseIterable, Identifiable {
    case jet
    case tank
    case unicorn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jet:
            return "Jet"
        case .tank:
            return "Tank"
        case .unicorn:
            return "Unicorn"
        }
    }
}

struct ArithmeticProblem {
    let left: Int
    let right: Int
    let result: Int
    let prompt: String
    let multiplicationTable: Int?
    let multiplicationFactor: Int?

    static func standard(
        left: Int,
        symbol: String,
        right: Int,
        result: Int,
        multiplicationTable: Int? = nil,
        multiplicationFactor: Int? = nil
    ) -> ArithmeticProblem {
        ArithmeticProblem(
            left: left,
            right: right,
            result: result,
            prompt: "\(left) \(symbol) \(right) = ?",
            multiplicationTable: multiplicationTable,
            multiplicationFactor: multiplicationFactor
        )
    }

    static func custom(
        prompt: String,
        result: Int,
        multiplicationTable: Int? = nil,
        multiplicationFactor: Int? = nil
    ) -> ArithmeticProblem {
        ArithmeticProblem(
            left: 0,
            right: 0,
            result: result,
            prompt: prompt,
            multiplicationTable: multiplicationTable,
            multiplicationFactor: multiplicationFactor
        )
    }
}
