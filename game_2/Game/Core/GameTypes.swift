import Foundation
import SpriteKit

enum GameSessionState {
    case playing
    case paused
    case gameOver
}

enum AIDifficulty: Int, CaseIterable {
    case easy
    case normal
    case hard

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        }
    }

    var enemySpeed: CGFloat {
        switch self {
        case .easy: return 190
        case .normal: return 260
        case .hard: return 340
        }
    }
}

enum GameMode: Int, CaseIterable {
    case classic
    case powerUps
    case localTwoPlayer

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .powerUps: return "Power-Ups"
        case .localTwoPlayer: return "2 Players"
        }
    }

    var usesAIOpponent: Bool {
        self != .localTwoPlayer
    }

    var recordsLeaderboard: Bool {
        self != .localTwoPlayer
    }
}

enum BallOwner {
    case player
    case enemy
}

enum PhysicsCategory {
    static let ball: UInt32 = 1 << 0
    static let paddle: UInt32 = 1 << 1
    static let boundary: UInt32 = 1 << 2
    static let obstacle: UInt32 = 1 << 3
    static let fieldObject: UInt32 = 1 << 4
}

enum GameNodeName {
    static let pauseButton = "pauseButton"
    static let resumeButton = "resumeButton"
    static let exitButton = "exitButton"
    static let playAgainButton = "playAgainButton"
    static let menuButton = "menuButton"
}

protocol GameSceneDelegate: AnyObject {
    func gameSceneDidRequestMainMenu(_ scene: GameScene)
    func gameSceneDidFinishCampaignLevel(_ scene: GameScene, levelID: Int, stars: Int, won: Bool)
    func gameSceneDidRequestNextCampaignLevel(_ scene: GameScene, level: CampaignLevel)
}
