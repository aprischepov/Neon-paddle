import UIKit

final class AchievementsViewController: UIViewController {
    private let summaryLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        AppLogger.screen("achievements")
        view.backgroundColor = MainMenuStyling.backgroundColor
        AchievementStore.evaluate()
        configureNavigation()
        configureSummary()
        configureTable()
        reloadSummary()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AchievementStore.evaluate()
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
        title = "Achievements"
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
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 82
        tableView.register(AchievementCell.self, forCellReuseIdentifier: AchievementCell.reuseID)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func reloadSummary() {
        summaryLabel.text = "\(AchievementStore.unlockedCount)/\(AchievementStore.totalCount) unlocked"
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
}

extension AchievementsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        AchievementCatalog.all.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AchievementCell.reuseID, for: indexPath) as! AchievementCell
        let achievement = AchievementCatalog.all[indexPath.row]
        cell.configure(achievement: achievement, unlocked: AchievementStore.isUnlocked(achievement.id))
        return cell
    }
}
