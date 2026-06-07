import SpriteKit
import UIKit
import CoreImage
import AVFoundation

final class GameScene: SKScene, SKPhysicsContactDelegate {
    weak var gameDelegate: GameSceneDelegate?
    var campaignLevel: CampaignLevel?
    var campaignLastStars = 0
    var campaignOffersNextLevel = false

    let difficultyInterval = 10
    let backgroundChangeInterval = 5
    let obstacleInterval = 15
    let baseBackgroundColor = UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 1)
    let playerColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 1)
    let enemyColor = UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 1)
    let maxPaddleSpinVelocity: CGFloat = 1_450
    let paddleSpinTransfer: CGFloat = 0.72
    let paddleLerpFactor: CGFloat = 0.18
    let lightImpactFeedback = UIImpactFeedbackGenerator(style: .light)
    let heavyImpactFeedback = UIImpactFeedbackGenerator(style: .heavy)
    lazy var particleTexture = makeParticleTexture()
    lazy var trailTexture = makeTrailTexture()
    lazy var confettiTexture = makeConfettiTexture()
    lazy var starTexture = makeStarTexture()
    var backgroundNode: SKSpriteNode?
    var backgroundPulseNode: SKSpriteNode?
    var worldNode: SKNode?
    var paddle: SKShapeNode?
    var enemyPaddle: SKShapeNode?
    var ball: Ball?
    var ballTrail: SKEmitterNode?
    var fieldObjects: [FieldObject] = []
    var scoreboardLabel: SKLabelNode?
    var overlayNode: SKNode?
    var startTime: TimeInterval = 0
    var lastUpdateTime: TimeInterval = 0
    var lastDifficultyStep = 0
    var lastBackgroundStep = 0
    var lastObstacleStep = 0
    var lastPaddleMoveTime: TimeInterval = 0
    var lastPaddleX: CGFloat = 0
    var targetPaddleX: CGFloat?
    var targetEnemyPaddleX: CGFloat?
    var paddleVelocityX: CGFloat = 0
    var enemyPaddleVelocityX: CGFloat = 0
    var lastEnemyPaddleMoveTime: TimeInterval = 0
    var selectedScoreLimit = 11
    var lastBallOwner: BallOwner?
    var pausedBallVelocity: CGVector?
    var isCountingDown = false
    var playerHasShield = false
    var enemyHasShield = false
    var playerIsDebuffed = false
    var enemyIsDebuffed = false
    var playerScore = 0
    var enemyScore = 0
    var currentScore = 0
    var gameState: GameSessionState = .playing
    var hasPresentedInitialLayout = false
    var lastLayoutSafeFrame: CGRect = .zero
    let backgroundColors: [UIColor] = [
        UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 1),
        UIColor(red: 0.055, green: 0.075, blue: 0.085, alpha: 1),
        UIColor(red: 0.085, green: 0.055, blue: 0.078, alpha: 1)
    ]

    override func didMove(to view: SKView) {
        backgroundColor = baseBackgroundColor
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        SoundManager.shared.configure(hostNode: self)
        startGame()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard view != nil else { return }
        if !hasPresentedInitialLayout {
            hasPresentedInitialLayout = true
            lastLayoutSafeFrame = safeFrame
            return
        }
        relayoutSceneForCurrentSize()
    }

    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing else { return }
        guard !isCountingDown else {
            lastUpdateTime = currentTime
            return
        }
        if startTime == 0 {
            startTime = currentTime
        }
        let deltaTime = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        currentScore = Int(currentTime - startTime)
        applyDifficultyIfNeeded(score: currentScore)
        updateBackgroundIfNeeded(score: currentScore)
        spawnObstacleIfNeeded(score: currentScore)
        updatePlayerPaddle(deltaTime: deltaTime)
        updatePaddleVelocityDecay(currentTime: currentTime)
        if matchGameMode == .localTwoPlayer {
            updateEnemyPaddleVelocityDecay(currentTime: currentTime)
        }
        updateEnemyPaddle(deltaTime: deltaTime)
        updateBallStretch()
        updateBallTrail()
        handleGoalIfNeeded()
        currentScore = Int(currentTime - startTime)
    }
}
