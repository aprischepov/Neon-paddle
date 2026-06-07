import SpriteKit
import UIKit
import CoreImage
import AVFoundation

extension GameScene {
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
                let isTwoPlayer = matchGameMode == .localTwoPlayer
                lastBallOwner = .enemy
                ball?.lastTouchedBy = isTwoPlayer ? "Player2" : "AI"
                setBallOwnerColor(.enemy)
                handlePaddleHit(
                    at: contact.contactPoint,
                    paddleNode: enemyPaddle,
                    appliesPlayerSpin: isTwoPlayer,
                    spinUsesEnemyPaddle: isTwoPlayer
                )
                if !isTwoPlayer {
                    addRandomVelocityJitter()
                }
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
}
