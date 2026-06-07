import SpriteKit

final class Ball: SKShapeNode {
    var lastTouchedBy = ""

    init(radius: CGFloat) {
        super.init()
        path = CGPath(
            ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
            transform: nil
        )
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
