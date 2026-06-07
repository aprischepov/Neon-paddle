import SpriteKit
import UIKit

extension GameScene {
    func applyBuff(to owner: BallOwner) {
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

    func applyHazard(toOpponentOf owner: BallOwner) {
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

    func runBuffRecovery(for owner: BallOwner) {
        let actionKey = owner == .player ? "playerBuffRecovery" : "enemyBuffRecovery"
        removeAction(forKey: actionKey)
        run(.sequence([
            .wait(forDuration: 7),
            .run { [weak self] in
                self?.clearBuff(for: owner)
            }
        ]), withKey: actionKey)
    }

    func runDebuffRecovery(for owner: BallOwner) {
        let actionKey = owner == .player ? "playerDebuffRecovery" : "enemyDebuffRecovery"
        removeAction(forKey: actionKey)
        run(.sequence([
            .wait(forDuration: 7),
            .run { [weak self] in
                self?.clearHazardDebuff(for: owner)
            }
        ]), withKey: actionKey)
    }

    func clearHazardDebuff(for owner: BallOwner) {
        switch owner {
        case .player:
            playerIsDebuffed = false
        case .enemy:
            enemyIsDebuffed = false
        }
        updatePaddleScale(for: owner)
    }

    func clearBuff(for owner: BallOwner) {
        switch owner {
        case .player:
            playerHasShield = false
        case .enemy:
            enemyHasShield = false
        }
        updatePaddleScale(for: owner)
    }

    func playPlatformRecoil(_ paddleNode: SKNode?) {
        guard let paddleNode else { return }
        let baseXScale = paddleNode.xScale
        let baseYScale = paddleNode.yScale
        paddleNode.removeAction(forKey: "recoil")
        paddleNode.run(.sequence([
            .scaleX(to: baseXScale * 1.12, y: baseYScale, duration: 0.045),
            .scaleX(to: baseXScale, y: baseYScale, duration: 0.09)
        ]), withKey: "recoil")
    }
}
