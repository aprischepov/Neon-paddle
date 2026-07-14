import UIKit

final class AchievementCell: UITableViewCell {
    static let reuseID = "AchievementCell"

    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let detailsLabel = UILabel()
    private let statusLabel = UILabel()
    private let cardView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(achievement: Achievement, unlocked: Bool) {
        iconLabel.text = unlocked ? "🏆" : "🔒"
        titleLabel.text = achievement.title
        detailsLabel.text = achievement.details
        statusLabel.text = unlocked ? "DONE" : "LOCKED"
        statusLabel.textColor = unlocked ? MainMenuStyling.accentColor : MainMenuStyling.subtitleColor
        titleLabel.alpha = unlocked ? 1 : 0.5
        detailsLabel.alpha = unlocked ? 0.82 : 0.4
        iconLabel.alpha = unlocked ? 1 : 0.5
        cardView.layer.borderColor = unlocked
            ? MainMenuStyling.accentColor.withAlphaComponent(0.6).cgColor
            : MainMenuStyling.outlineColor.withAlphaComponent(0.18).cgColor
    }

    private func configure() {
        backgroundColor = .clear
        selectionStyle = .none
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor(white: 0.08, alpha: 0.5)
        cardView.layer.cornerRadius = 16
        cardView.layer.borderWidth = 1.22
        cardView.layer.borderColor = MainMenuStyling.outlineColor.cgColor
        contentView.addSubview(cardView)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = MainMenuStyling.roundedFont(size: 22, weight: .regular)
        iconLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = MainMenuStyling.roundedFont(size: 17, weight: .semibold)
        titleLabel.textColor = .white
        detailsLabel.translatesAutoresizingMaskIntoConstraints = false
        detailsLabel.font = MainMenuStyling.roundedFont(size: 12, weight: .medium)
        detailsLabel.textColor = MainMenuStyling.subtitleColor
        detailsLabel.numberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = MainMenuStyling.roundedFont(size: 11, weight: .semibold)
        [iconLabel, titleLabel, detailsLabel, statusLabel].forEach { cardView.addSubview($0) }
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            iconLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            iconLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -8),
            detailsLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailsLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailsLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),
            statusLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            statusLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
        ])
    }
}
