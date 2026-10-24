import Foundation

enum LearningProfile: String, CaseIterable, Identifiable, Codable {
    case earlyLearner
    case primary
    case advanced
    case custom

    var id: String { rawValue }
}

enum ArithmeticFocus: String, CaseIterable, Identifiable, Codable {
    case foundations
    case bridgingTo20
    case doubleDigits
    case upTo100

    var id: String { rawValue }
}

struct CurriculumSettings: Codable, Equatable {
    var learningProfile: LearningProfile
    var arithmeticFocus: ArithmeticFocus
    var includeBasicReview: Bool
    var multiplicationTables: [Int]
    var multiplicationFactors: [Int]
    var multiplicationIncludeReversedFacts: Bool

    static let defaultTableSequence = [2, 3, 4, 5, 10, 6, 7, 8, 9]
    static let defaultFactorSequence = Array(2...10)

    static var `default`: CurriculumSettings {
        preset(.primary)
    }

    static func preset(_ profile: LearningProfile) -> CurriculumSettings {
        switch profile {
        case .earlyLearner:
            return CurriculumSettings(
                learningProfile: .earlyLearner,
                arithmeticFocus: .foundations,
                includeBasicReview: true,
                multiplicationTables: [2, 5, 10],
                multiplicationFactors: Array(2...5),
                multiplicationIncludeReversedFacts: false
            )
        case .primary:
            return CurriculumSettings(
                learningProfile: .primary,
                arithmeticFocus: .upTo100,
                includeBasicReview: true,
                multiplicationTables: defaultTableSequence,
                multiplicationFactors: defaultFactorSequence,
                multiplicationIncludeReversedFacts: false
            )
        case .advanced:
            return CurriculumSettings(
                learningProfile: .advanced,
                arithmeticFocus: .upTo100,
                includeBasicReview: false,
                multiplicationTables: Array(2...12),
                multiplicationFactors: Array(2...12),
                multiplicationIncludeReversedFacts: true
            )
        case .custom:
            return .default
        }
    }

    var normalized: CurriculumSettings {
        CurriculumSettings(
            learningProfile: learningProfile,
            arithmeticFocus: arithmeticFocus,
            includeBasicReview: includeBasicReview,
            multiplicationTables: normalizedMultiplicationTables,
            multiplicationFactors: normalizedMultiplicationFactors,
            multiplicationIncludeReversedFacts: multiplicationIncludeReversedFacts
        )
    }

    var arithmeticStages: [DifficultyStage] {
        var stages: [DifficultyStage]

        switch arithmeticFocus {
        case .foundations:
            stages = [.singleDigit, .complementsTo10, .crossing10]
        case .bridgingTo20:
            stages = [.singleDigit, .complementsTo10, .crossing10, .complementsTo20]
        case .doubleDigits:
            stages = [.digitPlusWholeTens, .doubleDigitPlusSingleNoCrossing, .twoDigitNoCarryBorrow]
        case .upTo100:
            stages = [
                .digitPlusWholeTens,
                .doubleDigitPlusSingleNoCrossing,
                .twoDigitNoCarryBorrow,
                .twoDigitWithCarryBorrow,
                .pattern,
                .mixed
            ]
        }

        if includeBasicReview && arithmeticFocus != .foundations && arithmeticFocus != .bridgingTo20 {
            stages.insert(contentsOf: [.singleDigit, .complementsTo10], at: 0)
        }

        return stages
    }

    var normalizedMultiplicationTables: [Int] {
        var seen: Set<Int> = []
        let normalized = multiplicationTables.filter { table in
            guard (2...12).contains(table), !seen.contains(table) else { return false }
            seen.insert(table)
            return true
        }
        return normalized.isEmpty ? [2] : normalized
    }

    var normalizedMultiplicationFactors: [Int] {
        let filtered = Set(multiplicationFactors.filter { (2...12).contains($0) })
        let normalized = Array(filtered).sorted()
        return normalized.isEmpty ? Array(2...5) : normalized
    }

    var introMultiplicationFactors: [Int] {
        // Use full range from the start - no longer limited to easy factors only
        return normalizedMultiplicationFactors
    }
}
