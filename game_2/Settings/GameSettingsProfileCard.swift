import SpriteKit
import UIKit

/// Карточка профиля: аватар (фото или инициалы), ник. Тап по карточке — `profileCardRoot`.
enum GameSettingsProfileCard {
    static let rootNodeName = "profileCardRoot"

    /// Высоты плашки (портрет компактнее — не «монолит» по центру экрана).
    enum Metrics {
        static func plateHeight(isPortrait: Bool) -> CGFloat {
            isPortrait ? 68 : 64
        }

        static func plateHalfHeight(isPortrait: Bool) -> CGFloat {
            plateHeight(isPortrait: isPortrait) * 0.5
        }
    }

    final class Handles {
        let root: SKNode
        private let nicknameLabel: SKLabelNode
        private let subtitleLabel: SKLabelNode
        private let initialsLabel: SKLabelNode
        private let avatarSprite: SKSpriteNode
        private let avatarDiameter: CGFloat

        init(
            root: SKNode,
            nicknameLabel: SKLabelNode,
            subtitleLabel: SKLabelNode,
            initialsLabel: SKLabelNode,
            avatarSprite: SKSpriteNode,
            avatarDiameter: CGFloat
        ) {
            self.root = root
            self.nicknameLabel = nicknameLabel
            self.subtitleLabel = subtitleLabel
            self.initialsLabel = initialsLabel
            self.avatarSprite = avatarSprite
            self.avatarDiameter = avatarDiameter
        }

        func refreshFromStore() {
            nicknameLabel.text = PlayerProfileStore.cardTitleText()
            subtitleLabel.text = PlayerProfileStore.cardSubtitleText()
            initialsLabel.text = PlayerProfileStore.initialsForAvatar()

            if let image = PlayerProfileStore.loadAvatarImage() {
                Handles.layoutAvatarSprite(avatarSprite, image: image, diameter: avatarDiameter)
                avatarSprite.isHidden = false
                initialsLabel.isHidden = true
            } else {
                avatarSprite.texture = nil
                avatarSprite.isHidden = true
                initialsLabel.isHidden = false
            }
        }

        private static func layoutAvatarSprite(_ sprite: SKSpriteNode, image: UIImage, diameter: CGFloat) {
            let tex = SKTexture(image: image)
            sprite.texture = tex
            let iw = max(image.size.width, 1)
            let ih = max(image.size.height, 1)
            let scale = max(diameter / iw, diameter / ih)
            sprite.size = CGSize(width: iw * scale, height: ih * scale)
        }
    }

    enum Layout {
        case portrait(cardCenter: CGPoint, cardWidth: CGFloat)
        case landscape(cardCenter: CGPoint, cardWidth: CGFloat)
    }

    @discardableResult
    static func attach(to parent: SKNode, layout: Layout) -> Handles {
        let (center, width): (CGPoint, CGFloat) = {
            switch layout {
            case let .portrait(c, w): return (c, w)
            case let .landscape(c, w): return (c, w)
            }
        }()

        let root = SKNode()
        root.name = rootNodeName
        root.position = center
        parent.addChild(root)

        let plateW = min(width, 360)
        let plateH = Metrics.plateHeight(isPortrait: layout.isPortrait)
        let corner = min(GameMenuAppearance.pillCornerRadius, plateH * 0.46)
        let plate = SKShapeNode(
            rectOf: CGSize(width: plateW, height: plateH),
            cornerRadius: corner
        )
        plate.fillColor = GameMenuAppearance.profilePlateFill
        plate.strokeColor = GameMenuAppearance.profilePlateStroke
        plate.lineWidth = GameMenuAppearance.outlineLineWidth
        plate.glowWidth = 0
        plate.zPosition = 0
        root.addChild(plate)

        let avatarR: CGFloat = layout.isPortrait ? 26 : 24
        let avatarDiameter = avatarR * 2
        let avatarX = -plateW * 0.5 + 18 + avatarR

        let backdrop = SKShapeNode(circleOfRadius: avatarR)
        backdrop.position = CGPoint(x: avatarX, y: 0)
        backdrop.fillColor = GameMenuAppearance.avatarWellFill
        backdrop.strokeColor = GameMenuAppearance.avatarWellStroke
        backdrop.lineWidth = GameMenuAppearance.outlineLineWidth
        backdrop.glowWidth = 0
        backdrop.zPosition = 1
        root.addChild(backdrop)

        let maskNode = SKShapeNode(circleOfRadius: avatarR)
        maskNode.fillColor = .white

        let crop = SKCropNode()
        crop.maskNode = maskNode
        crop.position = CGPoint(x: avatarX, y: 0)
        crop.zPosition = 2

        let avatarSprite = SKSpriteNode()
        avatarSprite.zPosition = 0
        crop.addChild(avatarSprite)
        root.addChild(crop)

        let initials = GameMenuAppearance.label(
            text: PlayerProfileStore.initialsForAvatar(),
            size: layout.isPortrait ? 15 : 14,
            weight: .semibold,
            horizontal: .center,
            vertical: .center
        )
        initials.fontColor = .white
        initials.position = CGPoint(x: avatarX, y: 0)
        initials.zPosition = 3
        root.addChild(initials)

        let textLeftX = avatarX + avatarR + 14
        let nick = GameMenuAppearance.label(
            text: PlayerProfileStore.cardTitleText(),
            size: layout.isPortrait ? 18 : 17,
            weight: .semibold,
            horizontal: .left,
            vertical: .center
        )
        nick.fontColor = .white
        nick.position = CGPoint(x: textLeftX, y: layout.isPortrait ? 7 : 6)
        nick.zPosition = 1
        root.addChild(nick)

        let sub = GameMenuAppearance.label(
            text: PlayerProfileStore.cardSubtitleText(),
            size: layout.isPortrait ? 11 : 10,
            weight: .medium,
            horizontal: .left,
            vertical: .center
        )
        sub.fontColor = GameMenuAppearance.captionMuted
        sub.position = CGPoint(x: textLeftX, y: layout.isPortrait ? -9 : -8)
        sub.zPosition = 1
        root.addChild(sub)

        let hit = SKShapeNode(rectOf: CGSize(width: plateW + 8, height: plateH + 8), cornerRadius: corner + 2)
        hit.fillColor = .clear
        hit.strokeColor = .clear
        hit.name = rootNodeName
        hit.zPosition = 10
        root.addChild(hit)

        let handles = Handles(
            root: root,
            nicknameLabel: nick,
            subtitleLabel: sub,
            initialsLabel: initials,
            avatarSprite: avatarSprite,
            avatarDiameter: avatarDiameter
        )
        handles.refreshFromStore()
        return handles
    }
}

private extension GameSettingsProfileCard.Layout {
    var isPortrait: Bool {
        if case .portrait = self { return true }
        return false
    }
}
