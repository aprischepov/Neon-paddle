import SpriteKit
import UIKit
import CoreImage
import AVFoundation

extension GameScene {
    func makeLabel(text: String, size: CGFloat, weight: UIFont.Weight) -> SKLabelNode {
        GameMenuAppearance.label(text: text, size: size, weight: weight)
    }

    func makeButton(
        title: String,
        name: String,
        buttonSize: CGSize? = nil,
        titleSize: CGFloat? = nil
    ) -> SKShapeNode {
        let size = buttonSize ?? GameMenuAppearance.defaultButtonSize
        let ts = titleSize ?? GameMenuAppearance.defaultButtonTitleSize
        return GameMenuAppearance.outlinePillButton(title: title, name: name, buttonSize: size, titleSize: ts)
    }

    func buttonNode(from node: SKNode, named name: String) -> SKNode? {
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

    func requestMainMenu() {
        gameDelegate?.gameSceneDidRequestMainMenu(self)
    }

    func animateButtonPress(_ button: SKNode?, completion: @escaping () -> Void) {
        guard let button else {
            completion()
            return
        }
        if let name = button.name {
            AppLogger.track(AppLogger.Event.buttonTap, properties: [
                "button": name,
                "screen": analyticsScreenName()
            ].merging(analyticsOrientation()) { _, new in new })
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

    func analyticsScreenName() -> String {
        switch gameState {
        case .playing: return "playing"
        case .paused: return "paused"
        case .gameOver: return "game_over"
        }
    }

    func clearGameReferences() {
        backgroundNode = nil
        backgroundPulseNode = nil
        paddle = nil
        enemyPaddle = nil
        ball = nil
        ballTrail = nil
        fieldObjects = []
        worldNode = nil
        scoreboardLabel = nil
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

    func makeScoreboardLabel(text: String, size: CGFloat) -> SKLabelNode {
        let font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: .black)
        let label = SKLabelNode(fontNamed: font.fontName)
        label.text = text
        label.fontSize = size
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        return label
    }

    func analyticsOrientation() -> [String: Any] {
        ["orientation": isLandscapeLayout ? "landscape" : "portrait"]
    }

    func fadeOutActiveOverlay(completion: @escaping () -> Void) {
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
}
