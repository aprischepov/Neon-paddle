import SpriteKit
import UIKit

/// Единый визуальный язык меню: обводки, стекло, SF Rounded.
enum GameMenuAppearance {
    // MARK: - Outline / glass

    static let outlineStroke = UIColor.white.withAlphaComponent(0.34)
    static let outlineLineWidth: CGFloat = 1.22
    static let pillCornerRadius: CGFloat = 16

    static let glassFill = UIColor(white: 0.08, alpha: 0.5)

    static let captionMuted = UIColor.white.withAlphaComponent(0.5)

    // MARK: - Labels (SF Rounded, same pipeline everywhere)

    static func label(
        text: String,
        size: CGFloat,
        weight: UIFont.Weight,
        horizontal: SKLabelHorizontalAlignmentMode = .center,
        vertical: SKLabelVerticalAlignmentMode = .center
    ) -> SKLabelNode {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        let font = UIFont(descriptor: descriptor, size: size)
        let node = SKLabelNode(fontNamed: font.fontName)
        node.text = text
        node.fontSize = size
        node.fontColor = .white
        node.horizontalAlignmentMode = horizontal
        node.verticalAlignmentMode = vertical
        return node
    }

    // MARK: - Picker row

    static let pickerSectionTitleAlpha: CGFloat = 0.52

    static func pickerTitleSize(isLandscape: Bool) -> CGFloat {
        isLandscape ? 11 : 12
    }

    static func pickerValueSize(isLandscape: Bool) -> CGFloat {
        isLandscape ? 24 : 28
    }

    static func pickerArrowSize(isLandscape: Bool) -> CGFloat {
        isLandscape ? 28 : 30
    }

    // MARK: - Primary outline button (START, SETTINGS, BACK, …)

    static let defaultButtonSize = CGSize(width: 172, height: 52)
    static let defaultButtonTitleSize: CGFloat = 22

    static func outlinePillButton(
        title: String,
        name: String,
        buttonSize: CGSize = defaultButtonSize,
        titleSize: CGFloat = defaultButtonTitleSize
    ) -> SKShapeNode {
        let corner = min(pillCornerRadius, buttonSize.height * 0.46)
        let shape = SKShapeNode(rectOf: buttonSize, cornerRadius: corner)
        shape.name = name
        shape.fillColor = .clear
        shape.strokeColor = outlineStroke
        shape.lineWidth = outlineLineWidth

        let titleLabel = label(text: title, size: titleSize, weight: .semibold)
        titleLabel.name = name
        titleLabel.position = .zero
        shape.addChild(titleLabel)
        return shape
    }

    // MARK: - Profile plate (same stroke/fill family as buttons)

    static let profilePlateFill = glassFill
    static let profilePlateStroke = outlineStroke
    static let avatarWellFill = UIColor(white: 0.1, alpha: 0.92)
    static let avatarWellStroke = outlineStroke
}
