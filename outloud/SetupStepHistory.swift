/// Completion belongs to a route, not to the currently visible question.
/// Revisiting an earlier answer never discards later completed steps.
struct SetupStepHistory {
    private var routes: [String: Set<Int>] = [:]
    mutating func complete(_ step: Int, route: String) {
        routes[route, default: []].insert(step)
    }
    func completed(in sequence: [Int], route: String) -> [Int] {
        sequence.filter { routes[route, default: []].contains($0) }
    }
}
