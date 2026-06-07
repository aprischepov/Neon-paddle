import SpriteKit
import UIKit
import CoreImage
import AVFoundation

extension GameScene {
    func makeGlow(radius: CGFloat, color: UIColor, alpha: CGFloat) -> SKShapeNode {
        let glow = SKShapeNode(circleOfRadius: radius)
        glow.fillColor = color
        glow.strokeColor = .clear
        glow.alpha = alpha
        glow.zPosition = -95
        glow.blendMode = .add
        return glow
    }

    func createGrid() {
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

    func aspectFillSize(for textureSize: CGSize, in targetSize: CGSize) -> CGSize {
        guard textureSize.width > 0, textureSize.height > 0 else { return targetSize }
        let scale = max(targetSize.width / textureSize.width, targetSize.height / textureSize.height)
        return CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
    }

    func pulseBackground(with color: UIColor) {
        backgroundPulseNode?.removeAction(forKey: "impactPulse")
        backgroundPulseNode?.color = color
        backgroundPulseNode?.colorBlendFactor = 1
        backgroundPulseNode?.alpha = 0
        backgroundPulseNode?.run(.sequence([
            .fadeAlpha(to: 0.13, duration: 0.035),
            .fadeOut(withDuration: 0.22)
        ]), withKey: "impactPulse")
    }

    func setupBackground() {
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

    func createParticleStars() {
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

    func createSpaceBackground() {
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

    func updateBackgroundIfNeeded(score: Int) {
        let backgroundStep = score / backgroundChangeInterval
        guard backgroundStep > lastBackgroundStep else { return }
        lastBackgroundStep = backgroundStep
        let color = backgroundColors[backgroundStep % backgroundColors.count]
        let colorize = SKAction.colorize(with: color, colorBlendFactor: 1, duration: 1.2)
        backgroundNode?.run(colorize, withKey: "backgroundColorize")
    }
}
