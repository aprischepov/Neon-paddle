import Foundation

struct CampaignLevel: Equatable {
    let id: Int
    let worldIndex: Int
    let worldTitle: String
    let title: String
    let objective: String
    let difficulty: AIDifficulty
    let gameMode: GameMode
    let scoreLimit: Int
    let requiresShutoutForThreeStars: Bool

    var displayNumber: String {
        String(id)
    }
}

struct CampaignWorld: Equatable {
    let index: Int
    let title: String
    let subtitle: String
    let levels: [CampaignLevel]
}
