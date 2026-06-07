import Foundation

enum CampaignProgressStore {
    private static let defaultsKey = "glowBounce.campaignProgress.v1"

    private struct Persisted: Codable {
        var bestStarsByLevelID: [String: Int]
    }

    private static func load() -> Persisted {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(Persisted.self, from: data) else {
            return Persisted(bestStarsByLevelID: [:])
        }
        return decoded
    }

    private static func save(_ value: Persisted) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func bestStars(for levelID: Int) -> Int {
        load().bestStarsByLevelID[String(levelID)] ?? 0
    }

    static func isCompleted(_ levelID: Int) -> Bool {
        bestStars(for: levelID) > 0
    }

    static func isUnlocked(_ levelID: Int) -> Bool {
        if levelID <= 1 { return true }
        return isCompleted(levelID - 1)
    }

    static func recordWin(levelID: Int, stars: Int) {
        var state = load()
        let key = String(levelID)
        let previous = state.bestStarsByLevelID[key] ?? 0
        state.bestStarsByLevelID[key] = max(previous, stars)
        save(state)
    }

    static var totalStarsEarned: Int {
        load().bestStarsByLevelID.values.reduce(0, +)
    }

    static var completedLevelCount: Int {
        load().bestStarsByLevelID.values.filter { $0 > 0 }.count
    }
}
