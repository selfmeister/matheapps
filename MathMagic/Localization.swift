import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english
    case german

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .english:
            return "EN"
        case .german:
            return "DE"
        }
    }

    var displayTitle: String {
        switch self {
        case .english:
            return "English"
        case .german:
            return "Deutsch"
        }
    }
}

final class AppSettings: ObservableObject {
    private static let languageKey = "appLanguage"
    private static let curriculumSettingsKey = "curriculumSettings"
    private static let soundEnabledKey = "soundEnabled"
    private static let bossShootingEnabledKey = "bossShootingEnabled"
    private static let reduceMotionEffectsKey = "reduceMotionEffects"
    private static let highContrastModeKey = "highContrastMode"
    private static let largeAnswerTextKey = "largeAnswerText"
    private static let specialMissionsEnabledKey = "specialMissionsEnabled"
    private static let automaticMissionSuggestionsKey = "automaticMissionSuggestions"
    private static let enabledSpecialMissionIDsKey = "enabledSpecialMissionIDs"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
        }
    }

    @Published var curriculumSettings: CurriculumSettings {
        didSet {
            let normalizedSettings = curriculumSettings.normalized
            if normalizedSettings != curriculumSettings {
                curriculumSettings = normalizedSettings
                return
            }

            guard let data = try? JSONEncoder().encode(curriculumSettings) else { return }
            UserDefaults.standard.set(data, forKey: Self.curriculumSettingsKey)
        }
    }

    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: Self.soundEnabledKey)
        }
    }

    @Published var bossShootingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(bossShootingEnabled, forKey: Self.bossShootingEnabledKey)
        }
    }

    @Published var reduceMotionEffects: Bool {
        didSet {
            UserDefaults.standard.set(reduceMotionEffects, forKey: Self.reduceMotionEffectsKey)
        }
    }

    @Published var highContrastMode: Bool {
        didSet {
            UserDefaults.standard.set(highContrastMode, forKey: Self.highContrastModeKey)
        }
    }

    @Published var largeAnswerText: Bool {
        didSet {
            UserDefaults.standard.set(largeAnswerText, forKey: Self.largeAnswerTextKey)
        }
    }

    @Published var specialMissionsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(specialMissionsEnabled, forKey: Self.specialMissionsEnabledKey)
        }
    }

    @Published var automaticMissionSuggestions: Bool {
        didSet {
            UserDefaults.standard.set(automaticMissionSuggestions, forKey: Self.automaticMissionSuggestionsKey)
        }
    }

    @Published var enabledSpecialMissionIDs: Set<SpecialMissionID> {
        didSet {
            UserDefaults.standard.set(
                enabledSpecialMissionIDs.map(\.rawValue),
                forKey: Self.enabledSpecialMissionIDsKey
            )
        }
    }

    init() {
        if let stored = UserDefaults.standard.string(forKey: Self.languageKey),
           let language = AppLanguage(rawValue: stored) {
            self.language = language
        } else {
            self.language = Locale.current.language.languageCode?.identifier == "de" ? .german : .english
        }

        if let data = UserDefaults.standard.data(forKey: Self.curriculumSettingsKey),
           let settings = try? JSONDecoder().decode(CurriculumSettings.self, from: data) {
            self.curriculumSettings = settings.normalized
        } else {
            self.curriculumSettings = .default
        }

        self.soundEnabled = UserDefaults.standard.object(forKey: Self.soundEnabledKey) as? Bool ?? true
        self.bossShootingEnabled = UserDefaults.standard.object(forKey: Self.bossShootingEnabledKey) as? Bool ?? true
        self.reduceMotionEffects = UserDefaults.standard.bool(forKey: Self.reduceMotionEffectsKey)
        self.highContrastMode = UserDefaults.standard.bool(forKey: Self.highContrastModeKey)
        self.largeAnswerText = UserDefaults.standard.bool(forKey: Self.largeAnswerTextKey)
        self.specialMissionsEnabled = UserDefaults.standard.object(forKey: Self.specialMissionsEnabledKey) as? Bool ?? true
        self.automaticMissionSuggestions = UserDefaults.standard.object(forKey: Self.automaticMissionSuggestionsKey) as? Bool ?? true
        if let storedIDs = UserDefaults.standard.stringArray(forKey: Self.enabledSpecialMissionIDsKey) {
            let missions = storedIDs.compactMap(SpecialMissionID.init(rawValue:))
            self.enabledSpecialMissionIDs = missions.isEmpty ? Set(SpecialMissionID.allCases) : Set(missions)
        } else {
            self.enabledSpecialMissionIDs = Set(SpecialMissionID.allCases)
        }
    }

    func setLearningProfile(_ profile: LearningProfile) {
        curriculumSettings = CurriculumSettings.preset(profile).normalized
    }

    func updateCurriculum(_ update: (inout CurriculumSettings) -> Void) {
        var updated = curriculumSettings
        update(&updated)
        updated.learningProfile = .custom
        curriculumSettings = updated.normalized
    }

    var accessibilityOptions: GameAccessibilityOptions {
        GameAccessibilityOptions(
            reduceMotionEffects: reduceMotionEffects,
            highContrastMode: highContrastMode,
            largeAnswerText: largeAnswerText
        )
    }

    func isSpecialMissionEnabled(_ mission: SpecialMissionID) -> Bool {
        specialMissionsEnabled && enabledSpecialMissionIDs.contains(mission)
    }

    func setSpecialMission(_ mission: SpecialMissionID, enabled: Bool) {
        if enabled {
            enabledSpecialMissionIDs.insert(mission)
        } else {
            enabledSpecialMissionIDs.remove(mission)
        }
    }
}

struct GameAccessibilityOptions: Equatable {
    var reduceMotionEffects: Bool
    var highContrastMode: Bool
    var largeAnswerText: Bool
}

enum SettingsHelpTopic: String, Identifiable {
    case learningProfile
    case arithmeticFocus
    case multiplicationDivision
    case specialMissions
    case accessibility

    var id: String { rawValue }
}

enum SpecialMissionID: String, CaseIterable, Identifiable, Codable {
    case friendsOf10
    case bridgingThrough10
    case doublesNearDoubles
    case countingUp
    case nineTrick

    var id: String { rawValue }

    var unlockRank: Int {
        switch self {
        case .friendsOf10:
            return 0
        case .bridgingThrough10:
            return 1
        case .doublesNearDoubles:
            return 2
        case .countingUp:
            return 3
        case .nineTrick:
            return 4
        }
    }

    var badgeSymbol: String {
        switch self {
        case .friendsOf10:
            return "10.circle.fill"
        case .bridgingThrough10:
            return "arrow.triangle.turn.up.right.circle.fill"
        case .doublesNearDoubles:
            return "equal.circle.fill"
        case .countingUp:
            return "arrow.up.forward.circle.fill"
        case .nineTrick:
            return "9.circle.fill"
        }
    }
}

struct AppCopy {
    let language: AppLanguage

    var chooseModeSubtitle: String {
        switch language {
        case .english:
            return "Choose your mode, then start the mission."
        case .german:
            return "Wähle deinen Modus und starte dann die Mission."
        }
    }

    func score(_ score: Int) -> String {
        switch language {
        case .english:
            return "Score: \(score)"
        case .german:
            return "Punkte: \(score)"
        }
    }

    func finalScore(_ score: Int) -> String {
        switch language {
        case .english:
            return "Final Score: \(score)"
        case .german:
            return "Endpunktzahl: \(score)"
        }
    }

    func roundAccuracy(correct: Int, attempts: Int) -> String {
        let percentage = attempts > 0 ? Int((Double(correct) / Double(attempts) * 100).rounded()) : 0

        switch language {
        case .english:
            return "Correct answers: \(correct) of \(attempts) (\(percentage)%)"
        case .german:
            return "Richtige Antworten: \(correct) von \(attempts) (\(percentage)%)"
        }
    }

    func highScore(_ score: Int) -> String {
        switch language {
        case .english:
            return "High Score: \(score)"
        case .german:
            return "Highscore: \(score)"
        }
    }

    func lives(_ count: Int) -> String {
        switch language {
        case .english:
            return "Lives: \(count)"
        case .german:
            return "Leben: \(count)"
        }
    }

    var gameOver: String {
        switch language {
        case .english:
            return "Game Over!"
        case .german:
            return "Spiel vorbei!"
        }
    }

    var playAgain: String {
        switch language {
        case .english:
            return "Play Again"
        case .german:
            return "Nochmal spielen"
        }
    }

    var startGame: String {
        switch language {
        case .english:
            return "Start Game"
        case .german:
            return "Spiel starten"
        }
    }

    var mode: String {
        switch language {
        case .english:
            return "Mode"
        case .german:
            return "Modus"
        }
    }

    var vehicle: String {
        switch language {
        case .english:
            return "Vehicle"
        case .german:
            return "Fahrzeug"
        }
    }

    var languageTitle: String {
        switch language {
        case .english:
            return "Language"
        case .german:
            return "Sprache"
        }
    }

    var analyticsTitle: String {
        switch language {
        case .english:
            return "Analytics"
        case .german:
            return "Analyse"
        }
    }

    var suggestions: String {
        switch language {
        case .english:
            return "Suggestions"
        case .german:
            return "Hinweise"
        }
    }

    var settings: String {
        switch language {
        case .english:
            return "Settings"
        case .german:
            return "Einstellungen"
        }
    }

    var parentTeacherGuide: String {
        switch language {
        case .english:
            return "Parents & Teachers"
        case .german:
            return "Eltern & Lehrkraefte"
        }
    }

    var parentTeacherGuideIntro: String {
        switch language {
        case .english:
            return "A quick overview of what the settings and modes do."
        case .german:
            return "Ein kurzer Ueberblick ueber Einstellungen und Spielmodi."
        }
    }

    var gameModesTitle: String {
        switch language {
        case .english:
            return "Game modes"
        case .german:
            return "Spielmodi"
        }
    }

    var settingsHelpTitle: String {
        switch language {
        case .english:
            return "Settings help"
        case .german:
            return "Hilfe zu Einstellungen"
        }
    }

    var settingsHelpFooter: String {
        switch language {
        case .english:
            return "Tap a ? for a short explanation."
        case .german:
            return "Tippe auf ?, um eine kurze Erklaerung zu sehen."
        }
    }

    var learningProfile: String {
        switch language {
        case .english:
            return "Learning Profile"
        case .german:
            return "Lernprofil"
        }
    }

    var arithmetic: String {
        switch language {
        case .english:
            return "Addition & Subtraction"
        case .german:
            return "Addition & Subtraktion"
        }
    }

    var multiplication: String {
        switch language {
        case .english:
            return "Multiplication & Division"
        case .german:
            return "Multiplikation & Division"
        }
    }

    var arithmeticFocus: String {
        switch language {
        case .english:
            return "Arithmetic Focus"
        case .german:
            return "Rechenfokus"
        }
    }

    var includeBasicReview: String {
        switch language {
        case .english:
            return "Include basic review"
        case .german:
            return "Einfache Wiederholung einbeziehen"
        }
    }

    var multiplicationTablesTitle: String {
        switch language {
        case .english:
            return "Tables"
        case .german:
            return "Reihen"
        }
    }

    var multiplicationFactorsTitle: String {
        switch language {
        case .english:
            return "Factors"
        case .german:
            return "Faktoren"
        }
    }

    var reversedFacts: String {
        switch language {
        case .english:
            return "Include reversed facts"
        case .german:
            return "Vertauschte Aufgaben einbeziehen"
        }
    }

    var settingsSummaryTitle: String {
        switch language {
        case .english:
            return "Active math path"
        case .german:
            return "Aktiver Lernweg"
        }
    }

    var settingsFooter: String {
        switch language {
        case .english:
            return "Choose a preset for a quick age-based setup, or tweak the math path yourself."
        case .german:
            return "Wähle ein Profil für eine schnelle altersgerechte Einstellung oder passe den Lernweg selbst an."
        }
    }

    var gameOptions: String {
        switch language {
        case .english:
            return "Game Options"
        case .german:
            return "Spieloptionen"
        }
    }

    var soundEffects: String {
        switch language {
        case .english:
            return "Sound effects"
        case .german:
            return "Soundeffekte"
        }
    }

    var bossShooting: String {
        switch language {
        case .english:
            return "Boss shooting effects"
        case .german:
            return "Schusseffekte des Bosses"
        }
    }

    var accessibility: String {
        switch language {
        case .english:
            return "Accessibility"
        case .german:
            return "Barrierefreiheit"
        }
    }

    var reduceMotionEffects: String {
        switch language {
        case .english:
            return "Reduce motion and flashes"
        case .german:
            return "Bewegung und Blitze reduzieren"
        }
    }

    var highContrastMode: String {
        switch language {
        case .english:
            return "High contrast answers"
        case .german:
            return "Antworten mit hohem Kontrast"
        }
    }

    var largeAnswerText: String {
        switch language {
        case .english:
            return "Larger answer text"
        case .german:
            return "Groessere Antwortzahlen"
        }
    }

    var accessibilityFooter: String {
        switch language {
        case .english:
            return "These options can make the game calmer and easier to read for players who need it."
        case .german:
            return "Diese Optionen machen das Spiel ruhiger und besser lesbar, wenn ein Kind das braucht."
        }
    }

    var specialMissions: String {
        switch language {
        case .english:
            return "Special Missions"
        case .german:
            return "Spezialmissionen"
        }
    }

    var specialMissionsGuide: String {
        switch language {
        case .english:
            return "Short strategy missions show a mental math idea, then let the child practice it in the game."
        case .german:
            return "Kurze Strategie-Missionen zeigen eine Rechenidee und lassen das Kind sie direkt im Spiel ueben."
        }
    }

    var accessibilityGuide: String {
        switch language {
        case .english:
            return "These options reduce visual load or make answers easier to read. They are optional and can be changed anytime."
        case .german:
            return "Diese Optionen verringern visuelle Reize oder machen Antworten besser lesbar. Sie sind optional und jederzeit aenderbar."
        }
    }

    var enableSpecialMissions: String {
        switch language {
        case .english:
            return "Enable Special Missions"
        case .german:
            return "Spezialmissionen aktivieren"
        }
    }

    var automaticMissionSuggestions: String {
        switch language {
        case .english:
            return "Automatically suggest missions"
        case .german:
            return "Missionen automatisch vorschlagen"
        }
    }

    var missionSettingsFooter: String {
        switch language {
        case .english:
            return "Missions are short strategy challenges that can be suggested after a round."
        case .german:
            return "Missionen sind kurze Strategie-Trainings, die nach einer Runde vorgeschlagen werden koennen."
        }
    }

    var startMission: String {
        switch language {
        case .english:
            return "Start Mission"
        case .german:
            return "Mission starten"
        }
    }

    var completed: String {
        switch language {
        case .english:
            return "Completed"
        case .german:
            return "Geschafft"
        }
    }

    var recommendedMission: String {
        switch language {
        case .english:
            return "Recommended Mission"
        case .german:
            return "Empfohlene Mission"
        }
    }

    var missionComplete: String {
        switch language {
        case .english:
            return "Mission Complete!"
        case .german:
            return "Mission geschafft!"
        }
    }

    var bossIncoming: String {
        switch language {
        case .english:
            return "Boss incoming!"
        case .german:
            return "Boss kommt!"
        }
    }

    var missionReward: String {
        switch language {
        case .english:
            return "Badge unlocked and energy boosted."
        case .german:
            return "Abzeichen freigeschaltet und Energie aufgefuellt."
        }
    }

    var continueButton: String {
        switch language {
        case .english:
            return "Continue"
        case .german:
            return "Weiter"
        }
    }

    func specialMissionTitle(_ mission: SpecialMissionID) -> String {
        switch (language, mission) {
        case (.english, .friendsOf10):
            return "Friends of 10"
        case (.english, .bridgingThrough10):
            return "Jump to 10"
        case (.english, .doublesNearDoubles):
            return "Twins and Near Twins"
        case (.english, .countingUp):
            return "Count Up"
        case (.english, .nineTrick):
            return "The 9-Trick"
        case (.german, .friendsOf10):
            return "Freunde der 10"
        case (.german, .bridgingThrough10):
            return "Sprung zur 10"
        case (.german, .doublesNearDoubles):
            return "Zwillinge und Nachbarn"
        case (.german, .countingUp):
            return "Hochzaehlen"
        case (.german, .nineTrick):
            return "Der 9er-Trick"
        }
    }

    func specialMissionDescription(_ mission: SpecialMissionID) -> String {
        switch (language, mission) {
        case (.english, .friendsOf10):
            return "Find partners that make 10."
        case (.english, .bridgingThrough10):
            return "Jump to 10 first, then finish."
        case (.english, .doublesNearDoubles):
            return "Use the twin, then add 1."
        case (.english, .countingUp):
            return "Count from the small number to the big one."
        case (.english, .nineTrick):
            return "Use 10, then step back 1."
        case (.german, .friendsOf10):
            return "Finde Partner, die 10 ergeben."
        case (.german, .bridgingThrough10):
            return "Spring zuerst zur 10, dann weiter."
        case (.german, .doublesNearDoubles):
            return "Nutze den Zwilling, dann plus 1."
        case (.german, .countingUp):
            return "Zaehle von der kleinen zur grossen Zahl."
        case (.german, .nineTrick):
            return "Nutze 10, dann einen Schritt zurueck."
        }
    }

    func specialMissionUnlockText(_ mission: SpecialMissionID) -> String {
        switch (language, mission) {
        case (.english, .friendsOf10):
            return "Find the partner that makes 10."
        case (.english, .bridgingThrough10):
            return "Jump to 10 first."
        case (.english, .doublesNearDoubles):
            return "Use the twin, then add 1."
        case (.english, .countingUp):
            return "Count from the small number to the big number."
        case (.english, .nineTrick):
            return "Add 10, then take away 1."
        case (.german, .friendsOf10):
            return "Finde den Partner bis 10."
        case (.german, .bridgingThrough10):
            return "Spring zuerst zur 10."
        case (.german, .doublesNearDoubles):
            return "Nutze den Zwilling, dann plus 1."
        case (.german, .countingUp):
            return "Zaehle von der kleinen zur grossen Zahl."
        case (.german, .nineTrick):
            return "Plus 10, dann minus 1."
        }
    }

    var recommendedPractice: String {
        switch language {
        case .english:
            return "Recommended Practice"
        case .german:
            return "Empfohlenes Training"
        }
    }

    var stageSummary: String {
        switch language {
        case .english:
            return "Stage Summary"
        case .german:
            return "Stufenübersicht"
        }
    }

    var resetStats: String {
        switch language {
        case .english:
            return "Reset Stats"
        case .german:
            return "Statistiken löschen"
        }
    }

    var done: String {
        switch language {
        case .english:
            return "Done"
        case .german:
            return "Fertig"
        }
    }

    var cancel: String {
        switch language {
        case .english:
            return "Cancel"
        case .german:
            return "Abbrechen"
        }
    }

    var reset: String {
        switch language {
        case .english:
            return "Reset"
        case .german:
            return "Zurücksetzen"
        }
    }

    var resetStatisticsTitle: String {
        switch language {
        case .english:
            return "Reset statistics?"
        case .german:
            return "Statistiken zurücksetzen?"
        }
    }

    var resetStatisticsMessage: String {
        switch language {
        case .english:
            return "This clears analytics history and learning progress, but keeps the saved high score."
        case .german:
            return "Dadurch werden Analyseverlauf und Lernfortschritt gelöscht, der Highscore bleibt aber erhalten."
        }
    }

    var missingExplosionVideo: String {
        switch language {
        case .english:
            return "Explosion video missing"
        case .german:
            return "Explosionsvideo fehlt"
        }
    }

    var noAnalyticsYet: String {
        switch language {
        case .english:
            return "Play a few rounds to start seeing math skill insights."
        case .german:
            return "Spiele ein paar Runden, damit Mathe-Einsichten sichtbar werden."
        }
    }

    var accuracy: String {
        switch language {
        case .english:
            return "Accuracy"
        case .german:
            return "Trefferquote"
        }
    }

    var averageTime: String {
        switch language {
        case .english:
            return "Avg Time"
        case .german:
            return "Ø Zeit"
        }
    }

    var retry: String {
        switch language {
        case .english:
            return "Retry"
        case .german:
            return "Wiederholung"
        }
    }

    func attempts(_ count: Int) -> String {
        switch language {
        case .english:
            return "Attempts: \(count)"
        case .german:
            return "Versuche: \(count)"
        }
    }

    var practiceFocus: String {
        switch language {
        case .english:
            return "Practice Focus"
        case .german:
            return "Trainingsfokus"
        }
    }

    var goodAt: String {
        switch language {
        case .english:
            return "Going well"
        case .german:
            return "Läuft gut"
        }
    }

    var practiceMore: String {
        switch language {
        case .english:
            return "Still practice"
        case .german:
            return "Weiter üben"
        }
    }

    func modeDescription(for mode: GameMode) -> String {
        switch (language, mode) {
        case (.english, .addition):
            return "Build confidence from single-digit facts up to bigger addition patterns."
        case (.english, .subtraction):
            return "Practice subtraction facts first, then move into borrowing and tougher number sense."
        case (.english, .multiplication):
            return "Start with the 2 times table, then unlock new tables as accuracy and speed improve."
        case (.english, .division):
            return "Practice exact division facts from the selected tables and unlock harder fact families."
        case (.german, .addition):
            return "Starte mit einfachen Plusaufgaben und arbeite dich zu größeren Mustern vor."
        case (.german, .subtraction):
            return "Übe zuerst einfache Minusaufgaben und steigere dich dann zu schwierigeren Zahlbeziehungen."
        case (.german, .multiplication):
            return "Beginne mit der 2er-Reihe und schalte neue Reihen durch Genauigkeit und Tempo frei."
        case (.german, .division):
            return "Uebe genaue Divisionsaufgaben aus den gewaehlten Reihen und schalte schwerere Aufgabenfamilien frei."
        }
    }

    func settingsHelpMessage(_ topic: SettingsHelpTopic) -> String {
        switch (language, topic) {
        case (.english, .learningProfile):
            return "A preset changes several math settings at once. Use Custom when you want direct control."
        case (.english, .arithmeticFocus):
            return "Controls how large or complex addition and subtraction problems can become."
        case (.english, .multiplicationDivision):
            return "Tables choose the fact families. Factors choose the numbers used inside those tables."
        case (.english, .specialMissions):
            return "Optional short missions teach one mental strategy, then end with a no-fail boss round."
        case (.english, .accessibility):
            return "Use these if motion, flashes, contrast, or answer size affect comfort or readability."
        case (.german, .learningProfile):
            return "Ein Profil aendert mehrere Mathe-Einstellungen gleichzeitig. Individuell gibt direkte Kontrolle."
        case (.german, .arithmeticFocus):
            return "Legt fest, wie gross oder komplex Plus- und Minusaufgaben werden duerfen."
        case (.german, .multiplicationDivision):
            return "Reihen waehlen die Aufgabenfamilien. Faktoren waehlen die Zahlen innerhalb dieser Reihen."
        case (.german, .specialMissions):
            return "Optionale kurze Missionen zeigen eine Kopfrechenstrategie und enden mit einem Boss ohne Scheitern."
        case (.german, .accessibility):
            return "Nutze diese Optionen, wenn Bewegung, Blitze, Kontrast oder Zahlengroesse wichtig sind."
        }
    }

    func learningProfileTitle(_ profile: LearningProfile) -> String {
        switch (language, profile) {
        case (.english, .earlyLearner):
            return "Early Learner"
        case (.english, .primary):
            return "Primary"
        case (.english, .advanced):
            return "Advanced"
        case (.english, .custom):
            return "Custom"
        case (.german, .earlyLearner):
            return "Fruehe Lernstufe"
        case (.german, .primary):
            return "Grundschule"
        case (.german, .advanced):
            return "Fortgeschritten"
        case (.german, .custom):
            return "Individuell"
        }
    }

    func learningProfileDescription(_ profile: LearningProfile) -> String {
        switch (language, profile) {
        case (.english, .earlyLearner):
            return "Keep arithmetic on small facts and start multiplication with gentle tables."
        case (.english, .primary):
            return "Mix review with up-to-100 arithmetic and the standard multiplication path."
        case (.english, .advanced):
            return "Focus on larger arithmetic and a wider multiplication range with reversed facts."
        case (.english, .custom):
            return "Fine-tune the learning path for a specific child or class."
        case (.german, .earlyLearner):
            return "Bleibt bei kleinen Rechenaufgaben und startet das Einmaleins mit einfachen Reihen."
        case (.german, .primary):
            return "Mischt Wiederholung mit Rechnen bis 100 und dem normalen Einmaleins-Weg."
        case (.german, .advanced):
            return "Fokussiert groessere Rechnungen und ein breiteres Einmaleins mit vertauschten Aufgaben."
        case (.german, .custom):
            return "Passe den Lernweg gezielt an ein Kind oder eine Klasse an."
        }
    }

    func arithmeticFocusTitle(_ focus: ArithmeticFocus) -> String {
        switch (language, focus) {
        case (.english, .foundations):
            return "Foundations"
        case (.english, .bridgingTo20):
            return "Up to 20"
        case (.english, .doubleDigits):
            return "Double Digits"
        case (.english, .upTo100):
            return "Up to 100"
        case (.german, .foundations):
            return "Grundlagen"
        case (.german, .bridgingTo20):
            return "Bis 20"
        case (.german, .doubleDigits):
            return "Zweistellig"
        case (.german, .upTo100):
            return "Bis 100"
        }
    }

    func arithmeticFocusDescription(_ focus: ArithmeticFocus) -> String {
        switch (language, focus) {
        case (.english, .foundations):
            return "Single digits, making 10, and early number confidence."
        case (.english, .bridgingTo20):
            return "Build fluency around crossing 10 and complements to 20."
        case (.english, .doubleDigits):
            return "Work on tens and double-digit calculations without dropping back too far."
        case (.english, .upTo100):
            return "Use the full two-digit path, including carry or borrow practice."
        case (.german, .foundations):
            return "Einstellige Aufgaben, Ergaenzungen bis 10 und fruehe Zahlensicherheit."
        case (.german, .bridgingTo20):
            return "Festigt den Uebergang ueber die 10 und Ergaenzungen bis 20."
        case (.german, .doubleDigits):
            return "Trainiert Zehner und zweistellige Aufgaben ohne staendig weit zurueckzugehen."
        case (.german, .upTo100):
            return "Nutzt den vollen zweistelligen Lernweg inklusive Uebertrag und Entbuendelung."
        }
    }

    func curriculumSummary(_ settings: CurriculumSettings) -> String {
        let focus = arithmeticFocusTitle(settings.arithmeticFocus)
        let review = settings.includeBasicReview ? reviewOnShortLabel : reviewOffShortLabel
        return "\(learningProfileTitle(settings.learningProfile)) · \(focus) · \(review)"
    }

    private var reviewOnShortLabel: String {
        switch language {
        case .english:
            return "with review"
        case .german:
            return "mit Wiederholung"
        }
    }

    private var reviewOffShortLabel: String {
        switch language {
        case .english:
            return "less review"
        case .german:
            return "weniger Wiederholung"
        }
    }
}
