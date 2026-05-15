//
//  SplashViewController.swift
//  Glow Bounce
//

import UIKit

/// Брендированный лоадинг: без искусственной задержки — переход, когда готово (повторный запуск сразу; первый — после ответа конфига).
/// Первый запуск: запрос конфига с появлением сплеша; не дольше `firstLaunchMaximumSplashDuration` — иначе экран «нет сети» с повтором.
final class SplashViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    private let imageView = UIImageView()
    private var didFinishSplash = false
    private var firstLaunchPipelineStarted = false
    private var awaitingFirstLaunchRouting = false
    private var routingObserver: NSObjectProtocol?
    private var transportObserver: NSObjectProtocol?
    private var connectivityObserver: NSObjectProtocol?
    private var configGateReadyObserver: NSObjectProtocol?
    private var maxSplashTimer: Timer?
    private var firstLaunchConfigRequestSent = false

    /// Максимальное время первого запуска на сплеше (AF + config + переход), п. 1.3 ТЗ.
    private let firstLaunchMaximumSplashDuration: TimeInterval = 10

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        updateSplashImage()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didFinishSplash else { return }

        if AppStartupSettings.resolvedMode != nil {
            completeRecurringSplashTransition()
        } else {
            startFirstLaunchPipelineIfNeeded()
        }
    }

    deinit {
        maxSplashTimer?.invalidate()
        teardownFirstLaunchObservers()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateSplashImage()
        })
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSplashImage()
    }

    private func updateSplashImage() {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        let isLandscape = view.bounds.width > view.bounds.height
        imageView.image = UIImage(named: isLandscape ? "loadingHorizontal" : "loadingVertical")
    }

    /// Повторный запуск: сразу `transitionFromSplash` (WebView / обёртка / оффлайн).
    private func completeRecurringSplashTransition() {
        guard !didFinishSplash else { return }
        didFinishSplash = true
        guard let window = view.window else { return }
        ApplicationFlowResolver.transitionFromSplash(window: window)
    }

    private func startFirstLaunchPipelineIfNeeded() {
        guard !firstLaunchPipelineStarted else { return }
        firstLaunchPipelineStarted = true
        awaitingFirstLaunchRouting = true

        routingObserver = NotificationCenter.default.addObserver(
            forName: .appStartupRoutingReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleFirstLaunchRoutingReady()
        }

        transportObserver = NotificationCenter.default.addObserver(
            forName: .appStartupConfigTransportFailed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleFirstLaunchTransportFailed()
        }

        connectivityObserver = NotificationCenter.default.addObserver(
            forName: .connectivityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleFirstLaunchConnectivityChange()
        }

        maxSplashTimer = Timer.scheduledTimer(withTimeInterval: firstLaunchMaximumSplashDuration, repeats: false) { [weak self] _ in
            self?.handleFirstLaunchMaxSplashElapsed()
        }
        if let maxSplashTimer {
            RunLoop.main.add(maxSplashTimer, forMode: .common)
        }

        if AppStartupSettings.resolvedMode != nil {
            handleFirstLaunchRoutingReady()
            return
        }
        if !ConnectivityMonitor.shared.isOnline {
            showNoInternetRootFromSplash()
            return
        }

        configGateReadyObserver = NotificationCenter.default.addObserver(
            forName: .firstLaunchConfigGateDidBecomeReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.requestFirstLaunchConfigIfNeeded()
        }

        FirstLaunchConfigGate.shared.beginWaitingForAttribution(maxDuration: firstLaunchMaximumSplashDuration)

        if FirstLaunchConfigGate.shared.isReadyForConfigRequest {
            requestFirstLaunchConfigIfNeeded()
        }
    }

    private func requestFirstLaunchConfigIfNeeded() {
        guard awaitingFirstLaunchRouting else { return }
        guard AppStartupSettings.resolvedMode == nil else { return }
        firstLaunchConfigRequestSent = true
        RemoteConfigFetchService.shared.requestConfigRefresh()
    }

    private func handleFirstLaunchRoutingReady() {
        guard awaitingFirstLaunchRouting else { return }
        guard AppStartupSettings.resolvedMode != nil else { return }
        maxSplashTimer?.invalidate()
        maxSplashTimer = nil
        FirstLaunchConfigGate.shared.cancelSplashTimeout()
        finishFirstLaunchRouting()
    }

    private func handleFirstLaunchTransportFailed() {
        guard awaitingFirstLaunchRouting else { return }
        if !ConnectivityMonitor.shared.isOnline {
            showNoInternetRootFromSplash()
        } else {
            RemoteConfigFetchService.shared.requestConfigRefresh()
        }
    }

    private func handleFirstLaunchConnectivityChange() {
        guard awaitingFirstLaunchRouting else { return }
        if !ConnectivityMonitor.shared.isOnline {
            guard !firstLaunchConfigRequestSent else { return }
            showNoInternetRootFromSplash()
        }
    }

    /// Лимит 10 с: при наличии attribution или отправленном config — wrapper и переход (Organic → «No data»).
    private func handleFirstLaunchMaxSplashElapsed() {
        guard awaitingFirstLaunchRouting else { return }
        if AppStartupSettings.resolvedMode != nil {
            handleFirstLaunchRoutingReady()
            return
        }

        FirstLaunchConfigGate.shared.forceReadyForSplashDeadline()

        let hasAttribution = AppsFlyerAttributionService.shared.currentConversionPayload() != nil
        if hasAttribution || firstLaunchConfigRequestSent {
            if !firstLaunchConfigRequestSent {
                requestFirstLaunchConfigIfNeeded()
            }
            if AppStartupSettings.resolvedMode == nil {
                AppStartupSettings.setResolved(.wrapper)
            }
            handleFirstLaunchRoutingReady()
            return
        }

        showNoInternetRootFromSplash()
    }

    private func finishFirstLaunchRouting() {
        guard let window = view.window else { return }
        guard !didFinishSplash, awaitingFirstLaunchRouting else { return }
        didFinishSplash = true
        awaitingFirstLaunchRouting = false
        maxSplashTimer?.invalidate()
        maxSplashTimer = nil
        teardownFirstLaunchObservers()
        ApplicationFlowResolver.applyRoutingReadyIfNeeded(window: window)
    }

    private func showNoInternetRootFromSplash() {
        maxSplashTimer?.invalidate()
        maxSplashTimer = nil
        awaitingFirstLaunchRouting = false
        didFinishSplash = true
        teardownFirstLaunchObservers()
        guard let window = view.window else { return }
        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
            window.rootViewController = NoInternetViewController(reason: .firstLaunchConfigPending)
        }
    }

    private func teardownFirstLaunchObservers() {
        if let routingObserver {
            NotificationCenter.default.removeObserver(routingObserver)
            self.routingObserver = nil
        }
        if let transportObserver {
            NotificationCenter.default.removeObserver(transportObserver)
            self.transportObserver = nil
        }
        if let connectivityObserver {
            NotificationCenter.default.removeObserver(connectivityObserver)
            self.connectivityObserver = nil
        }
        if let configGateReadyObserver {
            NotificationCenter.default.removeObserver(configGateReadyObserver)
            self.configGateReadyObserver = nil
        }
    }
}
