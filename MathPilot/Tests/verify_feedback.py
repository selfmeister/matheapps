"""Run portable regression checks against the app's actual Swift feedback code.

Usage: python3 Tests/verify_feedback.py
Only the SwiftUI-independent declarations are compiled, so no simulator is needed.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
manager = (root / 'GameManager.swift').read_text()
localization = (root / 'Localization.swift').read_text()

def section(source, start, end):
    return source[source.index(start):source.index(end, source.index(start))]

source = 'import Foundation\nenum AppLanguage { case english, german }\nstruct AppCopy { let language: AppLanguage }\n'
source += section(manager, 'enum GameMode:', 'enum MultiplicationLearningPhase:')
source += section(manager, 'struct AnalyticsRecord:', 'private struct FeedbackPracticeSession')
source += section(manager, 'struct FeedbackPracticeResult:', 'enum VehicleType:')
source += localization[localization.index('extension AppCopy {\n    private func feedbackText'):]
source += r'''
func record(_ index: Int, correct: Bool = true, retry: Bool = false,
            mode: GameMode = .addition, stage: DifficultyStage = .crossing10,
            problem: String = "8 + 5 = ?", answer: Int = 13) -> AnalyticsRecord {
    AnalyticsRecord(timestamp: Date(timeIntervalSince1970: Double(index)), mode: mode,
        stage: stage, patternPhase: nil, problem: problem, correctAnswer: answer,
        chosenAnswer: correct ? answer : 12, isCorrect: correct, wasRetry: retry,
        responseTimeMs: retry ? 9000 : 2000)
}
let en = AppCopy(language: .english), de = AppCopy(language: .german)
let perfect = (0..<8).map { record($0) }
let summary = AnalyticsEngine(records: perfect).stageSummaries(in: .english)[0]
assert(summary.accuracy == 1 && summary.retryAttempts == 0)
assert(en.feedbackRetry(summary) == "No retries recorded in this set.")
assert(de.feedbackRetry(summary).contains("keine Wiederholungsversuche"))

let attempts = [record(0, correct: false), record(1, retry: true)] + (2..<7).map { record($0) }
let retried = AnalyticsEngine(records: attempts).stageSummaries(in: .english)[0]
assert(retried.attempts == 6 && retried.correctFirstAttempts == 5)
assert(abs(retried.accuracy - 5.0 / 6) < 0.0001)
assert(retried.retryAttempts == 1 && retried.retrySuccessRate == 1)
assert(retried.averageResponseTimeMs == 2000)

let history = (0..<20).map { record($0, correct: false) } + (20..<40).map { record($0) }
let recent = AnalyticsEngine(records: history).stageSummaries(in: .german)[0]
assert(recent.attempts == 20 && recent.accuracy == 1 && recent.previousAccuracy == 0)
assert(de.feedbackTrend(recent).contains("zuvor 0% → zuletzt 100%"))
assert(AnalyticsEngine(records: Array(perfect.prefix(3))).stageSummaries(in: .english).isEmpty)

// Older records remain decodable but cannot contaminate corrected first-attempt metrics.
let encoded = try JSONEncoder().encode(perfect)
var legacy = try JSONSerialization.jsonObject(with: encoded) as! [[String: Any]]
for index in legacy.indices { legacy[index].removeValue(forKey: "measurementVersion") }
let decoded = try JSONDecoder().decode([AnalyticsRecord].self, from: JSONSerialization.data(withJSONObject: legacy))
assert(decoded.count == 8 && decoded[0].measurementVersion == nil)
assert(AnalyticsEngine(records: decoded).stageSummaries(in: .english).isEmpty)

assert(en.feedbackStrategy(for: record(0)).contains("8 + 2 = 10"))
assert(de.feedbackStrategy(for: record(0)).contains("Zerlege 5 in 2 und 3"))
let complement = record(0, mode: .subtraction, stage: .complementsTo10, problem: "10 - ? = 6", answer: 4)
assert(en.feedbackStrategy(for: complement).contains("from 6 to 10: 4 steps"))
assert(de.feedbackStrategy(for: complement).contains("von 6 bis 10: 4 Schritte"))
let division = record(0, mode: .division, stage: .multiplicationTable, problem: "24 ÷ 6 = ?", answer: 4)
assert(en.feedbackStrategy(for: division).contains("6 × 4 = 24"))
assert(de.feedbackStrategy(for: division).contains("Malaufgabe"))
let result = FeedbackPracticeResult(problem: "8 + 5 = ?", basePoints: 50,
    awardedPoints: 100, firstTryCorrect: 4, problemCount: 5)
assert(en.feedbackPracticeOutcome(result) == "4 of 5 correct on the first try")
assert(de.feedbackPracticeOutcome(result) == "4 von 5 im ersten Versuch richtig")
assert(de.feedbackTiming(2500).contains("2,5 s"))
assert(en.feedbackTiming(2500).contains("2.5 s"))
print("Feedback regression checks passed: first attempts, retries, recent window, history compatibility, strategies and EN/DE copy.")
'''
with tempfile.TemporaryDirectory(prefix='mathpilot-feedback-') as directory:
    path = Path(directory)
    (path / 'main.swift').write_text(source)
    subprocess.run(['swiftc', '-module-cache-path', str(path / 'cache'), str(path / 'main.swift'), '-o', str(path / 'checks')], check=True)
    subprocess.run([str(path / 'checks')], check=True)
