import SpriteKit
import UIKit

extension GameScene {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing else {
            handleOverlayTouchesBegan(touches)
            return
        }
        for touch in touches {
            let location = touch.location(in: self)
            let touchedNode = atPoint(location)
            if !isCountingDown, let button = buttonNode(from: touchedNode, named: GameNodeName.pauseButton) {
                animateButtonPress(button) { [weak self] in
                    self?.showPauseMenu()
                }
                return
            }
            routePaddleTouch(at: location, timestamp: touch.timestamp)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing else { return }
        for touch in touches {
            routePaddleTouch(at: touch.location(in: self), timestamp: touch.timestamp)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}

    private func handleOverlayTouchesBegan(_ touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNode = atPoint(location)
        if gameState == .paused {
            if let button = buttonNode(from: touchedNode, named: GameNodeName.resumeButton) {
                animateButtonPress(button) { [weak self] in
                    self?.fadeOutActiveOverlay { self?.resumeGame() }
                }
            } else if let button = buttonNode(from: touchedNode, named: GameNodeName.exitButton) {
                animateButtonPress(button) { [weak self] in
                    self?.fadeOutActiveOverlay {
                        self?.isPaused = false
                        self?.requestMainMenu()
                    }
                }
            }
        } else if gameState == .gameOver {
            if let button = buttonNode(from: touchedNode, named: GameNodeName.menuButton) {
                animateButtonPress(button) { [weak self] in
                    self?.fadeOutActiveOverlay { self?.requestMainMenu() }
                }
            } else if let button = buttonNode(from: touchedNode, named: GameNodeName.playAgainButton) {
                animateButtonPress(button) { [weak self] in
                    self?.fadeOutActiveOverlay {
                        guard let self else { return }
                        if self.campaignLevel != nil, self.campaignOffersNextLevel,
                           let currentID = self.campaignLevel?.id,
                           let next = CampaignCatalog.nextLevel(after: currentID) {
                            self.campaignLevel = next
                            self.gameDelegate?.gameSceneDidRequestNextCampaignLevel(self, level: next)
                            self.startGame()
                        } else {
                            self.startGame()
                        }
                    }
                }
            }
        }
    }

    func routePaddleTouch(at location: CGPoint, timestamp: TimeInterval) {
        if matchGameMode == .localTwoPlayer {
            if location.y <= safeFrame.midY {
                updatePaddleTarget(toX: location.x, timestamp: timestamp)
            } else {
                updateEnemyPaddleTarget(toX: location.x, timestamp: timestamp)
            }
        } else {
            updatePaddleTarget(toX: location.x, timestamp: timestamp)
        }
    }

    func updateEnemyPaddle(deltaTime: TimeInterval) {
        if matchGameMode == .localTwoPlayer {
            updateLocalMultiplayerEnemyPaddle(deltaTime: deltaTime)
            return
        }
        guard let enemyPaddle, let ball else { return }
        let halfWidth = enemyPaddleSize.width / 2
        let targetX = min(max(ball.position.x, safeFrame.minX + halfWidth), safeFrame.maxX - halfWidth)
        let distance = targetX - enemyPaddle.position.x
        let maxStep = matchDifficulty.enemySpeed * CGFloat(deltaTime)
        enemyPaddle.position.x += min(max(distance, -maxStep), maxStep)
    }

    func updateLocalMultiplayerEnemyPaddle(deltaTime: TimeInterval) {
        guard let enemyPaddle, let targetEnemyPaddleX else { return }
        let previousX = enemyPaddle.position.x
        let newX = previousX + (targetEnemyPaddleX - previousX) * paddleLerpFactor
        enemyPaddle.position.x = newX
        let safeDeltaTime = max(deltaTime, 0.001)
        enemyPaddleVelocityX = (newX - previousX) / CGFloat(safeDeltaTime)
    }

    func updatePaddleTarget(toX xPosition: CGFloat, timestamp: TimeInterval) {
        let halfWidth = paddleSize.width / 2
        targetPaddleX = min(max(xPosition, safeFrame.minX + halfWidth), safeFrame.maxX - halfWidth)
        lastPaddleMoveTime = timestamp
    }

    func updateEnemyPaddleTarget(toX xPosition: CGFloat, timestamp: TimeInterval) {
        let halfWidth = enemyPaddleSize.width / 2
        targetEnemyPaddleX = min(max(xPosition, safeFrame.minX + halfWidth), safeFrame.maxX - halfWidth)
        lastEnemyPaddleMoveTime = timestamp
    }

    func updatePlayerPaddle(deltaTime: TimeInterval) {
        guard let paddle, let targetPaddleX else { return }
        let previousX = paddle.position.x
        let newX = previousX + (targetPaddleX - previousX) * paddleLerpFactor
        paddle.position.x = newX
        let safeDeltaTime = max(deltaTime, 0.001)
        paddleVelocityX = (newX - previousX) / CGFloat(safeDeltaTime)
        lastPaddleX = newX
    }

    func updatePaddleVelocityDecay(currentTime: TimeInterval) {
        guard lastPaddleMoveTime > 0 else { return }
        if currentTime - lastPaddleMoveTime > 0.12 {
            paddleVelocityX *= 0.85
        }
        if abs(paddleVelocityX) < 8 {
            paddleVelocityX = 0
        }
    }

    func updateEnemyPaddleVelocityDecay(currentTime: TimeInterval) {
        guard lastEnemyPaddleMoveTime > 0 else { return }
        if currentTime - lastEnemyPaddleMoveTime > 0.12 {
            enemyPaddleVelocityX *= 0.85
        }
        if abs(enemyPaddleVelocityX) < 8 {
            enemyPaddleVelocityX = 0
        }
    }
}
