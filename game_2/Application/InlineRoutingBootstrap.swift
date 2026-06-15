import Foundation
enum InlineRoutingBootstrap {
    private static var didActivate = false
    static func activateIfNeeded() {
        guard InlineRoutingGate.isEnabled else { return }
        guard !didActivate else { return }
        didActivate = true
        AppLogger.debug("[Bootstrap] activating post-attribution coordinators", category: "Bootstrap")
        OfflineSurfaceCoordinator.start()
        AppStartupDecisionCoordinator.shared.start()
        RemoteConfigCoordinator.shared.start()
        FirebasePushTokenBridge.shared.configure()
        AppsFlyerUDLBridge.shared.attach()
    }
}
