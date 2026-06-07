import UIKit

final class ProfileSettingsCardView: UIControl {
    private let plateView = UIView()
    private let avatarBackdrop = UIView()
    private let avatarImageView = UIImageView()
    private let initialsLabel = UILabel()
    private let nicknameLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
        refreshFromStore()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshFromStore() {
        nicknameLabel.text = PlayerProfileStore.cardTitleText()
        subtitleLabel.text = PlayerProfileStore.cardSubtitleText()
        initialsLabel.text = PlayerProfileStore.initialsForAvatar()
        if let image = PlayerProfileStore.loadAvatarImage() {
            avatarImageView.image = image
            avatarImageView.isHidden = false
            initialsLabel.isHidden = true
        } else {
            avatarImageView.image = nil
            avatarImageView.isHidden = true
            initialsLabel.isHidden = false
        }
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        plateView.translatesAutoresizingMaskIntoConstraints = false
        plateView.backgroundColor = GameMenuAppearance.profilePlateFill
        plateView.layer.cornerRadius = 16
        plateView.layer.borderWidth = GameMenuAppearance.outlineLineWidth
        plateView.layer.borderColor = GameMenuAppearance.profilePlateStroke.cgColor
        plateView.isUserInteractionEnabled = false
        addSubview(plateView)
        avatarBackdrop.translatesAutoresizingMaskIntoConstraints = false
        avatarBackdrop.backgroundColor = GameMenuAppearance.avatarWellFill
        avatarBackdrop.layer.cornerRadius = 26
        avatarBackdrop.layer.borderWidth = GameMenuAppearance.outlineLineWidth
        avatarBackdrop.layer.borderColor = GameMenuAppearance.avatarWellStroke.cgColor
        avatarBackdrop.clipsToBounds = true
        avatarBackdrop.isUserInteractionEnabled = false
        plateView.addSubview(avatarBackdrop)
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarBackdrop.addSubview(avatarImageView)
        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.font = MainMenuStyling.roundedFont(size: 15, weight: .semibold)
        initialsLabel.textColor = .white
        initialsLabel.textAlignment = .center
        avatarBackdrop.addSubview(initialsLabel)
        nicknameLabel.translatesAutoresizingMaskIntoConstraints = false
        nicknameLabel.font = MainMenuStyling.roundedFont(size: 18, weight: .semibold)
        nicknameLabel.textColor = .white
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = MainMenuStyling.roundedFont(size: 11, weight: .medium)
        subtitleLabel.textColor = GameMenuAppearance.captionMuted
        plateView.addSubview(nicknameLabel)
        plateView.addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 68),
            plateView.topAnchor.constraint(equalTo: topAnchor),
            plateView.leadingAnchor.constraint(equalTo: leadingAnchor),
            plateView.trailingAnchor.constraint(equalTo: trailingAnchor),
            plateView.bottomAnchor.constraint(equalTo: bottomAnchor),
            avatarBackdrop.leadingAnchor.constraint(equalTo: plateView.leadingAnchor, constant: 18),
            avatarBackdrop.centerYAnchor.constraint(equalTo: plateView.centerYAnchor),
            avatarBackdrop.widthAnchor.constraint(equalToConstant: 52),
            avatarBackdrop.heightAnchor.constraint(equalToConstant: 52),
            avatarImageView.topAnchor.constraint(equalTo: avatarBackdrop.topAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarBackdrop.leadingAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: avatarBackdrop.trailingAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarBackdrop.bottomAnchor),
            initialsLabel.centerXAnchor.constraint(equalTo: avatarBackdrop.centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: avatarBackdrop.centerYAnchor),
            nicknameLabel.leadingAnchor.constraint(equalTo: avatarBackdrop.trailingAnchor, constant: 14),
            nicknameLabel.trailingAnchor.constraint(equalTo: plateView.trailingAnchor, constant: -16),
            nicknameLabel.topAnchor.constraint(equalTo: plateView.centerYAnchor, constant: -10),
            subtitleLabel.leadingAnchor.constraint(equalTo: nicknameLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: nicknameLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: nicknameLabel.bottomAnchor, constant: 2),
        ])
    }
}
