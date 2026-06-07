import AppTrackingTransparency
enum AppTrackingService {
    static func requestAuthorizationThen(completion: @escaping () -> Void) {
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async(execute: completion)
        }
    }
}
