import Foundation

enum AchievementStore {
    private static let defaultsKey = "glowBounce.achievements.v1"

    private struct Persisted: Codable {
        var unlockedIDs: [String]
        var matchesPlayed: Int
        var twoPlayerMatches: Int
        var powerUpWins: Int
    }

    private static func load() -> Persisted {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(Persisted.self, from: data) else {
            return Persisted(unlockedIDs: [], matchesPlayed: 0, twoPlayerMatches: 0, powerUpWins: 0)
        }
        return decoded
    }

    private static func save(_ value: Persisted) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func isUnlocked(_ id: String) -> Bool {
        load().unlockedIDs.contains(id)
    }

    static var unlockedCount: Int {
        load().unlockedIDs.count
    }

    static var totalCount: Int {
        AchievementCatalog.all.count
    }

    static func registerMatchResult(gameMode: GameMode, playerWon: Bool) {
        var state = load()
        state.matchesPlayed += 1
        if gameMode == .localTwoPlayer {
            state.twoPlayerMatches += 1
        }
        if gameMode == .powerUps, playerWon {
            state.powerUpWins += 1
        }
        save(state)
        evaluate()
    }

    static func registerCampaignResult() {
        evaluate()
    }

    @discardableResult
    static func evaluate() -> [Achievement] {
        var state = load()
        let metrics = currentMetrics(state: state)
        var unlocked = Set(state.unlockedIDs)
        var freshlyUnlocked: [Achievement] = []
        for achievement in AchievementCatalog.all where !unlocked.contains(achievement.id) {
            if achievement.isEarned(metrics) {
                unlocked.insert(achievement.id)
                freshlyUnlocked.append(achievement)
            }
        }
        if !freshlyUnlocked.isEmpty {
            state.unlockedIDs = AchievementCatalog.all.map(\.id).filter { unlocked.contains($0) }
            save(state)
            for achievement in freshlyUnlocked {
                AppLogger.track("achievement_unlocked", properties: ["id": achievement.id])
            }
        }
        return freshlyUnlocked
    }

    private static func currentMetrics(state: Persisted) -> AchievementMetrics {
        let allLevels = CampaignCatalog.allLevels
        let firstWorldCleared = CampaignCatalog.worlds.first.map { world in
            world.levels.allSatisfy { CampaignProgressStore.isCompleted($0.id) }
        } ?? false
        let hasThreeStar = allLevels.contains { CampaignProgressStore.bestStars(for: $0.id) >= 3 }
        return AchievementMetrics(
            bestWinStreak: LocalLeaderboardStore.bestWinStreak,
            totalPoints: LocalLeaderboardStore.totalPoints,
            matchesPlayed: state.matchesPlayed,
            twoPlayerMatches: state.twoPlayerMatches,
            powerUpWins: state.powerUpWins,
            campaignCompleted: CampaignProgressStore.completedLevelCount,
            campaignTotal: allLevels.count,
            totalStars: CampaignProgressStore.totalStarsEarned,
            maxStars: allLevels.count * 3,
            hasThreeStarLevel: hasThreeStar,
            firstWorldCleared: firstWorldCleared
        )
    }
}
