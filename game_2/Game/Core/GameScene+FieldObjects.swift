import SpriteKit
import UIKit
import CoreImage
import AVFoundation

extension GameScene {
    static func ballOwner(from lastTouchedBy: String) -> BallOwner {
        switch lastTouchedBy {
        case "Player2", "AI":
            return .enemy
        default:
            return .player
        }
    }

    func fieldObject(in contact: SKPhysicsContact) -> FieldObject? {
        if let object = contact.bodyA.node as? FieldObject {
            return object
        }
        return contact.bodyB.node as? FieldObject
    }

    func clearFieldObjects() {
        fieldObjects.forEach { $0.removeFromParent() }
        fieldObjects.removeAll()
    }

    func handleFieldObjectHit(_ object: FieldObject, at contactPoint: CGPoint) {
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

    func showFieldObjectShatter(at position: CGPoint, color: UIColor) {
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

    func applyFieldObjectEffect(_ type: FieldObject.ObjectType) {
        let lastOwner = Self.ballOwner(from: ball?.lastTouchedBy ?? "Player")
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

    func schedulePowerUpsIfNeeded(delay: TimeInterval = 2.0) {
        guard matchGameMode == .powerUps else {
            clearFieldObjects()
            removeAction(forKey: "fieldObjectSpawnDelay")
            return
        }
        scheduleFieldObjectsForRound(delay: delay)
    }

    func spawnFieldObjectsForRound() {
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

    func randomFieldObjectPosition(in zone: CGRect, radius: CGFloat) -> CGPoint {
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

    func scheduleFieldObjectsForRound(delay: TimeInterval = 2.0) {
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
}
