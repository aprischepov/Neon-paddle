import SwiftUI
import UIKit
final class NoInternetViewController: UIViewController, NoInternetScreenHost {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }
    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }
    private let reason: NoInternetPresentationReason
    private let screenModel: NoInternetScreenModel
    private let hostingController: UIHostingController<NoInternetView>
    init(reason: NoInternetPresentationReason) {
        self.reason = reason
        let model = NoInternetScreenModel(reason: reason)
        self.screenModel = model
        self.hostingController = UIHostingController(rootView: NoInternetView(model: model))
        super.init(nibName: nil, bundle: nil)
        model.host = self
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController.didMove(toParent: self)
    }
    func noInternetScreenDidAppear() {
        switch reason {
        case .firstLaunchConfigPending:
            goToResolvedIfNeededAfterFirstLaunchRouting()
        case .recurringSurfaceOffline:
            tryOpenSurfaceAfterRecurringOfflineIfPossible()
        }
    }
    func noInternetRetryTapped() {
        guard ConnectivityMonitor.shared.isOnline else { return }
        guard let window = view.window else { return }
        switch reason {
        case .firstLaunchConfigPending:
            if let splash = ApplicationFlowResolver.makeSplashRootFromStoryboard() {
                window.rootViewController = splash
            }
            RemoteConfigFetchService.shared.requestConfigRefresh()
        case .recurringSurfaceOffline:
            tryOpenSurfaceAfterRecurringOfflineIfPossible(forceEndpointRefresh: true)
        }
    }
    func noInternetRoutingReadyNotification() {
        goToResolvedIfNeededAfterFirstLaunchRouting()
    }
    func noInternetConnectivityChanged() {
        if reason == .recurringSurfaceOffline {
            tryOpenSurfaceAfterRecurringOfflineIfPossible()
        }
    }
    private func goToResolvedIfNeededAfterFirstLaunchRouting() {
        guard reason == .firstLaunchConfigPending else { return }
        guard AppStartupSettings.resolvedMode != nil else { return }
        guard let window = view.window else { return }
        ApplicationFlowResolver.applyRoutingReadyIfNeeded(window: window)
    }
    private func tryOpenSurfaceAfterRecurringOfflineIfPossible(forceEndpointRefresh: Bool = false) {
        guard reason == .recurringSurfaceOffline else { return }
        guard AppStartupSettings.resolvedMode == .inlineSurface else { return }
        guard ConnectivityMonitor.shared.isOnline else { return }
        guard let window = view.window else { return }
        ApplicationFlowResolver.installSurfaceRoot(in: window)
        if forceEndpointRefresh || RemoteConfigStore.shouldRefreshFromEndpoint {
            RemoteConfigFetchService.shared.requestConfigRefresh()
        }
    }
}
