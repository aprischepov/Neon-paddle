import SpriteKit
import UIKit
import CoreImage
import AVFoundation

extension GameScene {
    func screenShake(intensity: CGFloat = 5) {
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

    func makeBallTrail() -> SKEmitterNode {
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

    func playBallSquash() {
        guard let ball else { return }
        ball.removeAction(forKey: "stretch")
        ball.run(.sequence([
            .scaleX(to: 1.22, y: 0.72, duration: 0.05),
            .scaleX(to: 0.92, y: 1.14, duration: 0.07),
            .scale(to: 1.0, duration: 0.08)
        ]), withKey: "squash")
    }

    func playScreenShake() {
        screenShake()
    }

    func handlePaddleHit(
        at contactPoint: CGPoint,
        paddleNode: SKNode?,
        appliesPlayerSpin: Bool,
        spinUsesEnemyPaddle: Bool = false
    ) {
        showPaddleHitEffect(at: contactPoint)
        playBallSquash()
        playPlatformRecoil(paddleNode)
        playScreenShake()
        let hitColor = spinUsesEnemyPaddle ? enemyColor : (appliesPlayerSpin ? playerColor : enemyColor)
        pulseBackground(with: hitColor)
        lightImpactFeedback.impactOccurred()
        lightImpactFeedback.prepare()
        guard appliesPlayerSpin else { return }
        run(.sequence([
            .wait(forDuration: 0.01),
            .run { [weak self] in
                if spinUsesEnemyPaddle {
                    self?.applyEnemyPaddleInfluence(contactPoint: contactPoint)
                } else {
                    self?.applyPaddleInfluence(contactPoint: contactPoint)
                }
            }
        ]))
    }

    func applyEnemyPaddleInfluence(contactPoint: CGPoint) {
        guard gameState == .playing else { return }
        guard let ballBody = ball?.physicsBody, let enemyPaddle else { return }
        let hitOffset = (contactPoint.x - enemyPaddle.position.x) / (enemyPaddleSize.width / 2)
        let clampedOffset = min(max(hitOffset, -1), 1)
        let edgeBoost = clampedOffset * 210
        let clampedPaddleVelocity = min(max(enemyPaddleVelocityX, -maxPaddleSpinVelocity), maxPaddleSpinVelocity)
        let spinBoost = clampedPaddleVelocity * paddleSpinTransfer
        var velocity = ballBody.velocity
        velocity.dx += edgeBoost + spinBoost
        let spinRatio = min(abs(clampedPaddleVelocity) / maxPaddleSpinVelocity, 1)
        let minimumVerticalSpeed = 150 + (1 - spinRatio) * 100
        velocity.dy = -max(abs(velocity.dy) * (1 - spinRatio * 0.35), minimumVerticalSpeed)
        ballBody.velocity = limitedVelocity(velocity)
        addRandomVelocityJitter()
    }

    func makeStarTexture() -> SKTexture {
        let size = CGSize(width: 4, height: 4)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }

    func limitedVelocity(_ velocity: CGVector) -> CGVector {
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

    func updateBallTrail() {
        guard let trail = ballTrail, let velocity = ball?.physicsBody?.velocity else { return }
        let speed = hypot(velocity.dx, velocity.dy)
        trail.particleBirthRate = 45 + speed * 0.05
        trail.emissionAngle = atan2(-velocity.dy, -velocity.dx)
    }

    func makeTrailTexture() -> SKTexture {
        let size = CGSize(width: 6, height: 6)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }

    func showGoalConfetti() {
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

    func updateBallStretch() {
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

    func makeParticleTexture() -> SKTexture {
        let size = CGSize(width: 8, height: 8)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }

    func showPaddleHitEffect(at position: CGPoint) {
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

    func makeConfettiTexture() -> SKTexture {
        let size = CGSize(width: 8, height: 4)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }

    func applyPaddleInfluence(contactPoint: CGPoint) {
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

    func addRandomVelocityJitter() {
        guard let physicsBody = ball?.physicsBody else { return }
        let angle = CGFloat.random(in: 1...2) * (Bool.random() ? 1 : -1) * .pi / 180
        let velocity = physicsBody.velocity
        let rotatedVelocity = CGVector(
            dx: velocity.dx * cos(angle) - velocity.dy * sin(angle),
            dy: velocity.dx * sin(angle) + velocity.dy * cos(angle)
        )
        physicsBody.velocity = limitedVelocity(rotatedVelocity)
    }
}
