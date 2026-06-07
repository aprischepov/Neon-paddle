import UIKit

enum MainMenuStyling {
    static let backgroundColor = UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 1)
    static let accentColor = UIColor(red: 0.0, green: 0.82, blue: 1.0, alpha: 1)
    static let outlineColor = UIColor.white.withAlphaComponent(0.34)
    static let titleColor = UIColor.white.withAlphaComponent(0.94)
    static let subtitleColor = UIColor.white.withAlphaComponent(0.52)

    static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: size)
    }

    static func makeOutlineButton(title: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .white
        config.background.strokeColor = outlineColor
        config.background.strokeWidth = 1.22
        config.background.cornerRadius = 16
        config.background.backgroundColor = .clear
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = roundedFont(size: 20, weight: .semibold)
            return outgoing
        }
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 28, bottom: 14, trailing: 28)
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        return button
    }

    static func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = roundedFont(size: 12, weight: .semibold)
        label.textColor = subtitleColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    static func makeTitleLabel(_ text: String, size: CGFloat) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = roundedFont(size: size, weight: .bold)
        label.textColor = titleColor
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
}
