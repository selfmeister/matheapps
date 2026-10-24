public struct FactFamilyProblem: Equatable {
    public let prompt: String
    public let result: Int
    public let table: Int
    public let factor: Int
}

public struct FactFamilyProblemEngine {
    public init() {}

    public func multiplicationProblem(table: Int, factor: Int, reversed: Bool = false) -> FactFamilyProblem {
        let left = reversed ? factor : table
        let right = reversed ? table : factor
        return FactFamilyProblem(
            prompt: "\(left) x \(right) = ?",
            result: table * factor,
            table: table,
            factor: factor
        )
    }

    public func divisionProblem(table: Int, factor: Int) -> FactFamilyProblem {
        FactFamilyProblem(
            prompt: "\(table * factor) / \(table) = ?",
            result: factor,
            table: table,
            factor: factor
        )
    }

    public func divisionDistractors(for problem: FactFamilyProblem) -> [Int] {
        [
            problem.result - 2,
            problem.result - 1,
            problem.result + 1,
            problem.result + 2,
            problem.table,
            problem.factor,
            problem.result + problem.table,
            max(1, problem.result - problem.table)
        ]
        .filter { $0 > 0 && $0 != problem.result }
        .uniquePreservingOrder()
    }
}

private extension Array where Element: Hashable {
    func uniquePreservingOrder() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
