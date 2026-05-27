import Foundation
import FirebaseRemoteConfig

final class ABTestingService {
    static let shared = ABTestingService()

    enum Key: String {
        case appVariant = "SplashScreenTest"
        case scoreLimitVariant   = "score_limit_variant"
        case powerUpsEnabled     = "power_ups_enabled"
        case ballSpeedMultiplier = "ball_speed_multiplier"

        case showLeaderboardOnStart = "show_leaderboard_on_start"
    }

    private let defaultValues: [String: NSObject] = [
        Key.appVariant.rawValue:           "A" as NSString,
        Key.scoreLimitVariant.rawValue:    NSNumber(value: 7),
        Key.powerUpsEnabled.rawValue:      NSNumber(value: false),
        Key.ballSpeedMultiplier.rawValue:  NSNumber(value: 1.0),
        Key.showLeaderboardOnStart.rawValue: NSNumber(value: false),
    ]

    private let remoteConfig: RemoteConfig
    private var isFetching = false

    private init() {
        remoteConfig = RemoteConfig.remoteConfig()

        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(defaultValues)
    }

    // MARK: - Fetch
    func fetch(completion: ((Error?) -> Void)? = nil) {
        guard !isFetching else {
            AppLogger.debug("[RemoteConfig] fetch skipped — already in progress", category: "ABTesting")
            return
        }
        isFetching = true
        AppLogger.debug("[RemoteConfig] fetchAndActivate started...", category: "ABTesting")

        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard let self else { return }
            self.isFetching = false

            if let error {
                AppLogger.warning("[RemoteConfig] fetch FAILED", properties: [
                    "error": error.localizedDescription
                ])
                completion?(error)
                return
            }

            let statusName: String
            switch status {
            case .successFetchedFromRemote:   statusName = "fetched_from_remote"
            case .successUsingPreFetchedData: statusName = "pre_fetched"
            case .error:                      statusName = "error"
            @unknown default:                 statusName = "unknown"
            }

            let variant = self.string(for: .appVariant) ?? "nil"
            AppLogger.debug(
                "[RemoteConfig] fetch SUCCESS — status=\(statusName)  SplashScreenTest=\(variant)",
                category: "ABTesting"
            )
            AppLogger.debug(
                "[RemoteConfig] → AppsFlyer attribution will \(variant.uppercased() == "B" ? "RUN ✅" : "be SKIPPED ⛔️") (variant=\(variant))",
                category: "ABTesting"
            )
            AppLogger.track("ab_config_fetched", properties: [
                "status": statusName,
                "SplashScreenTest": variant
            ])
            NotificationCenter.default.post(name: .abTestingConfigDidUpdate, object: nil)
            completion?(nil)
        }
    }

    // MARK: - Typed accessors

    func bool(for key: Key) -> Bool {
        remoteConfig[key.rawValue].boolValue
    }

    func int(for key: Key) -> Int {
        Int(remoteConfig[key.rawValue].numberValue.intValue)
    }

    func double(for key: Key) -> Double {
        remoteConfig[key.rawValue].numberValue.doubleValue
    }

    func string(for key: Key) -> String? {
        let value = remoteConfig[key.rawValue].stringValue
        return value.isEmpty == false ? value : nil
    }
}

extension Notification.Name {
    static let abTestingConfigDidUpdate = Notification.Name("abTestingConfigDidUpdate")
}
