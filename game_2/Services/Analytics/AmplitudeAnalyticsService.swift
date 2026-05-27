import Foundation
import AmplitudeSwift

final class AmplitudeAnalyticsService {
    static let shared = AmplitudeAnalyticsService()

    private var amplitude: Amplitude?

    private init() {}

    func start() {
        let key = ThirdPartyKeys.amplitudeAPIKey
        guard !key.isEmpty else {
            AppLogger.debug("Amplitude skipped: empty amplitudeAPIKey in ThirdPartyKeys", category: "Amplitude")
            return
        }
        let configuration = Configuration(apiKey: key)
        amplitude = Amplitude(configuration: configuration)
        AppLogger.debug("Amplitude SDK started", category: "Amplitude")
    }

    func track(event name: String, properties: [String: Any]? = nil) {
        guard let amplitude else { return }
        if let properties {
            amplitude.track(eventType: name, eventProperties: properties)
        } else {
            amplitude.track(eventType: name)
        }
    }

    func setUserId(_ userId: String?) {
        amplitude?.setUserId(userId: userId)
    }
}
