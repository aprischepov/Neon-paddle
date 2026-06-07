import UIKit

final class CampaignLevelCell: UITableViewCell {
    static let reuseID = "CampaignLevelCell"

    private let numberLabel = UILabel()
    private let titleLabel = UILabel()
    private let objectiveLabel = UILabel()
    private let starsLabel = UILabel()
    private let lockIcon = UILabel()
    private let cardView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(level: CampaignLevel, unlocked: Bool) {
        numberLabel.text = level.displayNumber
        titleLabel.text = level.title
        objectiveLabel.text = level.objective
        let stars = CampaignProgressStore.bestStars(for: level.id)
        starsLabel.text = unlocked ? CampaignStarsCalculator.starsText(stars) : "—"
        lockIcon.isHidden = unlocked
        titleLabel.alpha = unlocked ? 1 : 0.45
        objectiveLabel.alpha = unlocked ? 0.82 : 0.35
        starsLabel.alpha = unlocked ? 1 : 0.35
        cardView.layer.borderColor = unlocked
            ? MainMenuStyling.outlineColor.cgColor
            : MainMenuStyling.outlineColor.withAlphaComponent(0.18).cgColor
        selectionStyle = unlocked ? .default : .none
        isUserInteractionEnabled = unlocked
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
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberLabel.font = MainMenuStyling.roundedFont(size: 18, weight: .bold)
        numberLabel.textColor = MainMenuStyling.accentColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = MainMenuStyling.roundedFont(size: 17, weight: .semibold)
        titleLabel.textColor = .white
        objectiveLabel.translatesAutoresizingMaskIntoConstraints = false
        objectiveLabel.font = MainMenuStyling.roundedFont(size: 12, weight: .medium)
        objectiveLabel.textColor = MainMenuStyling.subtitleColor
        objectiveLabel.numberOfLines = 2
        starsLabel.translatesAutoresizingMaskIntoConstraints = false
        starsLabel.font = MainMenuStyling.roundedFont(size: 14, weight: .semibold)
        starsLabel.textColor = .white
        lockIcon.translatesAutoresizingMaskIntoConstraints = false
        lockIcon.text = "🔒"
        lockIcon.font = MainMenuStyling.roundedFont(size: 16, weight: .regular)
        [numberLabel, titleLabel, objectiveLabel, starsLabel, lockIcon].forEach { cardView.addSubview($0) }
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            numberLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            numberLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            numberLabel.widthAnchor.constraint(equalToConstant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: lockIcon.leadingAnchor, constant: -8),
            objectiveLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            objectiveLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            objectiveLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            objectiveLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),
            starsLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            starsLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            lockIcon.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            lockIcon.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
        ])
    }
}
