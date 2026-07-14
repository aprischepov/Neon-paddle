import Foundation

struct AchievementMetrics {
    var bestWinStreak: Int
    var totalPoints: Int
    var matchesPlayed: Int
    var twoPlayerMatches: Int
    var powerUpWins: Int
    var campaignCompleted: Int
    var campaignTotal: Int
    var totalStars: Int
    var maxStars: Int
    var hasThreeStarLevel: Bool
    var firstWorldCleared: Bool
}

struct Achievement {
    let id: String
    let title: String
    let details: String
    let isEarned: (AchievementMetrics) -> Bool
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(
            id: "first_win",
            title: "First Serve",
            details: "Win your first match"
        ) { $0.bestWinStreak >= 1 || $0.campaignCompleted >= 1 },
        Achievement(
            id: "streak_3",
            title: "On Fire",
            details: "Reach a 3-win streak"
        ) { $0.bestWinStreak >= 3 },
        Achievement(
            id: "streak_5",
            title: "Unstoppable",
            details: "Reach a 5-win streak"
        ) { $0.bestWinStreak >= 5 },
        Achievement(
            id: "points_50",
            title: "Point Machine",
            details: "Earn 50 total points"
        ) { $0.totalPoints >= 50 },
        Achievement(
            id: "matches_25",
            title: "Regular",
            details: "Play 25 matches"
        ) { $0.matchesPlayed >= 25 },
        Achievement(
            id: "power_win",
            title: "Power Player",
            details: "Win a Power-Ups match"
        ) { $0.powerUpWins >= 1 },
        Achievement(
            id: "two_player",
            title: "Bring a Friend",
            details: "Play a 2-player match"
        ) { $0.twoPlayerMatches >= 1 },
        Achievement(
            id: "campaign_start",
            title: "Campaign Rookie",
            details: "Clear a campaign level"
        ) { $0.campaignCompleted >= 1 },
        Achievement(
            id: "world1_clear",
            title: "Warm-Up Done",
            details: "Clear every level in World 1"
        ) { $0.firstWorldCleared },
        Achievement(
            id: "flawless",
            title: "Flawless",
            details: "Earn 3 stars on any level"
        ) { $0.hasThreeStarLevel },
        Achievement(
            id: "stars_15",
            title: "Star Collector",
            details: "Collect 15 campaign stars"
        ) { $0.totalStars >= 15 },
        Achievement(
            id: "campaign_master",
            title: "Champion",
            details: "Clear every campaign level"
        ) { $0.campaignTotal > 0 && $0.campaignCompleted >= $0.campaignTotal },
        Achievement(
            id: "perfectionist",
            title: "Perfectionist",
            details: "Earn every campaign star"
        ) { $0.maxStars > 0 && $0.totalStars >= $0.maxStars },
    ]

    static func achievement(id: String) -> Achievement? {
        all.first { $0.id == id }
    }
}
