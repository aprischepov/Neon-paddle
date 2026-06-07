import Foundation
import FirebaseCore
import FirebaseCrashlytics
enum FirebaseCrashlyticsService {
    private static var didConfigure = false
    static func configure() {
        guard !didConfigure else { return }
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            return
        }
        FirebaseApp.configure()
        didConfigure = true
    }
    static func recordNonFatalError(_ error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }
    static func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }
    static func setUserId(_ id: String?) {
        Crashlytics.crashlytics().setUserID(id)
    }
}
