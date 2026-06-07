import UIKit

final class LeaderboardViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var rows: [String] = []

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        AppLogger.screen("leaderboard")
        view.backgroundColor = MainMenuStyling.backgroundColor
        configureNavigation()
        configureTable()
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
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
        title = "Leaderboard"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Back",
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = MainMenuStyling.accentColor
    }

    private func configureTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = MainMenuStyling.outlineColor
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func reloadData() {
        rows = LocalLeaderboardStore.matchTableRows(limit: 12)
        tableView.reloadData()
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
}

extension LeaderboardViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 3 : max(rows.count, 1)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Summary" : "Recent matches"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.font = MainMenuStyling.roundedFont(size: 15, weight: .medium)
        config.textProperties.color = .white
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                config.text = "Total points: \(LocalLeaderboardStore.totalPoints)"
            case 1:
                config.text = "Win streak: \(LocalLeaderboardStore.currentWinStreak) · Best: \(LocalLeaderboardStore.bestWinStreak)"
            default:
                config.text = "Win +\(LocalLeaderboardStore.pointsPerWin) · Loss +\(LocalLeaderboardStore.pointsPerLoss)"
            }
        } else if rows.isEmpty {
            config.text = "No matches yet — win a game!"
            config.textProperties.color = MainMenuStyling.subtitleColor
        } else {
            config.text = rows[indexPath.row]
            config.textProperties.font = MainMenuStyling.roundedFont(size: 13, weight: .medium)
        }
        cell.contentConfiguration = config
        cell.backgroundColor = UIColor(white: 0.08, alpha: 0.5)
        cell.selectionStyle = .none
        return cell
    }
}
