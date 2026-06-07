import UIKit

final class CampaignViewController: UIViewController {
    private let summaryLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        AppLogger.screen("campaign")
        view.backgroundColor = MainMenuStyling.backgroundColor
        configureNavigation()
        configureSummary()
        configureTable()
        reloadSummary()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        reloadSummary()
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
        title = "Campaign"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Back",
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = MainMenuStyling.accentColor
    }

    private func configureSummary() {
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.font = MainMenuStyling.roundedFont(size: 14, weight: .medium)
        summaryLabel.textColor = MainMenuStyling.subtitleColor
        summaryLabel.textAlignment = .center
        summaryLabel.numberOfLines = 0
        view.addSubview(summaryLabel)
        NSLayoutConstraint.activate([
            summaryLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func configureTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.register(CampaignLevelCell.self, forCellReuseIdentifier: CampaignLevelCell.reuseID)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func reloadSummary() {
        let completed = CampaignProgressStore.completedLevelCount
        let total = CampaignCatalog.allLevels.count
        let stars = CampaignProgressStore.totalStarsEarned
        let maxStars = total * 3
        summaryLabel.text = "\(completed)/\(total) levels cleared · \(stars)/\(maxStars) stars"
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
}

extension CampaignViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        CampaignCatalog.worlds.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        CampaignCatalog.worlds[section].levels.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let world = CampaignCatalog.worlds[section]
        return "\(world.title.uppercased()) — \(world.subtitle)"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CampaignLevelCell.reuseID, for: indexPath) as! CampaignLevelCell
        let level = CampaignCatalog.worlds[indexPath.section].levels[indexPath.row]
        cell.configure(level: level, unlocked: CampaignProgressStore.isUnlocked(level.id))
        return cell
    }
}

extension CampaignViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let level = CampaignCatalog.worlds[indexPath.section].levels[indexPath.row]
        guard CampaignProgressStore.isUnlocked(level.id) else { return }
        AppLogger.track(AppLogger.Event.buttonTap, properties: [
            "button": "campaign_level",
            "level_id": level.id,
        ])
        MainMenuFlowController.presentCampaignLevel(level, from: self)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = MainMenuStyling.roundedFont(size: 12, weight: .semibold)
        header.textLabel?.textColor = MainMenuStyling.subtitleColor
    }
}
