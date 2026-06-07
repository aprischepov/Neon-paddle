import SpriteKit
import UIKit
import CoreImage
import AVFoundation

extension GameScene {
    func startGame() {
        removeAllChildren()
        clearGameReferences()
        applyCampaignMatchSettings()
        campaignLastStars = 0
        campaignOffersNextLevel = false
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
        targetEnemyPaddleX = nil
        paddleVelocityX = 0
        enemyPaddleVelocityX = 0
        lastEnemyPaddleMoveTime = 0
        lastBallOwner = nil
        gameState = .playing
        var started: [String: Any] = [
            "difficulty": matchDifficulty.title,
            "game_mode": matchGameMode.title,
        ]
        if let level = campaignLevel {
            started["campaign_level"] = level.id
            started["campaign_world"] = level.worldTitle
        }
        AppLogger.track(AppLogger.Event.gameStarted, properties: started.merging(analyticsOrientation()) { _, new in new })
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

    func resumeGame() {
        isPaused = false
        gameState = .playing
        AppLogger.track(AppLogger.Event.gameResumed, properties: analyticsOrientation())
        let velocity = pausedBallVelocity ?? makeRandomStartVelocity()
        launchBall(with: velocity)
        pausedBallVelocity = nil
    }

    func launchBall(with velocity: CGVector) {
        physicsWorld.speed = 1
        ball?.physicsBody?.velocity = velocity
        ballTrail?.particleBirthRate = 70
        lastUpdateTime = 0
    }

    func showPauseMenu() {
        guard gameState == .playing else { return }
        isPaused = false
        gameState = .paused
        AppLogger.track(AppLogger.Event.gamePaused, properties: [
            "player_score": playerScore,
            "enemy_score": enemyScore
        ].merging(analyticsOrientation()) { _, new in new })
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
        let resumeButton = makeButton(title: "RESUME", name: GameNodeName.resumeButton)
        resumeButton.position = CGPoint(x: 0, y: -18)
        card.addChild(resumeButton)
        let exitButton = makeButton(title: "EXIT", name: GameNodeName.exitButton)
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

    func showMatchOver(winner: BallOwner) {
        guard gameState == .playing else { return }
        gameState = .gameOver
        AppLogger.track(AppLogger.Event.gameOver, properties: [
            "winner": winner == .player ? "player" : "enemy",
            "player_score": playerScore,
            "enemy_score": enemyScore,
            "difficulty": GamePreferencesStore.difficulty.title,
            "game_mode": GamePreferencesStore.gameMode.title
        ].merging(analyticsOrientation()) { _, new in new })
        AppLogger.screen("game_over", properties: analyticsOrientation())
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
        let playerWon = winner == .player
        let title: String
        if campaignLevel != nil {
            title = playerWon ? "LEVEL CLEAR" : "TRY AGAIN"
        } else if matchGameMode == .localTwoPlayer {
            title = playerWon ? "PLAYER 1 WINS" : "PLAYER 2 WINS"
        } else {
            title = playerWon ? "YOU WIN" : "YOU LOSE"
        }
        let resultLabel = makeScoreboardLabel(text: title, size: isLandscapeLayout ? 34 : 40)
        resultLabel.fontColor = playerWon ? playerColor : enemyColor
        resultLabel.position = CGPoint(x: 0, y: isLandscapeLayout ? 72 : 96)
        resultLabel.zPosition = 1
        overlay.addChild(resultLabel)
        if campaignLevel != nil, playerWon {
            campaignLastStars = campaignStarsForCurrentResult(playerWon: true)
            campaignOffersNextLevel = CampaignCatalog.nextLevel(after: campaignLevel!.id) != nil
            notifyCampaignResult(playerWon: true)
            let starsLabel = makeLabel(
                text: CampaignStarsCalculator.starsText(campaignLastStars),
                size: isLandscapeLayout ? 22 : 26,
                weight: .semibold
            )
            starsLabel.position = CGPoint(x: 0, y: isLandscapeLayout ? 38 : 52)
            starsLabel.zPosition = 1
            overlay.addChild(starsLabel)
        } else if campaignLevel != nil, !playerWon {
            notifyCampaignResult(playerWon: false)
        }
        let finalScoreLabel = makeScoreboardLabel(text: "\(playerScore):\(enemyScore)", size: isLandscapeLayout ? 30 : 34)
        finalScoreLabel.alpha = 0.9
        finalScoreLabel.position = CGPoint(x: 0, y: isLandscapeLayout ? 8 : 18)
        finalScoreLabel.zPosition = 1
        overlay.addChild(finalScoreLabel)
        let primaryButtonTitle: String
        if campaignLevel != nil {
            if playerWon, campaignOffersNextLevel {
                primaryButtonTitle = "NEXT"
            } else {
                primaryButtonTitle = "RETRY"
            }
        } else {
            primaryButtonTitle = "PLAY AGAIN"
        }
        let playAgainButton = makeButton(
            title: primaryButtonTitle,
            name: GameNodeName.playAgainButton,
            buttonSize: CGSize(width: 204, height: 52),
            titleSize: 20
        )
        if isLandscapeLayout {
            playAgainButton.setScale(0.82)
            playAgainButton.position = CGPoint(x: -92, y: -58)
        } else {
            playAgainButton.position = CGPoint(x: 0, y: -58)
        }
        playAgainButton.zPosition = 1
        overlay.addChild(playAgainButton)
        let secondaryTitle = campaignLevel != nil ? "CAMPAIGN" : "Menu"
        let menuButton = makeButton(title: secondaryTitle, name: GameNodeName.menuButton)
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

    func startCountdown(completion: @escaping () -> Void) {
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
        if let level = campaignLevel {
            let levelCaption = makeLabel(text: "LEVEL \(level.displayNumber)", size: 13, weight: .semibold)
            levelCaption.alpha = 0.72
            levelCaption.position = CGPoint(x: 0, y: 52)
            card.addChild(levelCaption)
            let levelTitle = makeLabel(text: level.title.uppercased(), size: 11, weight: .medium)
            levelTitle.alpha = 0.55
            levelTitle.position = CGPoint(x: 0, y: 36)
            card.addChild(levelTitle)
        }
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

    func checkMatchOver() {
        if playerScore >= selectedScoreLimit {
            recordLeaderboardIfNeeded(playerWon: true)
            showMatchOver(winner: .player)
        } else if enemyScore >= selectedScoreLimit {
            recordLeaderboardIfNeeded(playerWon: false)
            showMatchOver(winner: .enemy)
        }
    }

    func recordLeaderboardIfNeeded(playerWon: Bool) {
        guard shouldRecordLeaderboard else { return }
        LocalLeaderboardStore.recordMatchEnd(
            playerWon: playerWon,
            difficultyRaw: matchDifficulty.rawValue,
            gameModeRaw: matchGameMode.rawValue
        )
    }

    func createObstacle() {
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

    func updateScoreLabel() {
        scoreboardLabel?.text = "\(playerScore):\(enemyScore)"
        scoreboardLabel?.fontColor = playerScore >= enemyScore ? playerColor : enemyColor
    }

    func handleGoalIfNeeded() {
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

    func resetBallAfterGoal(directionY: CGFloat) {
        guard let ball, let physicsBody = ball.physicsBody else { return }
        ball.removeAllActions()
        ball.setScale(1)
        ball.zRotation = 0
        ball.position = CGPoint(x: safeFrame.midX, y: safeFrame.midY)
        lastBallOwner = nil
        setBallOwnerColor(directionY > 0 ? .player : .enemy)
        if directionY > 0 {
            ball.lastTouchedBy = "Player"
        } else {
            ball.lastTouchedBy = matchGameMode == .localTwoPlayer ? "Player2" : "AI"
        }
        schedulePowerUpsIfNeeded()
        let speed: CGFloat = 340
        let angle = CGFloat.random(in: 35...145) * .pi / 180
        let nextVelocity = CGVector(dx: cos(angle) * speed, dy: abs(sin(angle) * speed) * directionY)
        physicsBody.velocity = .zero
        physicsBody.angularVelocity = 0
        launchBall(with: nextVelocity)
    }

    func increaseBallImpulse() {
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

    func createBlurredBackdrop(zPosition: CGFloat) -> SKEffectNode {
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

    func spawnObstacleIfNeeded(score: Int) {
        guard matchGameMode == .powerUps else { return }
        let obstacleStep = score / obstacleInterval
        guard obstacleStep > lastObstacleStep else { return }
        lastObstacleStep = obstacleStep
        createObstacle()
    }

    func prepareReusableAssets() {
        _ = particleTexture
        _ = trailTexture
        _ = confettiTexture
        _ = starTexture
        SoundManager.shared.preloadSounds()
    }

    func applyDifficultyIfNeeded(score: Int) {
        let difficultyStep = score / difficultyInterval
        guard difficultyStep > lastDifficultyStep else { return }
        lastDifficultyStep = difficultyStep
        increaseBallImpulse()
    }

    func makeRandomStartVelocity() -> CGVector {
        let speed: CGFloat = 330
        let angle = CGFloat.random(in: 35...145) * .pi / 180
        return CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
    }
}
