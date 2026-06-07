import Foundation

enum CampaignStarsCalculator {
    static func stars(playerWon: Bool, playerScore: Int, enemyScore: Int) -> Int {
        guard playerWon else { return 0 }
        if enemyScore == 0 { return 3 }
        if playerScore - enemyScore >= 2 { return 2 }
        return 1
    }

    static func starsText(_ count: Int) -> String {
        let filled = String(repeating: "★", count: min(max(count, 0), 3))
        let empty = String(repeating: "☆", count: max(0, 3 - min(max(count, 0), 3)))
        return filled + empty
    }
}
