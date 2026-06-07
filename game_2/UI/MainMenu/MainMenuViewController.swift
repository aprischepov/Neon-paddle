import UIKit

final class MainMenuViewController: UIViewController {
    private let backgroundImageView = UIImageView()
    private let titleLabel = MainMenuStyling.makeTitleLabel("GLOW BOUNCE", size: 40)
    private let playButton = MainMenuStyling.makeOutlineButton(title: "PLAY")
    private let campaignButton = MainMenuStyling.makeOutlineButton(title: "CAMPAIGN")
    private let leaderboardButton = MainMenuStyling.makeOutlineButton(title: "LEADERBOARD")
    private let settingsButton = MainMenuStyling.makeOutlineButton(title: "SETTINGS")
    private let buttonStack = UIStackView()

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        AppLogger.screen("main_menu")
        view.backgroundColor = MainMenuStyling.backgroundColor
        configureBackground()
        configureLayout()
        wireActions()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.updateBackgroundImage() })
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBackgroundImage()
    }

    private func configureBackground() {
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.alpha = 0.56
        view.addSubview(backgroundImageView)
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        updateBackgroundImage()
    }

    private func updateBackgroundImage() {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        let isLandscape = view.bounds.width > view.bounds.height
        backgroundImageView.image = UIImage(named: isLandscape ? "splashHorizontal" : "splashVertical")
    }

    private func configureLayout() {
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.spacing = 14
        buttonStack.alignment = .fill
        [playButton, campaignButton, leaderboardButton, settingsButton].forEach { buttonStack.addArrangedSubview($0) }
        view.addSubview(titleLabel)
        view.addSubview(buttonStack)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -36),
            buttonStack.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            buttonStack.centerYAnchor.constraint(equalTo: safe.centerYAnchor, constant: 24),
            buttonStack.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, constant: -48),
            buttonStack.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
        ])
        [playButton, campaignButton, leaderboardButton, settingsButton].forEach {
            $0.widthAnchor.constraint(equalTo: buttonStack.widthAnchor).isActive = true
        }
    }

    private func wireActions() {
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        campaignButton.addTarget(self, action: #selector(campaignTapped), for: .touchUpInside)
        leaderboardButton.addTarget(self, action: #selector(leaderboardTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
    }

    @objc private func playTapped() {
        AppLogger.track(AppLogger.Event.buttonTap, properties: ["button": "play", "screen": "main_menu"])
        MainMenuFlowController.presentGame(from: self)
    }

    @objc private func campaignTapped() {
        AppLogger.track(AppLogger.Event.buttonTap, properties: ["button": "campaign", "screen": "main_menu"])
        navigationController?.pushViewController(CampaignViewController(), animated: true)
    }

    @objc private func leaderboardTapped() {
        AppLogger.track(AppLogger.Event.buttonTap, properties: ["button": "leaderboard", "screen": "main_menu"])
        navigationController?.pushViewController(LeaderboardViewController(), animated: true)
    }

    @objc private func settingsTapped() {
        AppLogger.track(AppLogger.Event.buttonTap, properties: ["button": "settings", "screen": "main_menu"])
        navigationController?.pushViewController(GameSettingsViewController(), animated: true)
    }
}
