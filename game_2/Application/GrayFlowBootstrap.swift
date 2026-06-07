import Foundation
enum GrayFlowBootstrap {
    private static var didActivate = false
    static func activateIfNeeded() {
        guard GrayFlowGate.isEnabled else { return }
        guard !didActivate else { return }
        didActivate = true
        AppLogger.debug("[GrayFlow] activating post-attribution coordinators", category: "GrayFlow")
        OfflineSurfaceCoordinator.start()
        AppStartupDecisionCoordinator.shared.start()
        RemoteConfigCoordinator.shared.start()
        FirebasePushTokenBridge.shared.configure()
        AppsFlyerUDLBridge.shared.attach()
    }
}
