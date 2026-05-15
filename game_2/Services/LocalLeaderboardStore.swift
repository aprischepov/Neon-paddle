import Foundation

/// Локальная таблица: очки за победу (+2), за поражение (+0), вин-стрик, история матчей с сложностью.
enum LocalLeaderboardStore {
    static let pointsPerWin = 2
    static let pointsPerLoss = 0
    private static let defaultsKey = "glowBounce.localLeaderboard.v1"
    private static let maxStoredMatches = 15

    struct MatchEntry: Codable, Equatable {
        var recordedAt: TimeInterval
        var difficultyRaw: Int
        var gameModeRaw: Int
        var playerWon: Bool
        var pointsEarned: Int
    }

    private struct Persisted: Codable {
        var totalPoints: Int
        var currentWinStreak: Int
        var bestWinStreak: Int
        var matches: [MatchEntry]
    }

    private static func load() -> Persisted {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(Persisted.self, from: data) else {
            return Persisted(totalPoints: 0, currentWinStreak: 0, bestWinStreak: 0, matches: [])
        }
        return decoded
    }

    private static func save(_ value: Persisted) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static var totalPoints: Int { load().totalPoints }
    static var currentWinStreak: Int { load().currentWinStreak }
    static var bestWinStreak: Int { load().bestWinStreak }
    static var recentMatches: [MatchEntry] { load().matches }

    static func recordMatchEnd(playerWon: Bool, difficultyRaw: Int, gameModeRaw: Int) {
        var s = load()
        let pts = playerWon ? pointsPerWin : pointsPerLoss
        s.totalPoints += pts
        if playerWon {
            s.currentWinStreak += 1
            s.bestWinStreak = max(s.bestWinStreak, s.currentWinStreak)
        } else {
            s.currentWinStreak = 0
        }
        let entry = MatchEntry(
            recordedAt: Date().timeIntervalSince1970,
            difficultyRaw: difficultyRaw,
            gameModeRaw: gameModeRaw,
            playerWon: playerWon,
            pointsEarned: pts
        )
        s.matches.insert(entry, at: 0)
        if s.matches.count > maxStoredMatches {
            s.matches = Array(s.matches.prefix(maxStoredMatches))
        }
        save(s)
    }

    static func difficultyTitle(raw: Int) -> String {
        switch raw {
        case 0: return "Easy"
        case 1: return "Normal"
        case 2: return "Hard"
        default: return "—"
        }
    }

    static func gameModeTitle(raw: Int) -> String {
        switch raw {
        case 0: return "Classic"
        case 1: return "Power-Ups"
        default: return "—"
        }
    }

    private static let rowDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    /// Строки таблицы «недавние матчи» (новые сверху).
    static func matchTableRows(limit: Int = 10) -> [String] {
        let m = load().matches
        return m.prefix(limit).map { e in
            let date = Date(timeIntervalSince1970: e.recordedAt)
            let ds = rowDateFormatter.string(from: date)
            let diff = difficultyTitle(raw: e.difficultyRaw)
            let modeShort = e.gameModeRaw == 0 ? "CL" : "PU"
            let res = e.playerWon ? "WIN" : "LOSS"
            return "\(ds)  \(diff)/\(modeShort)  \(res)  +\(e.pointsEarned)"
        }
    }
}
