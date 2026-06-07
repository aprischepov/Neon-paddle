import AppTrackingTransparency
import UIKit

enum AnalyticsServices {

    static func configureAtLaunch(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        _ = launchOptions
        FirebaseCrashlyticsService.configure()
        AmplitudeAnalyticsService.shared.start()
        AppsFlyerAttributionService.shared.configure()
        ABTestingService.shared.fetch { _ in
            GrayFlowBootstrap.activateIfNeeded()
        }
        if GrayFlowGate.hasPersistedGrayMode {
            GrayFlowBootstrap.activateIfNeeded()
        }
        AppLogger.debug("Analytics SDKs configured")
    }

    static func applicationDidBecomeActive() {
        AppTrackingService.requestAuthorizationThen {
            logATTStatusIfAvailable()
            AppsFlyerAttributionService.shared.startSession()
        }
    }

    private static func logATTStatusIfAvailable() {
        guard #available(iOS 14, *) else { return }
        let status = ATTrackingManager.trackingAuthorizationStatus
        let statusName: String
        switch status {
        case .authorized: statusName = "authorized"
        case .denied: statusName = "denied"
        case .restricted: statusName = "restricted"
        case .notDetermined: statusName = "not_determined"
        @unknown default: statusName = "unknown"
        }
        AppLogger.track(AppLogger.Event.attStatus, properties: ["status": statusName])
    }
}
