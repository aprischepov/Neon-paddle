import UIKit

final class GameSettingsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let difficultyRow = GameSettingsPickerRow(title: "Difficulty")
    private let modeRow = GameSettingsPickerRow(title: "Mode")
    private let notificationsRow = GameSettingsPickerRow(title: "Notifications")
    private let profileCard = ProfileSettingsCardView()
    private var profilePresenter: ProfileEditorPresenter?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        AppLogger.screen("settings")
        view.backgroundColor = MainMenuStyling.backgroundColor
        configureNavigation()
        configureLayout()
        reloadPickers()
        profilePresenter = ProfileEditorPresenter(host: self) { [weak self] in
            self?.profileCard.refreshFromStore()
        }
        profileCard.addTarget(self, action: #selector(profileTapped), for: .touchUpInside)
    }

    private func configureNavigation() {
        navigationController?.setNavigationBarHidden(false, animated: false)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .foregroundColor: MainMenuStyling.titleColor,
            .font: MainMenuStyling.roundedFont(size: 17, weight: .semibold),
        ]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        title = "Settings"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Back",
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = MainMenuStyling.accentColor
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 8
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        [difficultyRow, modeRow, notificationsRow].forEach { contentStack.addArrangedSubview($0) }
        let profileCaption = MainMenuStyling.makeSectionLabel("PROFILE")
        contentStack.addArrangedSubview(profileCaption)
        contentStack.addArrangedSubview(profileCard)
        let supportButton = MainMenuStyling.makeOutlineButton(title: "SUPPORT")
        supportButton.addTarget(self, action: #selector(supportTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(supportButton)
        let legalStack = UIStackView()
        legalStack.axis = .horizontal
        legalStack.spacing = 12
        legalStack.distribution = .fillEqually
        let privacyButton = MainMenuStyling.makeOutlineButton(title: "PRIVACY")
        privacyButton.addTarget(self, action: #selector(privacyTapped), for: .touchUpInside)
        let termsButton = MainMenuStyling.makeOutlineButton(title: "TERMS")
        termsButton.addTarget(self, action: #selector(termsTapped), for: .touchUpInside)
        legalStack.addArrangedSubview(privacyButton)
        legalStack.addArrangedSubview(termsButton)
        contentStack.addArrangedSubview(legalStack)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safe.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48),
        ])
    }

    private func reloadPickers() {
        let difficulties = AIDifficulty.allCases
        let difficultyIndex = difficulties.firstIndex(of: GamePreferencesStore.difficulty) ?? 1
        difficultyRow.configure(
            count: difficulties.count,
            selectedIndex: difficultyIndex,
            titles: difficulties.map(\.title)
        ) { index in
            GamePreferencesStore.difficulty = difficulties[index]
            AppLogger.track(AppLogger.Event.settingsChanged, properties: [
                "setting": "difficulty",
                "value": difficulties[index].title,
            ])
        }
        let modes = GameMode.allCases
        let modeIndex = modes.firstIndex(of: GamePreferencesStore.gameMode) ?? 0
        modeRow.configure(
            count: modes.count,
            selectedIndex: modeIndex,
            titles: modes.map(\.title)
        ) { [weak self] index in
            GamePreferencesStore.gameMode = modes[index]
            self?.updateDifficultyVisibility()
            AppLogger.track(AppLogger.Event.settingsChanged, properties: [
                "setting": "game_mode",
                "value": modes[index].title,
            ])
        }
        updateDifficultyVisibility()
        let notificationsEnabled = GameNotificationPreferenceStore.isUserRemoteNotificationsEnabled
        notificationsRow.configure(
            count: 2,
            selectedIndex: notificationsEnabled ? 1 : 0,
            titles: ["Off", "On"]
        ) { [weak self] index in
            self?.setNotificationsEnabled(index == 1)
        }
    }

    private func updateDifficultyVisibility() {
        let hidesDifficulty = !GamePreferencesStore.gameMode.usesAIOpponent
        difficultyRow.isHidden = hidesDifficulty
    }

    private func setNotificationsEnabled(_ enabled: Bool) {
        guard enabled != GameNotificationPreferenceStore.isUserRemoteNotificationsEnabled else { return }
        GameNotificationPreferenceStore.isUserRemoteNotificationsEnabled = enabled
        notificationsRow.setValue(GameNotificationPreferenceStore.notificationsPickerTitle(isEnabled: enabled))
        AppLogger.track(AppLogger.Event.notificationsToggled, properties: ["enabled": enabled])
        if enabled {
            GameNotificationPreferenceStore.applyEnableFromSettings { [weak self] in
                GameNotificationPreferenceStore.isUserRemoteNotificationsEnabled = false
                self?.notificationsRow.setValue(
                    GameNotificationPreferenceStore.notificationsPickerTitle(isEnabled: false)
                )
                AppLogger.track(AppLogger.Event.notificationsToggled, properties: [
                    "enabled": false,
                    "reason": "permission_denied",
                ])
            }
        }
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func profileTapped() {
        profilePresenter?.presentProfileEditor()
    }

    @objc private func supportTapped() {
        LegalPagePresenter.present(title: "Support", url: AppConstants.Legal.supportURL, from: self)
    }

    @objc private func privacyTapped() {
        LegalPagePresenter.present(title: "Privacy Policy", url: AppConstants.Legal.privacyPolicyURL, from: self)
    }

    @objc private func termsTapped() {
        LegalPagePresenter.present(title: "Terms of Use", url: AppConstants.Legal.termsOfUseURL, from: self)
    }
}
