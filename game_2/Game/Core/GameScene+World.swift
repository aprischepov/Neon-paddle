import SpriteKit
import UIKit
import CoreImage
import AVFoundation

extension GameScene {
    func createBall() {
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

    func addBoundary(from startPoint: CGPoint, to endPoint: CGPoint) {
        let boundary = SKNode()
        boundary.physicsBody = SKPhysicsBody(edgeFrom: startPoint, to: endPoint)
        boundary.physicsBody?.categoryBitMask = PhysicsCategory.boundary
        boundary.physicsBody?.collisionBitMask = PhysicsCategory.ball
        boundary.physicsBody?.contactTestBitMask = PhysicsCategory.ball
        addWorldChild(boundary)
    }

    func createPaddle() {
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

    func addWorldChild(_ node: SKNode) {
        if let worldNode {
            worldNode.addChild(node)
        } else {
            addChild(node)
        }
    }

    func createWorldNode() {
        let worldNode = SKNode()
        worldNode.name = "worldNode"
        worldNode.zPosition = 0
        addChild(worldNode)
        self.worldNode = worldNode
    }

    func contactIncludes(_ contact: SKPhysicsContact, node: SKNode?) -> Bool {
        guard let node else { return false }
        return contact.bodyA.node === node || contact.bodyB.node === node
    }

    func createScoreLabel() {
        let safeFrame = self.safeFrame
        let scoreboardLabel = makeScoreboardLabel(text: "", size: scoreboardFontSize)
        scoreboardLabel.alpha = 0.22
        scoreboardLabel.zPosition = -30
        scoreboardLabel.position = CGPoint(x: safeFrame.midX, y: safeFrame.midY)
        addWorldChild(scoreboardLabel)
        self.scoreboardLabel = scoreboardLabel
        updateScoreLabel()
    }

    func setBallOwnerColor(_ owner: BallOwner) {
        let color = owner == .player ? playerColor : enemyColor
        ball?.fillColor = color
        ball?.strokeColor = color
        (ball?.childNode(withName: "ballGlow") as? SKShapeNode)?.fillColor = color
        ballTrail?.particleColor = color
    }

    func updatePaddleScale(for owner: BallOwner) {
        let hasShield = owner == .player ? playerHasShield : enemyHasShield
        let isDebuffed = owner == .player ? playerIsDebuffed : enemyIsDebuffed
        let targetXScale: CGFloat = (hasShield ? 1.25 : 1.0) * (isDebuffed ? 0.5 : 1.0)
        let paddleNode = owner == .player ? paddle : enemyPaddle
        paddleNode?.removeAction(forKey: "effectScale")
        paddleNode?.run(.scaleX(to: targetXScale, y: 1.0, duration: 0.18), withKey: "effectScale")
    }

    func createPauseButton() {
        let safeFrame = self.safeFrame
        let pauseButton = SKLabelNode(text: "⏸")
        pauseButton.name = GameNodeName.pauseButton
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

    func createEnemyPaddle() {
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
        targetEnemyPaddleX = enemyPaddle.position.x
    }

    func createScreenBoundaries() {
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
}
