import UIKit

/// Кастомный запрос уведомлений до WebView; вёрстка в `UIScrollView` для портрета и альбома.
final class PushNotificationPrePromptViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    private let onAllow: () -> Void
    private let onSkip: () -> Void

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stack = UIStackView()
    private let allowButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)

    init(onAllow: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.onAllow = onAllow
        self.onSkip = onSkip
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        contentView.translatesAutoresizingMaskIntoConstraints = false

        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        allowButton.setTitle("Разрешить уведомления", for: .normal)
        allowButton.addTarget(self, action: #selector(allowTapped), for: .touchUpInside)

        skipButton.setTitle("Не сейчас", for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)

        stack.addArrangedSubview(allowButton)
        stack.addArrangedSubview(skipButton)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stack)

        let centerY = stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        centerY.priority = UILayoutPriority(750)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            stack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
            centerY,
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor),
        ])
    }

    @objc private func allowTapped() {
        dismiss(animated: true) { self.onAllow() }
    }

    @objc private func skipTapped() {
        dismiss(animated: true) { self.onSkip() }
    }
}
