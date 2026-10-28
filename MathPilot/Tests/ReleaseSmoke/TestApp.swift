import SwiftUI

// Separate test app and bundle: fixtures never enter the shipping app or its data.
@main
struct ReleaseSmokeApp: App {
    init() {
        let environment = ProcessInfo.processInfo.environment
        if let language = environment["SMOKE_LANGUAGE"] {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            UserDefaults.standard.set(language, forKey: "appLanguage")
            UserDefaults.standard.set(false, forKey: "soundEnabled")
            if environment["SMOKE_EMPTY"] != "1" {
                let records = (0..<8).map { index in
                    AnalyticsRecord(timestamp: Date().addingTimeInterval(Double(index - 8)),
                        mode: .addition, stage: .crossing10, patternPhase: nil,
                        problem: "8 + 5 = ?", correctAnswer: 13, chosenAnswer: index < 2 ? 12 : 13,
                        isCorrect: index >= 2, wasRetry: false, responseTimeMs: 2000)
                }
                AnalyticsRecord.store(records, forKey: "analyticsRecords")
            }
        }
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
