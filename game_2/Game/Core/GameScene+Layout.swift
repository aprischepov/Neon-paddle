import SpriteKit
import UIKit
import CoreImage
import AVFoundation

extension GameScene {
    func point(from normalizedPoint: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width * normalizedPoint.x,
            y: rect.minY + rect.height * normalizedPoint.y
        )
    }

    var safeFrame: CGRect {
        guard let view else { return frame }
        let insets = view.safeAreaInsets
        return CGRect(
            x: frame.minX + insets.left,
            y: frame.minY + insets.bottom,
            width: frame.width - insets.left - insets.right,
            height: frame.height - insets.top - insets.bottom
        )
    }

    var ballRadius: CGFloat {
        isLandscapeLayout ? 13 : 16
    }

    var paddleSize: CGSize {
        let width = isLandscapeLayout
            ? min(max(safeFrame.width * 0.24, 150), 230)
            : min(max(safeFrame.width * 0.36, 128), 160)
        return CGSize(width: width, height: isLandscapeLayout ? 16 : 18)
    }

    var enemyGoalLine: CGFloat {
        let enemyPaddleY = enemyPaddle?.position.y ?? safeFrame.maxY - enemyPaddleTopOffset
        return enemyPaddleY + enemyPaddleSize.height / 2 + ballRadius * 0.35
    }

    var titleFontSize: CGFloat {
        isLandscapeLayout ? min(max(safeFrame.height * 0.12, 34), 44) : 44
    }

    var playerGoalLine: CGFloat {
        let paddleY = paddle?.position.y ?? safeFrame.minY + paddleBottomOffset
        return paddleY - paddleSize.height / 2 - ballRadius * 0.35
    }

    func isZeroVelocity(_ velocity: CGVector) -> Bool {
        abs(velocity.dx) < 0.001 && abs(velocity.dy) < 0.001
    }

    var enemyPaddleSize: CGSize {
        let playerSize = paddleSize
        return CGSize(width: playerSize.width * 0.86, height: max(playerSize.height - 2, 14))
    }

    func normalizedPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        guard rect.width > 0, rect.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        return CGPoint(
            x: min(max((point.x - rect.minX) / rect.width, 0), 1),
            y: min(max((point.y - rect.minY) / rect.height, 0), 1)
        )
    }

    var isLandscapeLayout: Bool {
        safeFrame.width > safeFrame.height
    }

    var scoreboardFontSize: CGFloat {
        isLandscapeLayout ? min(max(safeFrame.height * 0.22, 70), 92) : 124
    }

    var paddleBottomOffset: CGFloat {
        isLandscapeLayout ? min(max(safeFrame.height * 0.13, 38), 56) : 72
    }

    func clampedBallPosition(_ position: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(position.x, safeFrame.minX + ballRadius), safeFrame.maxX - ballRadius),
            y: min(max(position.y, safeFrame.minY + ballRadius), safeFrame.maxY - ballRadius)
        )
    }

    var enemyPaddleTopOffset: CGFloat {
        paddleBottomOffset
    }

    func relayoutSceneForCurrentSize() {
        let previousSafeFrame = lastLayoutSafeFrame == .zero ? safeFrame : lastLayoutSafeFrame
        switch gameState {
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

    func rebuildPlayingSceneForCurrentLayout(
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
        setBallOwnerColor(Self.ballOwner(from: savedBallTouchedBy))
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
}
