import UIKit
final class SplashViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }
    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }
    private let imageView = UIImageView()
    private let loadingStack = UIStackView()
    private let spinnerImageView = UIImageView()
    private let loadingImageView = UIImageView()
    private var didFinishSplash = false
    private var variantRoutingStarted = false
    private var abConfigObserver: NSObjectProtocol?
    private var abConfigTimeoutTimer: Timer?
    private var firstLaunchPipelineStarted = false
    private var awaitingFirstLaunchRouting = false
    private var routingObserver: NSObjectProtocol?
    private var transportObserver: NSObjectProtocol?
    private var connectivityObserver: NSObjectProtocol?
    private var configGateReadyObserver: NSObjectProtocol?
    private var maxSplashTimer: Timer?
    private var firstLaunchConfigRequestSent = false
    private let firstLaunchMaximumSplashDuration: TimeInterval = 10
    private let variantDecisionTimeout: TimeInterval = 8
    private let loadingStackSpacing: CGFloat = 20
    private let spinnerImageSize: CGFloat = 56
    private let loadingImageMaxWidthRatio: CGFloat = 0.5
    private let spinnerRotationDuration: TimeInterval = 1.2
    private let spinnerRotationKey = "spinnerRotation"
    override func viewDidLoad() {
        super.viewDidLoad()
        AppLogger.screen("splash")
        view.backgroundColor = .black
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        view.addSubview(imageView)
        configureLoadingStack()
        setSpinnerVisible(true)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        updateSplashImage()
    }
    private func configureLoadingStack() {
        loadingStack.translatesAutoresizingMaskIntoConstraints = false
        loadingStack.axis = .vertical
        loadingStack.spacing = loadingStackSpacing
        loadingStack.alignment = .center
        loadingStack.isHidden = true
        loadingStack.isAccessibilityElement = false
        spinnerImageView.translatesAutoresizingMaskIntoConstraints = false
        spinnerImageView.image = UIImage(named: "spinner")
        spinnerImageView.contentMode = .scaleAspectFit
        loadingImageView.translatesAutoresizingMaskIntoConstraints = false
        let loadingImage = UIImage(named: "loading")
        loadingImageView.image = loadingImage
        loadingImageView.contentMode = .scaleAspectFit
        loadingStack.addArrangedSubview(spinnerImageView)
        loadingStack.addArrangedSubview(loadingImageView)
        view.addSubview(loadingStack)
        view.bringSubviewToFront(loadingStack)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            loadingStack.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            loadingStack.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            spinnerImageView.widthAnchor.constraint(equalToConstant: spinnerImageSize),
            spinnerImageView.heightAnchor.constraint(equalToConstant: spinnerImageSize),
            loadingImageView.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, multiplier: loadingImageMaxWidthRatio),
        ])
        if let loadingImage, loadingImage.size.width > 0 {
            loadingImageView.heightAnchor.constraint(
                equalTo: loadingImageView.widthAnchor,
                multiplier: loadingImage.size.height / loadingImage.size.width
            ).isActive = true
        }
    }
    private func setSpinnerVisible(_ visible: Bool) {
        loadingStack.isHidden = !visible
        if visible {
            startSpinnerRotation()
        } else {
            stopSpinnerRotation()
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didFinishSplash else { return }
        if InlineRoutingGate.hasPersistedRoutingDecision {
            beginInlineRouting()
            return
        }
        startVariantAwareRoutingIfNeeded()
    }
    deinit {
        abConfigTimeoutTimer?.invalidate()
        maxSplashTimer?.invalidate()
        teardownABObservers()
        teardownFirstLaunchObservers()
    }
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.updateSplashImage() })
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSplashImage()
    }
    private func updateSplashImage() {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        let isLandscape = view.bounds.width > view.bounds.height
        imageView.image = UIImage(named: isLandscape ? "splashHorizontal" : "splashVertical")
    }
    private func startVariantAwareRoutingIfNeeded() {
        guard !variantRoutingStarted else { return }
        variantRoutingStarted = true
        setSpinnerVisible(true)
        if InlineRoutingGate.isVariantB {
            beginInlineRouting()
            return
        }
        abConfigObserver = NotificationCenter.default.addObserver(
            forName: .abTestingConfigDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleVariantDecisionReady()
        }
        abConfigTimeoutTimer = Timer.scheduledTimer(withTimeInterval: variantDecisionTimeout, repeats: false) { [weak self] _ in
            self?.handleVariantDecisionReady()
        }
        if let abConfigTimeoutTimer {
            RunLoop.main.add(abConfigTimeoutTimer, forMode: .common)
        }
    }
    private func handleVariantDecisionReady() {
        teardownABObservers()
        guard !didFinishSplash else { return }
        if InlineRoutingGate.isEnabled {
            beginInlineRouting()
        } else {
            transitionToGame()
        }
    }
    private func beginInlineRouting() {
        InlineRoutingBootstrap.activateIfNeeded()
        if AppStartupSettings.resolvedMode != nil {
            completeRecurringSplashTransition()
        } else {
            startFirstLaunchPipelineIfNeeded()
        }
    }
    private func transitionToGame() {
        guard !didFinishSplash else { return }
        didFinishSplash = true
        setSpinnerVisible(false)
        guard let window = view.window else { return }
        AppLogger.track(AppLogger.Event.splashTransition, properties: ["route": "main_menu"])
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
            window.rootViewController = MainMenuFlowController.makeRootViewController()
        }
    }
    private func teardownABObservers() {
        abConfigTimeoutTimer?.invalidate()
        abConfigTimeoutTimer = nil
        if let abConfigObserver {
            NotificationCenter.default.removeObserver(abConfigObserver)
            self.abConfigObserver = nil
        }
    }
    private func completeRecurringSplashTransition() {
        guard !didFinishSplash else { return }
        didFinishSplash = true
        setSpinnerVisible(false)
        guard let window = view.window else { return }
        if window.rootViewController is PushPayloadSurfaceController {
            if AppStartupSettings.resolvedMode == .inlineSurface,
               RemoteConfigStore.shouldRefreshFromEndpoint {
                RemoteConfigFetchService.shared.requestConfigRefresh()
            }
            return
        }
        if PendingPushURLStore.hasPendingURL {
            PushNotificationRouting.flushPendingIfPossible()
            if !PendingPushURLStore.hasPendingURL {
                if AppStartupSettings.resolvedMode == .inlineSurface,
                   RemoteConfigStore.shouldRefreshFromEndpoint {
                    RemoteConfigFetchService.shared.requestConfigRefresh()
                }
                return
            }
        }
        ApplicationFlowResolver.transitionFromSplash(window: window)
    }
    private func startFirstLaunchPipelineIfNeeded() {
        guard !firstLaunchPipelineStarted else { return }
        firstLaunchPipelineStarted = true
        awaitingFirstLaunchRouting = true
        setSpinnerVisible(true)
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
        setSpinnerVisible(false)
        maxSplashTimer?.invalidate()
        maxSplashTimer = nil
        teardownFirstLaunchObservers()
        AppLogger.track(AppLogger.Event.splashTransition, properties: ["route": "bootstrap"])
        ApplicationFlowResolver.applyRoutingReadyIfNeeded(window: window)
    }
    private func showNoInternetRootFromSplash() {
        maxSplashTimer?.invalidate()
        maxSplashTimer = nil
        awaitingFirstLaunchRouting = false
        didFinishSplash = true
        setSpinnerVisible(false)
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
    private func startSpinnerRotation() {
        guard spinnerImageView.layer.animation(forKey: spinnerRotationKey) == nil else { return }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = spinnerRotationDuration
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        spinnerImageView.layer.add(rotation, forKey: spinnerRotationKey)
    }
    private func stopSpinnerRotation() {
        spinnerImageView.layer.removeAnimation(forKey: spinnerRotationKey)
    }
}
