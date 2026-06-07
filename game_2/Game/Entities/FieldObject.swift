import SpriteKit
import UIKit

final class FieldObject: SKShapeNode {
    enum ObjectType {
        case buff
        case hazard

        var color: UIColor {
            switch self {
            case .buff:
                return UIColor(red: 0.18, green: 1.0, blue: 0.38, alpha: 1)
            case .hazard:
                return UIColor(red: 1.0, green: 0.12, blue: 0.18, alpha: 1)
            }
        }
    }

    let objectType: ObjectType

    init(type: ObjectType, sides: Int, radius: CGFloat) {
        objectType = type
        super.init()
        path = Self.makePolygonPath(sides: sides, radius: radius)
        fillColor = type.color.withAlphaComponent(0.22)
        strokeColor = type.color
        lineWidth = 2.4
        glowWidth = 10
        addNeonGlow(color: type.color)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        objectType = .buff
        super.init(coder: aDecoder)
    }

    private static func makePolygonPath(sides: Int, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let clampedSides = max(sides, 3)
        for index in 0..<clampedSides {
            let angle = CGFloat(index) / CGFloat(clampedSides) * .pi * 2 + .pi / 2
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    func startAliveAnimation() {
        run(.repeatForever(.rotate(byAngle: .pi, duration: 2.0)), withKey: "fieldRotate")
        run(.repeatForever(.sequence([
            .scale(to: 1.08, duration: 1.0),
            .scale(to: 1.0, duration: 1.0)
        ])), withKey: "fieldPulse")
    }

    private func addNeonGlow(color: UIColor) {
        guard let path else { return }
        let glowEffect = SKEffectNode()
        glowEffect.name = "neonGlow"
        glowEffect.zPosition = -1
        glowEffect.filter = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 9])
        glowEffect.shouldRasterize = true
        let innerGlow = SKShapeNode(path: path)
        innerGlow.fillColor = color
        innerGlow.strokeColor = color
        innerGlow.alpha = 0.55
        innerGlow.blendMode = .add
        glowEffect.addChild(innerGlow)
        let outerGlow = SKShapeNode(path: path)
        outerGlow.fillColor = color
        outerGlow.strokeColor = .clear
        outerGlow.alpha = 0.22
        outerGlow.setScale(1.35)
        outerGlow.blendMode = .add
        glowEffect.addChild(outerGlow)
        addChild(glowEffect)
    }
}
