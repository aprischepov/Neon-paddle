import Foundation

/// После обновления conversion / UDL / FCM — повторный запрос конфига с актуальным телом.
final class RemoteConfigCoordinator {
    static let shared = RemoteConfigCoordinator()

    private var conversionObserver: NSObjectProtocol?

    private init() {}

    func start() {
        guard conversionObserver == nil else { return }
        conversionObserver = NotificationCenter.default.addObserver(
            forName: .appsFlyerConversionDataDidUpdate,
            object: nil,
            queue: .main
        ) { note in
            let payload = note.userInfo?[AppsFlyerAttributionService.conversionPayloadUserInfoKey] as? [String: Any]
                ?? AppsFlyerAttributionService.shared.currentConversionPayload()
            RemoteConfigFetchService.shared.performFetch(conversionPayload: payload)
        }
    }

    func notifyConfigContextUpdated() {
        RemoteConfigFetchService.shared.requestConfigRefresh()
    }
}
