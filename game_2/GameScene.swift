//
//  GameScene.swift
//  game_2
//
//  Created by Artem Prischepov on 1.05.26.
//

import SpriteKit
import UIKit
import CoreImage
import AVFoundation

final class SoundManager {
    static let shared = SoundManager()

    static let soundEnabledKey = "soundEnabled"

    private let defaults: UserDefaults
    private var players: [String: AVAudioPlayer] = [:]

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func configure(hostNode: SKNode) {
        preloadSounds()
    }

    func playHitSound() {
        playSoundFileNamed("hit.wav")
    }

    func playScoreSound() {
        playSoundFileNamed("score.wav")
    }

    func preloadSounds() {
        ["hit.wav", "score.wav"].forEach { fileName in
            guard players[fileName] == nil else { return }
            guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else { return }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[fileName] = player
            } catch {
                players[fileName] = nil
            }
        }
    }

    private var isSoundEnabled: Bool {
        defaults.object(forKey: Self.soundEnabledKey) as? Bool ?? true
    }

    private func playSoundFileNamed(_ fileName: String) {
        guard isSoundEnabled else { return }

        if players[fileName] == nil {
            preloadSounds()
        }

        guard let player = players[fileName] else { return }
        player.currentTime = 0
        player.play()
    }
}

final class Ball: SKShapeNode {
    var lastTouchedBy = ""

    init(radius: CGFloat) {
        super.init()
        path = CGPath(
            ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
            transform: nil
        )
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

final class FieldObject: SKShapeNode {
    enum ObjectType {
        case buff
        case hazard

        var color: UIColor {
            switch self {
            case .buff:
                return UIColor(red: 0.18, green: 1.0, blue: 0.38, alpha: 1)
            case .hazard:
                return UIColor(red: 1.0, green: 0.12, blue: 0.18, alpha: 1)
            }
        }
    }

    let objectType: ObjectType

    init(type: ObjectType, sides: Int, radius: CGFloat) {
        objectType = type
        super.init()
        path = Self.makePolygonPath(sides: sides, radius: radius)
        fillColor = type.color.withAlphaComponent(0.22)
        strokeColor = type.color
        lineWidth = 2.4
        glowWidth = 10
        addNeonGlow(color: type.color)
    }

    required init?(coder aDecoder: NSCoder) {
        objectType = .buff
        super.init(coder: aDecoder)
    }

    private static func makePolygonPath(sides: Int, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let clampedSides = max(sides, 3)

        for index in 0..<clampedSides {
            let angle = CGFloat(index) / CGFloat(clampedSides) * .pi * 2 + .pi / 2
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    func startAliveAnimation() {
        run(.repeatForever(.rotate(byAngle: .pi, duration: 2.0)), withKey: "fieldRotate")
        run(.repeatForever(.sequence([
            .scale(to: 1.08, duration: 1.0),
            .scale(to: 1.0, duration: 1.0)
        ])), withKey: "fieldPulse")
    }

    private func addNeonGlow(color: UIColor) {
        guard let path else { return }

        let glowEffect = SKEffectNode()
        glowEffect.name = "neonGlow"
        glowEffect.zPosition = -1
        glowEffect.filter = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 9])
        glowEffect.shouldRasterize = true

        let innerGlow = SKShapeNode(path: path)
        innerGlow.fillColor = color
        innerGlow.strokeColor = color
        innerGlow.lineWidth = 7
        innerGlow.alpha = 0.88
        innerGlow.blendMode = .add
        glowEffect.addChild(innerGlow)

        let outerGlow = SKShapeNode(path: path)
        outerGlow.fillColor = color
        outerGlow.strokeColor = color
        outerGlow.lineWidth = 14
        outerGlow.alpha = 0.38
        outerGlow.blendMode = .add
        glowEffect.addChild(outerGlow)

        addChild(glowEffect)
    }
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    private enum GameState {
        case start
        case settings
        case playing
        case paused
        case gameOver
    }

    private enum AIDifficulty: Int, CaseIterable {
        case easy
        case normal
        case hard

        var title: String {
            switch self {
            case .easy:
                return "Easy"
            case .normal:
                return "Normal"
            case .hard:
                return "Hard"
            }
        }

        var enemySpeed: CGFloat {
            switch self {
            case .easy:
                return 190
            case .normal:
                return 260
            case .hard:
                return 340
            }
        }
    }

    private enum GameMode: Int, CaseIterable {
        case classic
        case powerUps

        var title: String {
            switch self {
            case .classic:
                return "Classic"
            case .powerUps:
                return "Power-Ups"
            }
        }
    }

    private enum BallOwner {
        case player
        case enemy
    }

    private enum PhysicsCategory {
        static let ball: UInt32 = 1 << 0
        static let paddle: UInt32 = 1 << 1
        static let boundary: UInt32 = 1 << 2
        static let obstacle: UInt32 = 1 << 3
        static let fieldObject: UInt32 = 1 << 4
    }

    private enum NodeName {
        static let playButton = "playButton"
        static let settingsButton = "settingsButton"
        static let backButton = "backButton"
        static let difficultyLeft = "difficultyLeft"
        static let difficultyRight = "difficultyRight"
        static let gameModeLeft = "gameModeLeft"
        static let gameModeRight = "gameModeRight"
        static let privacyButton = "privacyButton"
        static let termsButton = "termsButton"
        static let menuButton = "menuButton"
        static let pauseButton = "pauseButton"
        static let resumeButton = "resumeButton"
        static let exitButton = "exitButton"
        static let playAgainButton = "playAgainButton"
    }

    private var paddleSize: CGSize {
        let width = isLandscapeLayout
            ? min(max(safeFrame.width * 0.24, 150), 230)
            : min(max(safeFrame.width * 0.36, 128), 160)
        return CGSize(width: width, height: isLandscapeLayout ? 16 : 18)
    }

    private var enemyPaddleSize: CGSize {
        let playerSize = paddleSize
        return CGSize(width: playerSize.width * 0.86, height: max(playerSize.height - 2, 14))
    }

    private var ballRadius: CGFloat {
        isLandscapeLayout ? 13 : 16
    }

    private var paddleBottomOffset: CGFloat {
        isLandscapeLayout ? min(max(safeFrame.height * 0.13, 38), 56) : 72
    }

    private var enemyPaddleTopOffset: CGFloat {
        paddleBottomOffset
    }

    private let difficultyInterval = 10
    private let backgroundChangeInterval = 5
    private let obstacleInterval = 15
    private let baseBackgroundColor = UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 1)
    private let playerColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 1)
    private let enemyColor = UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 1)
    private let maxPaddleSpinVelocity: CGFloat = 1_450
    private let paddleSpinTransfer: CGFloat = 0.72
    private let paddleLerpFactor: CGFloat = 0.18
    private let lightImpactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let heavyImpactFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var particleTexture = makeParticleTexture()
    private lazy var trailTexture = makeTrailTexture()
    private lazy var confettiTexture = makeConfettiTexture()
    private lazy var starTexture = makeStarTexture()
    private var backgroundNode: SKSpriteNode?
    private var backgroundPulseNode: SKSpriteNode?
    private var worldNode: SKNode?
    private var paddle: SKShapeNode?
    private var enemyPaddle: SKShapeNode?
    private var ball: Ball?
    private var ballTrail: SKEmitterNode?
    private var fieldObjects: [FieldObject] = []
    private var scoreboardLabel: SKLabelNode?
    private var difficultyValueLabel: SKLabelNode?
    private var gameModeValueLabel: SKLabelNode?
    private var overlayNode: SKNode?
    private var startTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var lastDifficultyStep = 0
    private var lastBackgroundStep = 0
    private var lastObstacleStep = 0
    private var lastPaddleMoveTime: TimeInterval = 0
    private var lastPaddleX: CGFloat = 0
    private var targetPaddleX: CGFloat?
    private var paddleVelocityX: CGFloat = 0
    private var selectedDifficulty: AIDifficulty = .normal
    private var selectedGameMode: GameMode = .powerUps
    private var selectedScoreLimit = 11
    private var lastBallOwner: BallOwner?
    private var pausedBallVelocity: CGVector?
    private var isCountingDown = false
    private var playerHasShield = false
    private var enemyHasShield = false
    private var playerIsDebuffed = false
    private var enemyIsDebuffed = false
    private var playerScore = 0
    private var enemyScore = 0
    private var currentScore = 0
    private var gameState: GameState = .start
    private var hasPresentedInitialLayout = false
    private var lastLayoutSafeFrame: CGRect = .zero

    private let backgroundColors: [UIColor] = [
        UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 1),
        UIColor(red: 0.055, green: 0.075, blue: 0.085, alpha: 1),
        UIColor(red: 0.085, green: 0.055, blue: 0.078, alpha: 1)
    ]

    override func didMove(to view: SKView) {
        backgroundColor = baseBackgroundColor
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        SoundManager.shared.configure(hostNode: self)
        loadSettings()
        showStartScreen()
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

    private var safeFrame: CGRect {
        guard let view else { return frame }

        let insets = view.safeAreaInsets
        return CGRect(
            x: frame.minX + insets.left,
            y: frame.minY + insets.bottom,
            width: frame.width - insets.left - insets.right,
            height: frame.height - insets.top - insets.bottom
        )
    }

    private var isLandscapeLayout: Bool {
        safeFrame.width > safeFrame.height
    }

    private var titleFontSize: CGFloat {
        isLandscapeLayout ? min(max(safeFrame.height * 0.12, 34), 44) : 44
    }

    private var scoreboardFontSize: CGFloat {
        isLandscapeLayout ? min(max(safeFrame.height * 0.22, 70), 92) : 124
    }

    private func relayoutSceneForCurrentSize() {
        let previousSafeFrame = lastLayoutSafeFrame == .zero ? safeFrame : lastLayoutSafeFrame

        switch gameState {
        case .start:
            showStartScreen()
        case .settings:
            showSettingsScreen()
        case .playing:
            rebuildPlayingSceneForCurrentLayout(previousSafeFrame: previousSafeFrame)
        case .paused:
            let velocity = pausedBallVelocity ?? ball?.physicsBody?.velocity
            rebuildPlayingSceneForCurrentLayout(previousSafeFrame: previousSafeFrame, velocityOverride: velocity)
            pausedBallVelocity = velocity
            showPauseMenu()
        case .gameOver:
            let winner: BallOwner = playerScore >= enemyScore ? .player : .enemy
            rebuildPlayingSceneForCurrentLayout(previousSafeFrame: previousSafeFrame, velocityOverride: .zero)
            showMatchOver(winner: winner)
        }

        lastLayoutSafeFrame = safeFrame
    }

    private func rebuildPlayingSceneForCurrentLayout(
        previousSafeFrame: CGRect,
        velocityOverride: CGVector? = nil
    ) {
        let wasCountingDown = isCountingDown
        let savedPlayerScore = playerScore
        let savedEnemyScore = enemyScore
        let savedCurrentScore = currentScore
        let savedStartTime = startTime
        let savedLastUpdateTime = lastUpdateTime
        let savedDifficultyStep = lastDifficultyStep
        let savedBackgroundStep = lastBackgroundStep
        let savedObstacleStep = lastObstacleStep
        let savedLastOwner = lastBallOwner
        let savedBallTouchedBy = ball?.lastTouchedBy ?? "Player"
        let savedPlayerHasShield = playerHasShield
        let savedEnemyHasShield = enemyHasShield
        let savedPlayerIsDebuffed = playerIsDebuffed
        let savedEnemyIsDebuffed = enemyIsDebuffed
        let savedVelocity = velocityOverride ?? ball?.physicsBody?.velocity ?? .zero
        let defaultBallPosition = CGPoint(x: safeFrame.midX, y: safeFrame.midY)
        let normalizedBallPosition = normalizedPoint(ball?.position ?? defaultBallPosition, in: previousSafeFrame)

        removeAllChildren()
        clearGameReferences()
        physicsWorld.speed = 1
        gameState = .playing

        playerScore = savedPlayerScore
        enemyScore = savedEnemyScore
        currentScore = savedCurrentScore
        startTime = savedStartTime
        lastUpdateTime = savedLastUpdateTime
        lastDifficultyStep = savedDifficultyStep
        lastBackgroundStep = savedBackgroundStep
        lastObstacleStep = savedObstacleStep
        lastBallOwner = savedLastOwner
        playerHasShield = savedPlayerHasShield
        enemyHasShield = savedEnemyHasShield
        playerIsDebuffed = savedPlayerIsDebuffed
        enemyIsDebuffed = savedEnemyIsDebuffed

        createWorldNode()
        setupBackground()
        createScreenBoundaries()
        createPaddle()
        createEnemyPaddle()
        createBall()
        createScoreLabel()
        createPauseButton()

        ball?.position = clampedBallPosition(point(from: normalizedBallPosition, in: safeFrame))
        ball?.lastTouchedBy = savedBallTouchedBy
        setBallOwnerColor(savedBallTouchedBy == "AI" ? .enemy : .player)
        updatePaddleScale(for: .player)
        updatePaddleScale(for: .enemy)

        if wasCountingDown {
            startCountdown { [weak self] in
                self?.launchBall(with: self?.makeRandomStartVelocity() ?? .zero)
                self?.schedulePowerUpsIfNeeded()
            }
        } else if isZeroVelocity(savedVelocity) {
            ball?.physicsBody?.velocity = .zero
            ballTrail?.particleBirthRate = 0
        } else {
            launchBall(with: limitedVelocity(savedVelocity))
            schedulePowerUpsIfNeeded(delay: 1.0)
        }
    }

    private func normalizedPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        guard rect.width > 0, rect.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        return CGPoint(
            x: min(max((point.x - rect.minX) / rect.width, 0), 1),
            y: min(max((point.y - rect.minY) / rect.height, 0), 1)
        )
    }

    private func point(from normalizedPoint: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width * normalizedPoint.x,
            y: rect.minY + rect.height * normalizedPoint.y
        )
    }

    private func clampedBallPosition(_ position: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(position.x, safeFrame.minX + ballRadius), safeFrame.maxX - ballRadius),
            y: min(max(position.y, safeFrame.minY + ballRadius), safeFrame.maxY - ballRadius)
        )
    }

    private func isZeroVelocity(_ velocity: CGVector) -> Bool {
        abs(velocity.dx) < 0.001 && abs(velocity.dy) < 0.001
    }

    private func showStartScreen() {
        isPaused = false
        removeAllChildren()
        clearGameReferences()
        physicsWorld.speed = 0
        gameState = .start
        createWorldNode()
        setupBackground()
        createBlurredBackdrop(zPosition: 60)

        let safeFrame = self.safeFrame
        let menuOverlay = SKNode()
        menuOverlay.zPosition = 90
        menuOverlay.alpha = 0
        addChild(menuOverlay)
        overlayNode = menuOverlay

        let titleLabel = makeLabel(text: "NEON PADDLE", size: titleFontSize, weight: .bold)
        titleLabel.alpha = 0.94
        titleLabel.position = CGPoint(x: safeFrame.midX, y: safeFrame.midY + min(72, safeFrame.height * 0.18))
        menuOverlay.addChild(titleLabel)

        let playButton = makeButton(title: "START", name: NodeName.playButton)
        playButton.position = CGPoint(
            x: safeFrame.midX,
            y: safeFrame.midY - (isLandscapeLayout ? min(18, safeFrame.height * 0.06) : 34)
        )
        menuOverlay.addChild(playButton)

        let settingsButton = makeButton(title: "SETTINGS", name: NodeName.settingsButton)
        settingsButton.setScale(0.84)
        settingsButton.alpha = 0.84
        settingsButton.position = CGPoint(
            x: safeFrame.midX,
            y: playButton.position.y - (isLandscapeLayout ? 56 : 70)
        )
        menuOverlay.addChild(settingsButton)

        menuOverlay.run(.fadeIn(withDuration: 0.3))
        hasPresentedInitialLayout = true
        lastLayoutSafeFrame = safeFrame
    }

    private func showSettingsScreen() {
        isPaused = false
        removeAllChildren()
        clearGameReferences()
        physicsWorld.speed = 0
        gameState = .settings
        createWorldNode()
        setupBackground()
        createBlurredBackdrop(zPosition: 60)

        let safeFrame = self.safeFrame
        let settingsOverlay = SKNode()
        settingsOverlay.zPosition = 90
        settingsOverlay.alpha = 0
        addChild(settingsOverlay)
        overlayNode = settingsOverlay

        let titleLabel = makeLabel(text: "SETTINGS", size: isLandscapeLayout ? 34 : 40, weight: .bold)
        titleLabel.alpha = 0.94
        titleLabel.position = CGPoint(x: safeFrame.midX, y: safeFrame.midY + (isLandscapeLayout ? 104 : 170))
        settingsOverlay.addChild(titleLabel)

        createSettingsPicker(
            title: "Difficulty",
            value: selectedDifficulty.title,
            y: safeFrame.midY + (isLandscapeLayout ? 42 : 88),
            leftName: NodeName.difficultyLeft,
            rightName: NodeName.difficultyRight,
            in: settingsOverlay
        ) { [weak self] label in
            self?.difficultyValueLabel = label
        }

        createSettingsPicker(
            title: "Mode",
            value: selectedGameMode.title,
            y: safeFrame.midY + (isLandscapeLayout ? -26 : 6),
            leftName: NodeName.gameModeLeft,
            rightName: NodeName.gameModeRight,
            in: settingsOverlay
        ) { [weak self] label in
            self?.gameModeValueLabel = label
        }

        let legalY = safeFrame.midY + (isLandscapeLayout ? -96 : -88)
        let privacyButton = makeButton(title: "PRIVACY", name: NodeName.privacyButton)
        privacyButton.setScale(0.76)
        privacyButton.position = CGPoint(x: safeFrame.midX - 78, y: legalY)
        settingsOverlay.addChild(privacyButton)

        let termsButton = makeButton(title: "TERMS", name: NodeName.termsButton)
        termsButton.setScale(0.76)
        termsButton.position = CGPoint(x: safeFrame.midX + 78, y: legalY)
        settingsOverlay.addChild(termsButton)

        let backButton = makeButton(title: "BACK", name: NodeName.backButton)
        backButton.setScale(0.78)
        backButton.alpha = 0.84
        backButton.position = CGPoint(x: safeFrame.midX, y: safeFrame.midY + (isLandscapeLayout ? -154 : -168))
        settingsOverlay.addChild(backButton)

        settingsOverlay.run(.fadeIn(withDuration: 0.3))
        hasPresentedInitialLayout = true
        lastLayoutSafeFrame = safeFrame
    }

    private func clearGameReferences() {
        backgroundNode = nil
        backgroundPulseNode = nil
        paddle = nil
        enemyPaddle = nil
        ball = nil
        ballTrail = nil
        fieldObjects = []
        worldNode = nil
        scoreboardLabel = nil
        difficultyValueLabel = nil
        gameModeValueLabel = nil
        overlayNode = nil
        pausedBallVelocity = nil
        isCountingDown = false
        playerHasShield = false
        enemyHasShield = false
        playerIsDebuffed = false
        enemyIsDebuffed = false
        removeAction(forKey: "playerBuffRecovery")
        removeAction(forKey: "enemyBuffRecovery")
        removeAction(forKey: "playerDebuffRecovery")
        removeAction(forKey: "enemyDebuffRecovery")
        removeAction(forKey: "fieldObjectSpawnDelay")
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: SettingsKey.difficulty) == nil {
            selectedDifficulty = .normal
        } else if let difficulty = AIDifficulty(rawValue: defaults.integer(forKey: SettingsKey.difficulty)) {
            selectedDifficulty = difficulty
        }

        if defaults.object(forKey: SettingsKey.gameMode) == nil {
            selectedGameMode = .powerUps
        } else if let gameMode = GameMode(rawValue: defaults.integer(forKey: SettingsKey.gameMode)) {
            selectedGameMode = gameMode
        }
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(selectedDifficulty.rawValue, forKey: SettingsKey.difficulty)
        defaults.set(selectedGameMode.rawValue, forKey: SettingsKey.gameMode)
    }

    private enum SettingsKey {
        static let difficulty = "selectedDifficulty"
        static let gameMode = "selectedGameMode"
    }

    private func createWorldNode() {
        let worldNode = SKNode()
        worldNode.name = "worldNode"
        worldNode.zPosition = 0
        addChild(worldNode)
        self.worldNode = worldNode
    }

    private func addWorldChild(_ node: SKNode) {
        if let worldNode {
            worldNode.addChild(node)
        } else {
            addChild(node)
        }
    }

    private func createPicker(
        title: String,
        value: String,
        y: CGFloat,
        leftName: String,
        rightName: String,
        valueHandler: (SKLabelNode) -> Void
    ) {
        let safeFrame = self.safeFrame
        let titleLabel = makeLabel(text: title.uppercased(), size: 13, weight: .semibold)
        titleLabel.alpha = 0.52
        titleLabel.position = CGPoint(x: safeFrame.midX, y: y + 28)
        addChild(titleLabel)

        let leftArrow = makeLabel(text: "<", size: 34, weight: .bold)
        leftArrow.name = leftName
        leftArrow.position = CGPoint(x: safeFrame.midX - 112, y: y - 2)
        addChild(leftArrow)

        let valueLabel = makeLabel(text: value, size: 30, weight: .light)
        valueLabel.position = CGPoint(x: safeFrame.midX, y: y)
        addChild(valueLabel)
        valueHandler(valueLabel)

        let rightArrow = makeLabel(text: ">", size: 34, weight: .bold)
        rightArrow.name = rightName
        rightArrow.position = CGPoint(x: safeFrame.midX + 112, y: y - 2)
        addChild(rightArrow)
    }

    private func createSettingsPicker(
        title: String,
        value: String,
        y: CGFloat,
        leftName: String,
        rightName: String,
        in parent: SKNode,
        valueHandler: (SKLabelNode) -> Void
    ) {
        let safeFrame = self.safeFrame
        let titleLabel = makeLabel(text: title.uppercased(), size: isLandscapeLayout ? 12 : 13, weight: .semibold)
        titleLabel.alpha = 0.58
        titleLabel.position = CGPoint(x: safeFrame.midX, y: y + (isLandscapeLayout ? 23 : 28))
        parent.addChild(titleLabel)

        let arrowOffset = isLandscapeLayout ? min(safeFrame.width * 0.14, 124) : 112
        let leftArrow = makeLabel(text: "<", size: isLandscapeLayout ? 30 : 34, weight: .bold)
        leftArrow.name = leftName
        leftArrow.position = CGPoint(x: safeFrame.midX - arrowOffset, y: y - 2)
        parent.addChild(leftArrow)

        let valueLabel = makeLabel(text: value, size: isLandscapeLayout ? 26 : 30, weight: .light)
        valueLabel.position = CGPoint(x: safeFrame.midX, y: y)
        parent.addChild(valueLabel)
        valueHandler(valueLabel)

        let rightArrow = makeLabel(text: ">", size: isLandscapeLayout ? 30 : 34, weight: .bold)
        rightArrow.name = rightName
        rightArrow.position = CGPoint(x: safeFrame.midX + arrowOffset, y: y - 2)
        parent.addChild(rightArrow)
    }

    private func setupBackground() {
        let backgroundNode = SKSpriteNode(color: backgroundColors[0], size: size)
        backgroundNode.position = CGPoint(x: frame.midX, y: frame.midY)
        backgroundNode.zPosition = -100
        addWorldChild(backgroundNode)

        self.backgroundNode = backgroundNode

        createSpaceBackground()
        createGrid()
        createParticleStars()

        let pulseNode = SKSpriteNode(color: .clear, size: size)
        pulseNode.position = CGPoint(x: frame.midX, y: frame.midY)
        pulseNode.alpha = 0
        pulseNode.zPosition = -89
        pulseNode.blendMode = .add
        addWorldChild(pulseNode)
        backgroundPulseNode = pulseNode

        let topGlow = makeGlow(
            radius: size.width * 0.8,
            color: playerColor,
            alpha: 0.12
        )
        topGlow.position = CGPoint(x: frame.midX, y: frame.maxY + size.width * 0.25)
        addWorldChild(topGlow)

        let bottomGlow = makeGlow(
            radius: size.width * 0.65,
            color: enemyColor,
            alpha: 0.10
        )
        bottomGlow.position = CGPoint(x: frame.midX, y: frame.minY - size.width * 0.28)
        addWorldChild(bottomGlow)

    }

    private func createSpaceBackground() {
        let texture = SKTexture(imageNamed: "bgSpace")
        let spaceBackground = SKSpriteNode(texture: texture)
        spaceBackground.zPosition = -10
        spaceBackground.alpha = 0.56
        spaceBackground.position = .zero
        spaceBackground.size = aspectFillSize(for: texture.size(), in: size)

        let blurNode = SKEffectNode()
        blurNode.zPosition = -99
        blurNode.position = CGPoint(x: frame.midX, y: frame.midY)
        blurNode.filter = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 2.5])
        blurNode.shouldRasterize = true
        blurNode.addChild(spaceBackground)
        addWorldChild(blurNode)

        blurNode.run(.repeatForever(.sequence([
            .scale(to: 1.05, duration: 60),
            .scale(to: 1.0, duration: 60)
        ])), withKey: "spacePulse")
    }

    private func aspectFillSize(for textureSize: CGSize, in targetSize: CGSize) -> CGSize {
        guard textureSize.width > 0, textureSize.height > 0 else { return targetSize }

        let scale = max(targetSize.width / textureSize.width, targetSize.height / textureSize.height)
        return CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
    }

    private func createGrid() {
        let spacing: CGFloat = 36
        let gridPath = CGMutablePath()
        var x = frame.minX

        while x <= frame.maxX {
            gridPath.move(to: CGPoint(x: x, y: frame.minY))
            gridPath.addLine(to: CGPoint(x: x, y: frame.maxY))
            x += spacing
        }

        var y = frame.minY
        while y <= frame.maxY {
            gridPath.move(to: CGPoint(x: frame.minX, y: y))
            gridPath.addLine(to: CGPoint(x: frame.maxX, y: y))
            y += spacing
        }

        let grid = SKShapeNode(path: gridPath)
        grid.strokeColor = UIColor(white: 0.22, alpha: 1)
        grid.lineWidth = 0.7
        grid.alpha = 0.18
        grid.zPosition = -96
        addWorldChild(grid)
    }

    private func createParticleStars() {
        let stars = SKEmitterNode()
        stars.position = CGPoint(x: frame.midX, y: frame.minY - 20)
        stars.particlePositionRange = CGVector(dx: frame.width, dy: 0)
        stars.particleTexture = starTexture
        stars.particleBirthRate = 10
        stars.particleLifetime = 9
        stars.particleLifetimeRange = 3
        stars.particleSpeed = 18
        stars.particleSpeedRange = 8
        stars.emissionAngle = .pi / 2
        stars.emissionAngleRange = .pi / 16
        stars.particleAlpha = 0.28
        stars.particleAlphaRange = 0.12
        stars.particleAlphaSpeed = -0.02
        stars.particleScale = 0.08
        stars.particleScaleRange = 0.04
        stars.particleColor = UIColor(white: 0.75, alpha: 1)
        stars.particleColorBlendFactor = 1
        stars.zPosition = -94
        addWorldChild(stars)
    }

    private func pulseBackground(with color: UIColor) {
        backgroundPulseNode?.removeAction(forKey: "impactPulse")
        backgroundPulseNode?.color = color
        backgroundPulseNode?.colorBlendFactor = 1
        backgroundPulseNode?.alpha = 0
        backgroundPulseNode?.run(.sequence([
            .fadeAlpha(to: 0.13, duration: 0.035),
            .fadeOut(withDuration: 0.22)
        ]), withKey: "impactPulse")
    }

    private func makeGlow(radius: CGFloat, color: UIColor, alpha: CGFloat) -> SKShapeNode {
        let glow = SKShapeNode(circleOfRadius: radius)
        glow.fillColor = color
        glow.strokeColor = .clear
        glow.alpha = alpha
        glow.zPosition = -95
        glow.blendMode = .add
        return glow
    }

    private func makeLabel(text: String, size: CGFloat, weight: UIFont.Weight) -> SKLabelNode {
        let baseFont = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor
        let font = UIFont(descriptor: descriptor, size: size)
        let label = SKLabelNode(fontNamed: font.fontName)
        label.text = text
        label.fontSize = size
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        return label
    }

    private func makeScoreboardLabel(text: String, size: CGFloat) -> SKLabelNode {
        let font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: .black)
        let label = SKLabelNode(fontNamed: font.fontName)
        label.text = text
        label.fontSize = size
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        return label
    }

    private func makeButton(title: String, name: String) -> SKShapeNode {
        let buttonSize = CGSize(width: 160, height: 54)
        let button = SKShapeNode(rectOf: buttonSize, cornerRadius: 16)
        button.name = name
        button.fillColor = .clear
        button.strokeColor = .white
        button.lineWidth = 1.5

        let titleLabel = makeLabel(text: title, size: 26, weight: .semibold)
        titleLabel.name = name
        titleLabel.position = .zero
        button.addChild(titleLabel)

        return button
    }

    private func buttonNode(from node: SKNode, named name: String) -> SKNode? {
        var currentNode: SKNode? = node
        var matchedNode: SKNode?

        while let node = currentNode {
            if node.name == name {
                matchedNode = node
            }

            currentNode = node.parent
        }

        return matchedNode
    }

    private func animateButtonPress(_ button: SKNode?, completion: @escaping () -> Void) {
        guard let button else {
            completion()
            return
        }

        isPaused = false
        let originalScale = button.xScale
        button.removeAction(forKey: "buttonPress")
        button.run(.sequence([
            .scale(to: originalScale * 1.08, duration: 0.06),
            .scale(to: originalScale, duration: 0.08),
            .run(completion)
        ]), withKey: "buttonPress")
    }

    private func fadeOutActiveOverlay(completion: @escaping () -> Void) {
        let nodes = [overlayNode, childNode(withName: "blurredBackdrop")].compactMap { $0 }

        guard !nodes.isEmpty else {
            completion()
            return
        }

        nodes.forEach { $0.run(.fadeOut(withDuration: 0.3)) }
        run(.sequence([
            .wait(forDuration: 0.3),
            .run { [weak self] in
                nodes.forEach { $0.removeFromParent() }
                self?.overlayNode = nil
                completion()
            }
        ]))
    }

    private func startGame() {
        removeAllChildren()
        clearGameReferences()
        physicsWorld.speed = 1
        startTime = 0
        lastUpdateTime = 0
        playerScore = 0
        enemyScore = 0
        currentScore = 0
        lastDifficultyStep = 0
        lastBackgroundStep = 0
        lastObstacleStep = 0
        lastPaddleMoveTime = 0
        targetPaddleX = nil
        paddleVelocityX = 0
        lastBallOwner = nil
        gameState = .playing

        lightImpactFeedback.prepare()
        heavyImpactFeedback.prepare()
        prepareReusableAssets()

        createWorldNode()
        setupBackground()
        createScreenBoundaries()
        createPaddle()
        createEnemyPaddle()
        createBall()
        createScoreLabel()
        createPauseButton()
        startCountdown { [weak self] in
            self?.launchBall(with: self?.makeRandomStartVelocity() ?? .zero)
            self?.schedulePowerUpsIfNeeded()
        }
    }

    private func prepareReusableAssets() {
        _ = particleTexture
        _ = trailTexture
        _ = confettiTexture
        _ = starTexture
        SoundManager.shared.preloadSounds()
    }

    private func createPauseButton() {
        let safeFrame = self.safeFrame
        let pauseButton = SKLabelNode(text: "⏸")
        pauseButton.name = NodeName.pauseButton
        pauseButton.fontName = UIFont.systemFont(ofSize: 22, weight: .bold).fontName
        pauseButton.fontSize = 22
        pauseButton.fontColor = .white
        pauseButton.alpha = 0.48
        pauseButton.horizontalAlignmentMode = .center
        pauseButton.verticalAlignmentMode = .center
        pauseButton.position = CGPoint(x: safeFrame.maxX - 28, y: safeFrame.maxY - 28)
        pauseButton.zPosition = 65
        addChild(pauseButton)
    }

    private func createScreenBoundaries() {
        let playArea = safeFrame.insetBy(dx: ballRadius, dy: 8)
        addBoundary(
            from: CGPoint(x: playArea.minX, y: safeFrame.minY),
            to: CGPoint(x: playArea.minX, y: playArea.maxY)
        )
        addBoundary(
            from: CGPoint(x: playArea.maxX, y: safeFrame.minY),
            to: CGPoint(x: playArea.maxX, y: playArea.maxY)
        )
    }

    private func addBoundary(from startPoint: CGPoint, to endPoint: CGPoint) {
        let boundary = SKNode()
        boundary.physicsBody = SKPhysicsBody(edgeFrom: startPoint, to: endPoint)
        boundary.physicsBody?.categoryBitMask = PhysicsCategory.boundary
        boundary.physicsBody?.collisionBitMask = PhysicsCategory.ball
        boundary.physicsBody?.contactTestBitMask = PhysicsCategory.ball
        addWorldChild(boundary)
    }

    private func createPaddle() {
        let safeFrame = self.safeFrame
        let paddle = SKShapeNode(rectOf: paddleSize, cornerRadius: paddleSize.height / 2)
        paddle.fillColor = playerColor
        paddle.strokeColor = playerColor
        paddle.position = CGPoint(x: safeFrame.midX, y: safeFrame.minY + paddleBottomOffset)
        paddle.physicsBody = SKPhysicsBody(rectangleOf: paddleSize)
        paddle.physicsBody?.isDynamic = false
        paddle.physicsBody?.categoryBitMask = PhysicsCategory.paddle
        paddle.physicsBody?.collisionBitMask = PhysicsCategory.ball
        addWorldChild(paddle)

        let paddleGlow = SKShapeNode(rectOf: CGSize(width: paddleSize.width + 18, height: paddleSize.height + 12), cornerRadius: 15)
        paddleGlow.fillColor = playerColor
        paddleGlow.strokeColor = .clear
        paddleGlow.alpha = 0.34
        paddleGlow.blendMode = .add
        paddleGlow.zPosition = -1
        paddle.addChild(paddleGlow)

        self.paddle = paddle
        lastPaddleX = paddle.position.x
        targetPaddleX = paddle.position.x
    }

    private func createEnemyPaddle() {
        let safeFrame = self.safeFrame
        let enemyPaddle = SKShapeNode(rectOf: enemyPaddleSize, cornerRadius: enemyPaddleSize.height / 2)
        enemyPaddle.name = "enemyPaddle"
        enemyPaddle.fillColor = enemyColor
        enemyPaddle.strokeColor = .clear
        enemyPaddle.position = CGPoint(x: safeFrame.midX, y: safeFrame.maxY - enemyPaddleTopOffset)
        enemyPaddle.physicsBody = SKPhysicsBody(rectangleOf: enemyPaddleSize)
        enemyPaddle.physicsBody?.isDynamic = false
        enemyPaddle.physicsBody?.categoryBitMask = PhysicsCategory.paddle
        enemyPaddle.physicsBody?.collisionBitMask = PhysicsCategory.ball
        addWorldChild(enemyPaddle)

        let enemyGlow = SKShapeNode(rectOf: CGSize(width: enemyPaddleSize.width + 16, height: enemyPaddleSize.height + 10), cornerRadius: 13)
        enemyGlow.fillColor = enemyColor
        enemyGlow.strokeColor = .clear
        enemyGlow.alpha = 0.32
        enemyGlow.blendMode = .add
        enemyGlow.zPosition = -1
        enemyPaddle.addChild(enemyGlow)

        self.enemyPaddle = enemyPaddle
    }

    private func createBall() {
        let safeFrame = self.safeFrame
        let ball = Ball(radius: ballRadius)
        ball.fillColor = playerColor
        ball.strokeColor = playerColor
        ball.position = CGPoint(x: safeFrame.midX, y: safeFrame.midY)
        ball.physicsBody = SKPhysicsBody(circleOfRadius: ballRadius)
        ball.physicsBody?.affectedByGravity = false
        ball.physicsBody?.allowsRotation = false
        ball.physicsBody?.restitution = 1.0
        ball.physicsBody?.friction = 0
        ball.physicsBody?.linearDamping = 0
        ball.physicsBody?.angularDamping = 0
        ball.physicsBody?.categoryBitMask = PhysicsCategory.ball
        ball.physicsBody?.collisionBitMask = PhysicsCategory.paddle | PhysicsCategory.boundary | PhysicsCategory.obstacle
        ball.physicsBody?.contactTestBitMask = PhysicsCategory.paddle | PhysicsCategory.boundary | PhysicsCategory.obstacle | PhysicsCategory.fieldObject
        addWorldChild(ball)

        let ballGlow = SKShapeNode(circleOfRadius: ballRadius * 2)
        ballGlow.fillColor = playerColor
        ballGlow.strokeColor = .clear
        ballGlow.alpha = 0.38
        ballGlow.blendMode = .add
        ballGlow.zPosition = -1
        ballGlow.name = "ballGlow"
        ball.addChild(ballGlow)

        let trail = makeBallTrail()
        ball.addChild(trail)
        ballTrail = trail

        self.ball = ball
        ball.lastTouchedBy = "Player"
        setBallOwnerColor(.player)
        ball.physicsBody?.velocity = .zero
    }

    private func spawnFieldObjectsForRound() {
        clearFieldObjects()

        let objectCount = 1
        let zone = CGRect(
            x: safeFrame.minX + 52,
            y: safeFrame.midY - safeFrame.height * 0.18,
            width: safeFrame.width - 104,
            height: safeFrame.height * 0.36
        )

        guard zone.width > 0, zone.height > 0 else { return }

        for _ in 0..<objectCount {
            let type = [FieldObject.ObjectType.buff, .hazard].randomElement() ?? .buff
            let sides = Bool.random() ? 6 : 8
            let radius = CGFloat.random(in: 18...26)
            let object = FieldObject(type: type, sides: sides, radius: radius)
            object.name = "fieldObject"
            object.position = randomFieldObjectPosition(in: zone, radius: radius)
            object.zPosition = 4
            object.physicsBody = SKPhysicsBody(polygonFrom: object.path ?? CGPath(rect: .zero, transform: nil))
            object.physicsBody?.isDynamic = false
            object.physicsBody?.restitution = 1.0
            object.physicsBody?.friction = 0
            object.physicsBody?.categoryBitMask = PhysicsCategory.fieldObject
            object.physicsBody?.collisionBitMask = 0
            object.physicsBody?.contactTestBitMask = PhysicsCategory.ball
            object.startAliveAnimation()

            addWorldChild(object)
            fieldObjects.append(object)
        }
    }

    private func scheduleFieldObjectsForRound(delay: TimeInterval = 2.0) {
        clearFieldObjects()
        removeAction(forKey: "fieldObjectSpawnDelay")
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, self.gameState == .playing, !self.isCountingDown else { return }
                self.spawnFieldObjectsForRound()
            }
        ]), withKey: "fieldObjectSpawnDelay")
    }

    private func schedulePowerUpsIfNeeded(delay: TimeInterval = 2.0) {
        guard selectedGameMode == .powerUps else {
            clearFieldObjects()
            removeAction(forKey: "fieldObjectSpawnDelay")
            return
        }

        scheduleFieldObjectsForRound(delay: delay)
    }

    private func randomFieldObjectPosition(in zone: CGRect, radius: CGFloat) -> CGPoint {
        let centerPoint = CGPoint(x: safeFrame.midX, y: safeFrame.midY)

        for _ in 0..<16 {
            let position = CGPoint(
                x: CGFloat.random(in: zone.minX...zone.maxX),
                y: CGFloat.random(in: zone.minY...zone.maxY)
            )

            let isAwayFromBallSpawn = hypot(position.x - centerPoint.x, position.y - centerPoint.y) > ballRadius + radius + 34
            let isAwayFromOtherObjects = fieldObjects.allSatisfy {
                hypot(position.x - $0.position.x, position.y - $0.position.y) > radius + 42
            }

            if isAwayFromBallSpawn && isAwayFromOtherObjects {
                return position
            }
        }

        return CGPoint(
            x: CGFloat.random(in: zone.minX...zone.maxX),
            y: CGFloat.random(in: zone.minY...zone.maxY)
        )
    }

    private func clearFieldObjects() {
        fieldObjects.forEach { $0.removeFromParent() }
        fieldObjects.removeAll()
    }

    private func makeRandomStartVelocity() -> CGVector {
        let speed: CGFloat = 330
        let angle = CGFloat.random(in: 35...145) * .pi / 180
        return CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
    }

    private func launchBall(with velocity: CGVector) {
        physicsWorld.speed = 1
        ball?.physicsBody?.velocity = velocity
        ballTrail?.particleBirthRate = 70
        lastUpdateTime = 0
    }

    private func startCountdown(completion: @escaping () -> Void) {
        isCountingDown = true
        physicsWorld.speed = 0
        ball?.physicsBody?.velocity = .zero
        ballTrail?.particleBirthRate = 0

        let countdownOverlay = SKNode()
        countdownOverlay.name = "countdownOverlay"
        countdownOverlay.zPosition = 95
        countdownOverlay.alpha = 0
        addChild(countdownOverlay)

        let dim = SKSpriteNode(color: UIColor(white: 0, alpha: 0.38), size: size)
        dim.position = CGPoint(x: frame.midX, y: frame.midY)
        countdownOverlay.addChild(dim)

        let card = SKShapeNode(rectOf: CGSize(width: 190, height: 150), cornerRadius: 30)
        card.fillColor = UIColor(white: 0.02, alpha: 0.9)
        card.strokeColor = playerColor
        card.lineWidth = 2.5
        card.glowWidth = 8
        card.position = CGPoint(x: safeFrame.midX, y: safeFrame.midY)
        countdownOverlay.addChild(card)

        let countdownLabel = makeScoreboardLabel(text: "3", size: 82)
        countdownLabel.name = "countdownLabel"
        countdownLabel.fontColor = playerColor
        countdownLabel.alpha = 0
        countdownLabel.position = .zero
        card.addChild(countdownLabel)

        let steps = ["3", "2", "1", "GO!"]
        let actions = steps.flatMap { value in
            [
                SKAction.run { countdownLabel.text = value },
                SKAction.run {
                    countdownLabel.alpha = 0
                    countdownLabel.setScale(0.7)
                },
                SKAction.group([
                    .fadeIn(withDuration: 0.12),
                    .scale(to: 1.12, duration: 0.18)
                ]),
                SKAction.wait(forDuration: 0.28),
                SKAction.group([
                    .fadeOut(withDuration: 0.14),
                    .scale(to: 1.28, duration: 0.14)
                ])
            ]
        }

        countdownOverlay.run(.fadeIn(withDuration: 0.18))
        countdownLabel.run(.sequence(actions + [
            .run {
                countdownOverlay.run(.fadeOut(withDuration: 0.16))
            },
            .wait(forDuration: 0.16),
            .run {
                countdownOverlay.removeFromParent()
            },
            .removeFromParent(),
            .run { [weak self] in
                self?.isCountingDown = false
                completion()
            }
        ]))
    }

    private func createScoreLabel() {
        let safeFrame = self.safeFrame
        let scoreboardLabel = makeScoreboardLabel(text: "", size: scoreboardFontSize)
        scoreboardLabel.alpha = 0.22
        scoreboardLabel.zPosition = -30
        scoreboardLabel.position = CGPoint(x: safeFrame.midX, y: safeFrame.midY)
        addWorldChild(scoreboardLabel)

        self.scoreboardLabel = scoreboardLabel
        updateScoreLabel()
    }

    private func updateScoreLabel() {
        scoreboardLabel?.text = "\(playerScore):\(enemyScore)"
        scoreboardLabel?.fontColor = playerScore >= enemyScore ? playerColor : enemyColor
    }

    private func showMatchOver(winner: BallOwner) {
        guard gameState == .playing else { return }

        gameState = .gameOver
        physicsWorld.speed = 0
        ballTrail?.particleBirthRate = 0
        ball?.physicsBody?.velocity = .zero
        ball?.physicsBody?.angularVelocity = 0

        let safeFrame = self.safeFrame
        createBlurredBackdrop(zPosition: 70)

        let overlayHeight = isLandscapeLayout ? min(safeFrame.height - 28, 260) : 310
        let overlay = SKShapeNode(rectOf: CGSize(width: safeFrame.width - 36, height: overlayHeight), cornerRadius: 32)
        overlay.fillColor = UIColor(white: 0.02, alpha: 0.92)
        overlay.strokeColor = winner == .player ? playerColor : enemyColor
        overlay.lineWidth = 3
        overlay.position = CGPoint(x: safeFrame.midX, y: safeFrame.midY)
        overlay.zPosition = 80
        overlayNode = overlay
        addChild(overlay)

        let title = winner == .player ? "YOU WIN" : "YOU LOSE"
        let resultLabel = makeScoreboardLabel(text: title, size: isLandscapeLayout ? 34 : 40)
        resultLabel.fontColor = winner == .player ? playerColor : enemyColor
        resultLabel.position = CGPoint(x: 0, y: isLandscapeLayout ? 58 : 88)
        resultLabel.zPosition = 1
        overlay.addChild(resultLabel)

        let finalScoreLabel = makeScoreboardLabel(text: "\(playerScore):\(enemyScore)", size: isLandscapeLayout ? 30 : 34)
        finalScoreLabel.alpha = 0.9
        finalScoreLabel.position = CGPoint(x: 0, y: isLandscapeLayout ? 12 : 28)
        finalScoreLabel.zPosition = 1
        overlay.addChild(finalScoreLabel)

        let playAgainButton = makeButton(title: "PLAY AGAIN", name: NodeName.playAgainButton)
        if isLandscapeLayout {
            playAgainButton.setScale(0.82)
            playAgainButton.position = CGPoint(x: -92, y: -58)
        } else {
            playAgainButton.position = CGPoint(x: 0, y: -58)
        }
        playAgainButton.zPosition = 1
        overlay.addChild(playAgainButton)

        let menuButton = makeButton(title: "Menu", name: NodeName.menuButton)
        menuButton.setScale(isLandscapeLayout ? 0.82 : 0.78)
        menuButton.alpha = 0.78
        menuButton.position = isLandscapeLayout ? CGPoint(x: 92, y: -58) : CGPoint(x: 0, y: -122)
        menuButton.zPosition = 1
        overlay.addChild(menuButton)

        overlay.setScale(0.92)
        overlay.alpha = 0
        overlay.run(.group([
            .fadeIn(withDuration: 0.3),
            .scale(to: 1, duration: 0.3)
        ]))
    }

    private func showPauseMenu() {
        guard gameState == .playing else { return }

        isPaused = false
        gameState = .paused
        physicsWorld.speed = 0
        pausedBallVelocity = ball?.physicsBody?.velocity

        let safeFrame = self.safeFrame
        let pauseOverlay = SKNode()
        pauseOverlay.name = "pauseOverlay"
        pauseOverlay.zPosition = 90
        pauseOverlay.alpha = 0
        addChild(pauseOverlay)
        overlayNode = pauseOverlay

        createBlurredBackdrop(zPosition: 70)

        let cardHeight = isLandscapeLayout ? min(safeFrame.height - 32, 210) : 230
        let card = SKShapeNode(rectOf: CGSize(width: safeFrame.width - 48, height: cardHeight), cornerRadius: 28)
        card.fillColor = UIColor(white: 0.02, alpha: 0.9)
        card.strokeColor = playerColor
        card.lineWidth = 2
        card.position = CGPoint(x: safeFrame.midX, y: safeFrame.midY)
        pauseOverlay.addChild(card)

        let titleLabel = makeScoreboardLabel(text: "PAUSED", size: 38)
        titleLabel.fontColor = playerColor
        titleLabel.position = CGPoint(x: 0, y: 62)
        card.addChild(titleLabel)

        let resumeButton = makeButton(title: "RESUME", name: NodeName.resumeButton)
        resumeButton.position = CGPoint(x: 0, y: -18)
        card.addChild(resumeButton)

        let exitButton = makeButton(title: "EXIT", name: NodeName.exitButton)
        exitButton.setScale(0.78)
        exitButton.alpha = 0.78
        exitButton.position = CGPoint(x: 0, y: -82)
        card.addChild(exitButton)

        pauseOverlay.run(.sequence([
            .fadeIn(withDuration: 0.3),
            .run { [weak self] in
                self?.isPaused = true
            }
        ]))
    }

    private func resumeGame() {
        isPaused = false
        gameState = .playing
        let velocity = pausedBallVelocity ?? makeRandomStartVelocity()
        launchBall(with: velocity)
        pausedBallVelocity = nil
    }

    @discardableResult
    private func createBlurredBackdrop(zPosition: CGFloat) -> SKEffectNode {
        let backdrop = SKEffectNode()
        backdrop.name = "blurredBackdrop"
        backdrop.zPosition = zPosition
        backdrop.alpha = 0
        backdrop.filter = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 12])
        backdrop.shouldRasterize = true

        if let texture = view?.texture(from: self) {
            let snapshot = SKSpriteNode(texture: texture)
            snapshot.size = size
            snapshot.position = CGPoint(x: frame.midX, y: frame.midY)
            backdrop.addChild(snapshot)
        }

        let dim = SKSpriteNode(color: UIColor(white: 0, alpha: 0.38), size: size)
        dim.position = CGPoint(x: frame.midX, y: frame.midY)
        dim.zPosition = 1
        backdrop.addChild(dim)

        addChild(backdrop)
        backdrop.run(.fadeIn(withDuration: 0.3))
        return backdrop
    }

    private func checkMatchOver() {
        if playerScore >= selectedScoreLimit {
            showMatchOver(winner: .player)
        } else if enemyScore >= selectedScoreLimit {
            showMatchOver(winner: .enemy)
        }
    }

    private func applyDifficultyIfNeeded(score: Int) {
        let difficultyStep = score / difficultyInterval
        guard difficultyStep > lastDifficultyStep else { return }

        lastDifficultyStep = difficultyStep
        increaseBallImpulse()
    }

    private func updateBackgroundIfNeeded(score: Int) {
        let backgroundStep = score / backgroundChangeInterval
        guard backgroundStep > lastBackgroundStep else { return }

        lastBackgroundStep = backgroundStep

        let color = backgroundColors[backgroundStep % backgroundColors.count]
        let colorize = SKAction.colorize(with: color, colorBlendFactor: 1, duration: 1.2)
        backgroundNode?.run(colorize, withKey: "backgroundColorize")
    }

    private func spawnObstacleIfNeeded(score: Int) {
        guard selectedGameMode == .powerUps else { return }

        let obstacleStep = score / obstacleInterval
        guard obstacleStep > lastObstacleStep else { return }

        lastObstacleStep = obstacleStep
        createObstacle()
    }

    private func createObstacle() {
        let safeFrame = self.safeFrame
        let obstacleSize = CGSize(width: 34, height: 34)
        let minX = safeFrame.minX + obstacleSize.width
        let maxX = safeFrame.maxX - obstacleSize.width
        let minY = (paddle?.position.y ?? safeFrame.minY) + (isLandscapeLayout ? 72 : 120)
        let maxY = safeFrame.maxY - (isLandscapeLayout ? 64 : 90)
        guard minX < maxX, minY < maxY else { return }

        let obstacle = SKShapeNode(rectOf: obstacleSize, cornerRadius: 7)
        obstacle.fillColor = .white
        obstacle.strokeColor = .clear
        obstacle.alpha = 0.94
        obstacle.position = CGPoint(
            x: CGFloat.random(in: minX...maxX),
            y: CGFloat.random(in: minY...maxY)
        )
        obstacle.zPosition = 5
        obstacle.physicsBody = SKPhysicsBody(rectangleOf: obstacleSize)
        obstacle.physicsBody?.isDynamic = false
        obstacle.physicsBody?.restitution = 1.0
        obstacle.physicsBody?.friction = 0
        obstacle.physicsBody?.categoryBitMask = PhysicsCategory.obstacle
        obstacle.physicsBody?.collisionBitMask = PhysicsCategory.ball
        obstacle.physicsBody?.contactTestBitMask = PhysicsCategory.ball
        addWorldChild(obstacle)

        let glow = SKShapeNode(rectOf: CGSize(width: obstacleSize.width + 18, height: obstacleSize.height + 18), cornerRadius: 11)
        glow.fillColor = .white
        glow.strokeColor = .clear
        glow.alpha = 0.12
        glow.blendMode = .add
        glow.zPosition = -1
        obstacle.addChild(glow)

        obstacle.run(.repeatForever(.rotate(byAngle: .pi, duration: 1.1)), withKey: "spin")
        obstacle.run(.sequence([
            .wait(forDuration: 4.4),
            .fadeOut(withDuration: 0.6),
            .removeFromParent()
        ]), withKey: "life")
    }

    private func increaseBallImpulse() {
        guard let physicsBody = ball?.physicsBody else { return }

        let velocity = physicsBody.velocity
        let currentSpeed = hypot(velocity.dx, velocity.dy)
        guard currentSpeed > 0 else { return }

        let maxSpeed: CGFloat = 760
        let newSpeed = min(currentSpeed * 1.08, maxSpeed)
        physicsBody.velocity = CGVector(
            dx: velocity.dx / currentSpeed * newSpeed,
            dy: velocity.dy / currentSpeed * newSpeed
        )
    }

    private func showPaddleHitEffect(at position: CGPoint) {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.particleTexture = particleTexture
        emitter.particleBirthRate = 320
        emitter.numParticlesToEmit = 18
        emitter.particleLifetime = 0.35
        emitter.particleLifetimeRange = 0.12
        emitter.particleSpeed = 120
        emitter.particleSpeedRange = 50
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -2.4
        emitter.particleScale = 0.18
        emitter.particleScaleRange = 0.08
        emitter.particleScaleSpeed = -0.35
        emitter.particleColor = .white
        emitter.particleColorBlendFactor = 1
        addWorldChild(emitter)

        emitter.run(.sequence([
            .wait(forDuration: 0.45),
            .removeFromParent()
        ]))
    }

    private func showGoalConfetti() {
        let emitter = SKEmitterNode()
        emitter.position = CGPoint(x: safeFrame.midX, y: safeFrame.midY)
        emitter.particleTexture = confettiTexture
        emitter.particleBirthRate = 1_200
        emitter.numParticlesToEmit = 70
        emitter.particleLifetime = 0.85
        emitter.particleLifetimeRange = 0.25
        emitter.particleSpeed = 240
        emitter.particleSpeedRange = 90
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.95
        emitter.particleAlphaSpeed = -1.0
        emitter.particleScale = 0.22
        emitter.particleScaleRange = 0.12
        emitter.particleScaleSpeed = -0.16
        emitter.particleRotationRange = .pi
        emitter.particleRotationSpeed = 5
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [playerColor, UIColor.white, enemyColor, UIColor.systemYellow],
            times: [0, 0.35, 0.7, 1]
        )
        emitter.particleColorBlendFactor = 1
        emitter.zPosition = 20
        addWorldChild(emitter)

        emitter.run(.sequence([
            .wait(forDuration: 1.15),
            .removeFromParent()
        ]))
    }

    private func makeBallTrail() -> SKEmitterNode {
        let trail = SKEmitterNode()
        trail.targetNode = worldNode ?? self
        trail.particleTexture = trailTexture
        trail.particleBirthRate = 70
        trail.particleLifetime = 0.62
        trail.particleLifetimeRange = 0.22
        trail.particleSpeed = 20
        trail.particleSpeedRange = 10
        trail.emissionAngleRange = .pi / 7
        trail.particleAlpha = 0.24
        trail.particleAlphaSpeed = -0.42
        trail.particleScale = 0.36
        trail.particleScaleRange = 0.12
        trail.particleScaleSpeed = -0.34
        trail.particleColor = .white
        trail.particleColorBlendFactor = 1
        trail.zPosition = -2
        return trail
    }

    private func makeParticleTexture() -> SKTexture {
        let size = CGSize(width: 8, height: 8)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }

    private func makeTrailTexture() -> SKTexture {
        let size = CGSize(width: 6, height: 6)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }

    private func makeConfettiTexture() -> SKTexture {
        let size = CGSize(width: 8, height: 4)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }

    private func makeStarTexture() -> SKTexture {
        let size = CGSize(width: 4, height: 4)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }

    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .playing else { return }

        let categories = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        guard categories & PhysicsCategory.ball != 0 else { return }

        if categories & PhysicsCategory.paddle != 0 {
            SoundManager.shared.playHitSound()

            if contactIncludes(contact, node: paddle) {
                lastBallOwner = .player
                ball?.lastTouchedBy = "Player"
                setBallOwnerColor(.player)
                handlePaddleHit(at: contact.contactPoint, paddleNode: paddle, appliesPlayerSpin: true)
            } else {
                lastBallOwner = .enemy
                ball?.lastTouchedBy = "AI"
                setBallOwnerColor(.enemy)
                handlePaddleHit(at: contact.contactPoint, paddleNode: enemyPaddle, appliesPlayerSpin: false)
                addRandomVelocityJitter()
            }
        } else if categories & PhysicsCategory.fieldObject != 0 {
            if let fieldObject = fieldObject(in: contact) {
                handleFieldObjectHit(fieldObject, at: contact.contactPoint)
            }
        } else if categories & (PhysicsCategory.boundary | PhysicsCategory.obstacle) != 0 {
            SoundManager.shared.playHitSound()
            playScreenShake()
            addRandomVelocityJitter()
        }
    }

    private func fieldObject(in contact: SKPhysicsContact) -> FieldObject? {
        if let object = contact.bodyA.node as? FieldObject {
            return object
        }

        return contact.bodyB.node as? FieldObject
    }

    private func handleFieldObjectHit(_ object: FieldObject, at contactPoint: CGPoint) {
        guard fieldObjects.contains(where: { $0 === object }) else { return }

        SoundManager.shared.playHitSound()
        applyFieldObjectEffect(object.objectType)
        showFieldObjectShatter(at: contactPoint, color: object.objectType.color)

        object.physicsBody?.categoryBitMask = 0
        object.physicsBody?.collisionBitMask = 0
        object.physicsBody?.contactTestBitMask = 0
        object.removeAction(forKey: "fieldRotate")
        object.removeAction(forKey: "fieldPulse")
        fieldObjects.removeAll { $0 === object }
        object.run(.sequence([
            .group([
                .fadeOut(withDuration: 0.12),
                .scale(to: 1.35, duration: 0.12)
            ]),
            .removeFromParent()
        ]))
    }

    private func applyFieldObjectEffect(_ type: FieldObject.ObjectType) {
        let lastOwner = ball?.lastTouchedBy == "AI" ? BallOwner.enemy : BallOwner.player

        switch type {
        case .buff:
            applyBuff(to: lastOwner)
            pulseBackground(with: FieldObject.ObjectType.buff.color)
        case .hazard:
            applyHazard(toOpponentOf: lastOwner)
            screenShake(intensity: 8)
            pulseBackground(with: FieldObject.ObjectType.hazard.color)
        }
    }

    private func applyBuff(to owner: BallOwner) {
        switch owner {
        case .player:
            playerHasShield = true
            updatePaddleScale(for: .player)
            runBuffRecovery(for: .player)
        case .enemy:
            enemyHasShield = true
            updatePaddleScale(for: .enemy)
            runBuffRecovery(for: .enemy)
        }
    }

    private func applyHazard(toOpponentOf owner: BallOwner) {
        let target: BallOwner = owner == .player ? .enemy : .player

        switch target {
        case .player:
            playerIsDebuffed = true
            updatePaddleScale(for: .player)
            runDebuffRecovery(for: .player)
        case .enemy:
            enemyIsDebuffed = true
            updatePaddleScale(for: .enemy)
            runDebuffRecovery(for: .enemy)
        }
    }

    private func runBuffRecovery(for owner: BallOwner) {
        let actionKey = owner == .player ? "playerBuffRecovery" : "enemyBuffRecovery"
        removeAction(forKey: actionKey)
        run(.sequence([
            .wait(forDuration: 7),
            .run { [weak self] in
                self?.clearBuff(for: owner)
            }
        ]), withKey: actionKey)
    }

    private func runDebuffRecovery(for owner: BallOwner) {
        let actionKey = owner == .player ? "playerDebuffRecovery" : "enemyDebuffRecovery"
        removeAction(forKey: actionKey)
        run(.sequence([
            .wait(forDuration: 7),
            .run { [weak self] in
                self?.clearHazardDebuff(for: owner)
            }
        ]), withKey: actionKey)
    }

    private func clearHazardDebuff(for owner: BallOwner) {
        switch owner {
        case .player:
            playerIsDebuffed = false
        case .enemy:
            enemyIsDebuffed = false
        }

        updatePaddleScale(for: owner)
    }

    private func clearBuff(for owner: BallOwner) {
        switch owner {
        case .player:
            playerHasShield = false
        case .enemy:
            enemyHasShield = false
        }

        updatePaddleScale(for: owner)
    }

    private func updatePaddleScale(for owner: BallOwner) {
        let hasShield = owner == .player ? playerHasShield : enemyHasShield
        let isDebuffed = owner == .player ? playerIsDebuffed : enemyIsDebuffed
        let targetXScale: CGFloat = (hasShield ? 1.25 : 1.0) * (isDebuffed ? 0.5 : 1.0)
        let paddleNode = owner == .player ? paddle : enemyPaddle

        paddleNode?.removeAction(forKey: "effectScale")
        paddleNode?.run(.scaleX(to: targetXScale, y: 1.0, duration: 0.18), withKey: "effectScale")
    }

    private func showFieldObjectShatter(at position: CGPoint, color: UIColor) {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.particleTexture = particleTexture
        emitter.particleBirthRate = 760
        emitter.numParticlesToEmit = 36
        emitter.particleLifetime = 0.42
        emitter.particleLifetimeRange = 0.16
        emitter.particleSpeed = 170
        emitter.particleSpeedRange = 70
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.95
        emitter.particleAlphaSpeed = -2.0
        emitter.particleScale = 0.2
        emitter.particleScaleRange = 0.12
        emitter.particleScaleSpeed = -0.35
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.zPosition = 18
        addWorldChild(emitter)

        emitter.run(.sequence([
            .wait(forDuration: 0.55),
            .removeFromParent()
        ]))
    }

    private func contactIncludes(_ contact: SKPhysicsContact, node: SKNode?) -> Bool {
        guard let node else { return false }

        return contact.bodyA.node === node || contact.bodyB.node === node
    }

    private func setBallOwnerColor(_ owner: BallOwner) {
        let color = owner == .player ? playerColor : enemyColor
        ball?.fillColor = color
        ball?.strokeColor = color
        (ball?.childNode(withName: "ballGlow") as? SKShapeNode)?.fillColor = color
        ballTrail?.particleColor = color
    }

    private func handlePaddleHit(at contactPoint: CGPoint, paddleNode: SKNode?, appliesPlayerSpin: Bool) {
        showPaddleHitEffect(at: contactPoint)
        playBallSquash()
        playPlatformRecoil(paddleNode)
        playScreenShake()
        pulseBackground(with: appliesPlayerSpin ? playerColor : enemyColor)
        lightImpactFeedback.impactOccurred()
        lightImpactFeedback.prepare()

        guard appliesPlayerSpin else { return }

        run(.sequence([
            .wait(forDuration: 0.01),
            .run { [weak self] in
                self?.applyPaddleInfluence(contactPoint: contactPoint)
            }
        ]))
    }

    private func playPlatformRecoil(_ paddleNode: SKNode?) {
        guard let paddleNode else { return }

        let baseXScale = paddleNode.xScale
        let baseYScale = paddleNode.yScale
        paddleNode.removeAction(forKey: "recoil")
        paddleNode.run(.sequence([
            .scaleX(to: baseXScale * 1.12, y: baseYScale, duration: 0.045),
            .scaleX(to: baseXScale, y: baseYScale, duration: 0.09)
        ]), withKey: "recoil")
    }

    private func screenShake(intensity: CGFloat = 5) {
        guard let worldNode else { return }

        worldNode.removeAction(forKey: "screenShake")
        worldNode.position = .zero

        let shake = SKAction.sequence([
            .moveBy(x: intensity, y: -intensity * 0.6, duration: 0.025),
            .moveBy(x: -intensity * 1.8, y: intensity, duration: 0.035),
            .moveBy(x: intensity * 1.4, y: -intensity * 0.8, duration: 0.03),
            .moveBy(x: -intensity * 0.6, y: intensity * 0.4, duration: 0.025),
            .move(to: .zero, duration: 0.04)
        ])
        worldNode.run(shake, withKey: "screenShake")
    }

    private func playScreenShake() {
        screenShake()
    }

    private func applyPaddleInfluence(contactPoint: CGPoint) {
        guard gameState == .playing else { return }
        guard let ballBody = ball?.physicsBody, let paddle else { return }

        let hitOffset = (contactPoint.x - paddle.position.x) / (paddleSize.width / 2)
        let clampedOffset = min(max(hitOffset, -1), 1)
        let edgeBoost = clampedOffset * 210
        let clampedPaddleVelocity = min(max(paddleVelocityX, -maxPaddleSpinVelocity), maxPaddleSpinVelocity)
        let spinBoost = clampedPaddleVelocity * paddleSpinTransfer

        var velocity = ballBody.velocity
        velocity.dx += edgeBoost + spinBoost

        let spinRatio = min(abs(clampedPaddleVelocity) / maxPaddleSpinVelocity, 1)
        let minimumVerticalSpeed = 150 + (1 - spinRatio) * 100
        velocity.dy = max(abs(velocity.dy) * (1 - spinRatio * 0.35), minimumVerticalSpeed)

        ballBody.velocity = limitedVelocity(velocity)
        addRandomVelocityJitter()
    }

    private func addRandomVelocityJitter() {
        guard let physicsBody = ball?.physicsBody else { return }

        let angle = CGFloat.random(in: 1...2) * (Bool.random() ? 1 : -1) * .pi / 180
        let velocity = physicsBody.velocity
        let rotatedVelocity = CGVector(
            dx: velocity.dx * cos(angle) - velocity.dy * sin(angle),
            dy: velocity.dx * sin(angle) + velocity.dy * cos(angle)
        )
        physicsBody.velocity = limitedVelocity(rotatedVelocity)
    }

    private func playBallSquash() {
        guard let ball else { return }

        ball.removeAction(forKey: "stretch")
        ball.run(.sequence([
            .scaleX(to: 1.22, y: 0.72, duration: 0.05),
            .scaleX(to: 0.92, y: 1.14, duration: 0.07),
            .scale(to: 1.0, duration: 0.08)
        ]), withKey: "squash")
    }

    private func updateBallStretch() {
        guard let ball, let physicsBody = ball.physicsBody else { return }
        guard ball.action(forKey: "squash") == nil else { return }

        let velocity = physicsBody.velocity
        let speed = hypot(velocity.dx, velocity.dy)
        let stretchAmount = min(max((speed - 280) / 620, 0), 1)
        let xScale = 1.0 - stretchAmount * 0.12
        let yScale = 1.0 + stretchAmount * 0.18
        let angle = atan2(velocity.dy, velocity.dx) - .pi / 2

        ball.run(.group([
            .scaleX(to: xScale, y: yScale, duration: 0.08),
            .rotate(toAngle: angle, duration: 0.08, shortestUnitArc: true)
        ]), withKey: "stretch")
    }

    private func updateBallTrail() {
        guard let trail = ballTrail, let velocity = ball?.physicsBody?.velocity else { return }

        let speed = hypot(velocity.dx, velocity.dy)
        trail.particleBirthRate = 45 + speed * 0.05
        trail.emissionAngle = atan2(-velocity.dy, -velocity.dx)
    }

    private func limitedVelocity(_ velocity: CGVector) -> CGVector {
        let speed = hypot(velocity.dx, velocity.dy)
        guard speed > 0 else { return velocity }

        let minSpeed: CGFloat = 280
        let maxSpeed: CGFloat = 840
        let targetSpeed = min(max(speed, minSpeed), maxSpeed)
        return CGVector(
            dx: velocity.dx / speed * targetSpeed,
            dy: velocity.dy / speed * targetSpeed
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        let touchedNode = atPoint(touch.location(in: self))

        if gameState == .start {
            if let button = buttonNode(from: touchedNode, named: NodeName.playButton) {
                animateButtonPress(button) { [weak self] in
                    self?.fadeOutActiveOverlay {
                        self?.startGame()
                    }
                }
            } else if let button = buttonNode(from: touchedNode, named: NodeName.settingsButton) {
                animateButtonPress(button) { [weak self] in
                    self?.fadeOutActiveOverlay {
                        self?.showSettingsScreen()
                    }
                }
            }
        } else if gameState == .settings {
            if let button = buttonNode(from: touchedNode, named: NodeName.backButton) {
                animateButtonPress(button) { [weak self] in
                    self?.fadeOutActiveOverlay {
                        self?.showStartScreen()
                    }
                }
            } else if let button = buttonNode(from: touchedNode, named: NodeName.difficultyLeft) {
                animateButtonPress(button) { [weak self] in
                    self?.changeDifficulty(by: -1)
                }
            } else if let button = buttonNode(from: touchedNode, named: NodeName.difficultyRight) {
                animateButtonPress(button) { [weak self] in
                    self?.changeDifficulty(by: 1)
                }
            } else if let button = buttonNode(from: touchedNode, named: NodeName.gameModeLeft) {
                animateButtonPress(button) { [weak self] in
                    self?.changeGameMode(by: -1)
                }
            } else if let button = buttonNode(from: touchedNode, named: NodeName.gameModeRight) {
                animateButtonPress(button) { [weak self] in
                    self?.changeGameMode(by: 1)
                }
            } else if let button = buttonNode(from: touchedNode, named: NodeName.privacyButton) {
                animateButtonPress(button) { [weak self] in
                    self?.openPolicyPage(title: "Privacy Policy", url: AppConstants.Legal.privacyPolicyURL)
                }
            } else if let button = buttonNode(from: touchedNode, named: NodeName.termsButton) {
                animateButtonPress(button) { [weak self] in
                    self?.openPolicyPage(title: "Terms of Use", url: AppConstants.Legal.termsOfUseURL)
                }
            }
        } else if gameState == .playing {
            if !isCountingDown, let button = buttonNode(from: touchedNode, named: NodeName.pauseButton) {
                animateButtonPress(button) { [weak self] in
                    self?.showPauseMenu()
                }
            }
        } else if gameState == .paused {
            if let button = buttonNode(from: touchedNode, named: NodeName.resumeButton) {
                animateButtonPress(button) { [weak self] in
                    self?.fadeOutActiveOverlay {
                        self?.resumeGame()
                    }
                }
            } else if let button = buttonNode(from: touchedNode, named: NodeName.exitButton) {
                animateButtonPress(button) { [weak self] in
                    self?.fadeOutActiveOverlay {
                        self?.isPaused = false
                        self?.showStartScreen()
                    }
                }
            }
        } else if gameState == .gameOver {
            if let button = buttonNode(from: touchedNode, named: NodeName.menuButton) {
                animateButtonPress(button) { [weak self] in
                    self?.fadeOutActiveOverlay {
                        self?.showStartScreen()
                    }
                }
            } else if let button = buttonNode(from: touchedNode, named: NodeName.playAgainButton) {
                animateButtonPress(button) { [weak self] in
                    self?.fadeOutActiveOverlay {
                        self?.startGame()
                    }
                }
            }
        }
    }

    private func changeDifficulty(by offset: Int) {
        let difficulties = AIDifficulty.allCases
        guard let currentIndex = difficulties.firstIndex(of: selectedDifficulty) else { return }

        let newIndex = (currentIndex + offset + difficulties.count) % difficulties.count
        selectedDifficulty = difficulties[newIndex]
        difficultyValueLabel?.text = selectedDifficulty.title
        saveSettings()
    }

    private func changeGameMode(by offset: Int) {
        let modes = GameMode.allCases
        guard let currentIndex = modes.firstIndex(of: selectedGameMode) else { return }

        let newIndex = (currentIndex + offset + modes.count) % modes.count
        selectedGameMode = modes[newIndex]
        gameModeValueLabel?.text = selectedGameMode.title
        saveSettings()
    }

    private func openPolicyPage(title: String, url: URL) {
        guard let viewController = view?.window?.rootViewController else { return }

        let policyViewController = PolicyWebViewController(title: title, url: url)
        let navigationController = UINavigationController(rootViewController: policyViewController)
        navigationController.modalPresentationStyle = .fullScreen
        viewController.present(navigationController, animated: true)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing else { return }
        guard let touch = touches.first else { return }
        updatePaddleTarget(toX: touch.location(in: self).x, timestamp: touch.timestamp)
    }

    private func updatePaddleTarget(toX xPosition: CGFloat, timestamp: TimeInterval) {
        let halfWidth = paddleSize.width / 2
        targetPaddleX = min(max(xPosition, safeFrame.minX + halfWidth), safeFrame.maxX - halfWidth)
        lastPaddleMoveTime = timestamp
    }

    private func updatePlayerPaddle(deltaTime: TimeInterval) {
        guard let paddle, let targetPaddleX else { return }

        let previousX = paddle.position.x
        let newX = previousX + (targetPaddleX - previousX) * paddleLerpFactor
        paddle.position.x = newX

        let safeDeltaTime = max(deltaTime, 0.001)
        paddleVelocityX = (newX - previousX) / CGFloat(safeDeltaTime)
        lastPaddleX = newX
    }

    private func updatePaddleVelocityDecay(currentTime: TimeInterval) {
        guard lastPaddleMoveTime > 0 else { return }

        if currentTime - lastPaddleMoveTime > 0.12 {
            paddleVelocityX *= 0.85
        }

        if abs(paddleVelocityX) < 8 {
            paddleVelocityX = 0
        }
    }

    private func updateEnemyPaddle(deltaTime: TimeInterval) {
        guard let enemyPaddle, let ball else { return }

        let halfWidth = enemyPaddleSize.width / 2
        let targetX = min(max(ball.position.x, safeFrame.minX + halfWidth), safeFrame.maxX - halfWidth)
        let distance = targetX - enemyPaddle.position.x
        let maxStep = selectedDifficulty.enemySpeed * CGFloat(deltaTime)
        enemyPaddle.position.x += min(max(distance, -maxStep), maxStep)
    }

    private var playerGoalLine: CGFloat {
        let paddleY = paddle?.position.y ?? safeFrame.minY + paddleBottomOffset
        return paddleY - paddleSize.height / 2 - ballRadius * 0.35
    }

    private var enemyGoalLine: CGFloat {
        let enemyPaddleY = enemyPaddle?.position.y ?? safeFrame.maxY - enemyPaddleTopOffset
        return enemyPaddleY + enemyPaddleSize.height / 2 + ballRadius * 0.35
    }

    private func handleGoalIfNeeded() {
        guard let ball else { return }

        if ball.position.y > enemyGoalLine {
            playerScore += 1
            SoundManager.shared.playScoreSound()
            screenShake(intensity: 10)
            showGoalConfetti()
            heavyImpactFeedback.impactOccurred()
            heavyImpactFeedback.prepare()
            updateScoreLabel()
            checkMatchOver()

            if gameState == .playing {
                resetBallAfterGoal(directionY: -1)
            }
        } else if ball.position.y < playerGoalLine {
            enemyScore += 1
            SoundManager.shared.playScoreSound()
            screenShake(intensity: 10)
            showGoalConfetti()
            heavyImpactFeedback.impactOccurred()
            heavyImpactFeedback.prepare()
            updateScoreLabel()
            checkMatchOver()

            if gameState == .playing {
                resetBallAfterGoal(directionY: 1)
            }
        }
    }

    private func resetBallAfterGoal(directionY: CGFloat) {
        guard let ball, let physicsBody = ball.physicsBody else { return }

        ball.removeAllActions()
        ball.setScale(1)
        ball.zRotation = 0
        ball.position = CGPoint(x: safeFrame.midX, y: safeFrame.midY)
        lastBallOwner = nil
        setBallOwnerColor(directionY > 0 ? .player : .enemy)
        ball.lastTouchedBy = directionY > 0 ? "Player" : "AI"
        schedulePowerUpsIfNeeded()

        let speed: CGFloat = 340
        let angle = CGFloat.random(in: 35...145) * .pi / 180
        let nextVelocity = CGVector(dx: cos(angle) * speed, dy: abs(sin(angle) * speed) * directionY)
        physicsBody.velocity = .zero
        physicsBody.angularVelocity = 0

        launchBall(with: nextVelocity)
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
        updateEnemyPaddle(deltaTime: deltaTime)
        updateBallStretch()
        updateBallTrail()
        handleGoalIfNeeded()

        currentScore = Int(currentTime - startTime)
    }
}
