import Foundation

enum CampaignCatalog {
    static let worlds: [CampaignWorld] = [
        CampaignWorld(
            index: 1,
            title: "Warm-Up",
            subtitle: "Learn the rally",
            levels: [
                CampaignLevel(
                    id: 1, worldIndex: 1, worldTitle: "Warm-Up",
                    title: "First Bounce", objective: "Win to 5 · Easy · Classic",
                    difficulty: .easy, gameMode: .classic, scoreLimit: 5, requiresShutoutForThreeStars: false
                ),
                CampaignLevel(
                    id: 2, worldIndex: 1, worldTitle: "Warm-Up",
                    title: "Steady Rally", objective: "Win to 7 · Easy · Classic",
                    difficulty: .easy, gameMode: .classic, scoreLimit: 7, requiresShutoutForThreeStars: false
                ),
                CampaignLevel(
                    id: 3, worldIndex: 1, worldTitle: "Warm-Up",
                    title: "Neon Basics", objective: "Win to 7 · Easy · Power-Ups",
                    difficulty: .easy, gameMode: .powerUps, scoreLimit: 7, requiresShutoutForThreeStars: false
                ),
                CampaignLevel(
                    id: 4, worldIndex: 1, worldTitle: "Warm-Up",
                    title: "Clean Sheet", objective: "Win to 5 · Do not concede for 3★",
                    difficulty: .easy, gameMode: .classic, scoreLimit: 5, requiresShutoutForThreeStars: true
                ),
                CampaignLevel(
                    id: 5, worldIndex: 1, worldTitle: "Warm-Up",
                    title: "Gate Keeper", objective: "Win to 9 · Easy · Classic",
                    difficulty: .easy, gameMode: .classic, scoreLimit: 9, requiresShutoutForThreeStars: false
                ),
            ]
        ),
        CampaignWorld(
            index: 2,
            title: "Pulse Circuit",
            subtitle: "Pick up the pace",
            levels: [
                CampaignLevel(
                    id: 6, worldIndex: 2, worldTitle: "Pulse Circuit",
                    title: "Mid Tempo", objective: "Win to 7 · Normal · Classic",
                    difficulty: .normal, gameMode: .classic, scoreLimit: 7, requiresShutoutForThreeStars: false
                ),
                CampaignLevel(
                    id: 7, worldIndex: 2, worldTitle: "Pulse Circuit",
                    title: "Power Grid", objective: "Win to 7 · Normal · Power-Ups",
                    difficulty: .normal, gameMode: .powerUps, scoreLimit: 7, requiresShutoutForThreeStars: false
                ),
                CampaignLevel(
                    id: 8, worldIndex: 2, worldTitle: "Pulse Circuit",
                    title: "Pressure Line", objective: "Win to 9 · Normal · Classic",
                    difficulty: .normal, gameMode: .classic, scoreLimit: 9, requiresShutoutForThreeStars: false
                ),
                CampaignLevel(
                    id: 9, worldIndex: 2, worldTitle: "Pulse Circuit",
                    title: "Flux Field", objective: "Win to 11 · Normal · Power-Ups",
                    difficulty: .normal, gameMode: .powerUps, scoreLimit: 11, requiresShutoutForThreeStars: false
                ),
                CampaignLevel(
                    id: 10, worldIndex: 2, worldTitle: "Pulse Circuit",
                    title: "Perfect Pulse", objective: "Win to 7 · Shutout for 3★",
                    difficulty: .normal, gameMode: .classic, scoreLimit: 7, requiresShutoutForThreeStars: true
                ),
            ]
        ),
        CampaignWorld(
            index: 3,
            title: "Void League",
            subtitle: "Master the glow",
            levels: [
                CampaignLevel(
                    id: 11, worldIndex: 3, worldTitle: "Void League",
                    title: "Hard Line", objective: "Win to 7 · Hard · Classic",
                    difficulty: .hard, gameMode: .classic, scoreLimit: 7, requiresShutoutForThreeStars: false
                ),
                CampaignLevel(
                    id: 12, worldIndex: 3, worldTitle: "Void League",
                    title: "Crimson Ace", objective: "Win to 9 · Hard · Classic",
                    difficulty: .hard, gameMode: .classic, scoreLimit: 9, requiresShutoutForThreeStars: false
                ),
                CampaignLevel(
                    id: 13, worldIndex: 3, worldTitle: "Void League",
                    title: "Hazard Zone", objective: "Win to 9 · Hard · Power-Ups",
                    difficulty: .hard, gameMode: .powerUps, scoreLimit: 9, requiresShutoutForThreeStars: false
                ),
                CampaignLevel(
                    id: 14, worldIndex: 3, worldTitle: "Void League",
                    title: "Perfect Run", objective: "Win to 7 · Shutout for 3★",
                    difficulty: .hard, gameMode: .classic, scoreLimit: 7, requiresShutoutForThreeStars: true
                ),
                CampaignLevel(
                    id: 15, worldIndex: 3, worldTitle: "Void League",
                    title: "Final Glow", objective: "Win to 11 · Hard · Power-Ups",
                    difficulty: .hard, gameMode: .powerUps, scoreLimit: 11, requiresShutoutForThreeStars: false
                ),
            ]
        ),
    ]

    static var allLevels: [CampaignLevel] {
        worlds.flatMap(\.levels)
    }

    static func level(id: Int) -> CampaignLevel? {
        allLevels.first { $0.id == id }
    }

    static func nextLevel(after id: Int) -> CampaignLevel? {
        level(id: id + 1)
    }

    static func previousLevel(before id: Int) -> CampaignLevel? {
        guard id > 1 else { return nil }
        return level(id: id - 1)
    }
}
