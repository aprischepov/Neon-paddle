import UIKit

enum NoInternetPresentationReason {
    case firstLaunchConfigPending
    case recurringWebViewOffline
}

/// Заглушка «нет сети»: отдельный экран, только кнопки (вёрстку можно заменить позже).
final class NoInternetViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    private let reason: NoInternetPresentationReason
    private let retryButton = UIButton(type: .system)
    private var routingObserver: NSObjectProtocol?
    private var connectivityObserver: NSObjectProtocol?

    init(reason: NoInternetPresentationReason) {
        self.reason = reason
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        retryButton.setTitle("Повторить", for: .normal)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        view.addSubview(retryButton)

        NSLayoutConstraint.activate([
            retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            retryButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        routingObserver = NotificationCenter.default.addObserver(
            forName: .appStartupRoutingReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.goToResolvedIfNeededAfterFirstLaunchRouting()
        }

        connectivityObserver = NotificationCenter.default.addObserver(
            forName: .connectivityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onConnectivityChanged()
        }

        updateRetryAvailability()
    }

    deinit {
        if let routingObserver { NotificationCenter.default.removeObserver(routingObserver) }
        if let connectivityObserver { NotificationCenter.default.removeObserver(connectivityObserver) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        switch reason {
        case .firstLaunchConfigPending:
            goToResolvedIfNeededAfterFirstLaunchRouting()
        case .recurringWebViewOffline:
            tryOpenWebViewAfterRecurringOfflineIfPossible()
        }
    }

    private func onConnectivityChanged() {
        updateRetryAvailability()
        if reason == .recurringWebViewOffline {
            tryOpenWebViewAfterRecurringOfflineIfPossible()
        }
    }

    private func updateRetryAvailability() {
        retryButton.isEnabled = ConnectivityMonitor.shared.isOnline
    }

    @objc private func retryTapped() {
        guard ConnectivityMonitor.shared.isOnline else { return }
        guard let window = view.window else { return }
        switch reason {
        case .firstLaunchConfigPending:
            if let splash = ApplicationFlowResolver.makeSplashRootFromStoryboard() {
                window.rootViewController = splash
            }
            RemoteConfigFetchService.shared.requestConfigRefresh()
        case .recurringWebViewOffline:
            tryOpenWebViewAfterRecurringOfflineIfPossible(forceEndpointRefresh: true)
        }
    }

    private func goToResolvedIfNeededAfterFirstLaunchRouting() {
        guard reason == .firstLaunchConfigPending else { return }
        guard AppStartupSettings.resolvedMode != nil else { return }
        guard let window = view.window else { return }
        ApplicationFlowResolver.applyRoutingReadyIfNeeded(window: window)
    }

    private func tryOpenWebViewAfterRecurringOfflineIfPossible(forceEndpointRefresh: Bool = false) {
        guard reason == .recurringWebViewOffline else { return }
        guard AppStartupSettings.resolvedMode == .webView else { return }
        guard ConnectivityMonitor.shared.isOnline else { return }
        guard let window = view.window else { return }
        ApplicationFlowResolver.installWebViewRoot(in: window)
        if forceEndpointRefresh || RemoteConfigStore.shouldRefreshFromEndpoint {
            RemoteConfigFetchService.shared.requestConfigRefresh()
        }
    }
}
