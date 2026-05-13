import Foundation

enum AppConstants {
    enum Legal {
        static let privacyPolicyURL = URL(string: "https://sites.google.com/view/glowbounceapp/support/privacy")!
        static let termsOfUseURL = URL(string: "https://sites.google.com/view/glowbounceapp/support/terms")!
    }

    /// Сервер конфигурации (после готовности conversion payload + клиентские поля).
    enum RemoteConfig {
        static let endpointURL = URL(string: "https://glowbouncearcade.com/config.php")!
    }

    /// User-Agent для встроенных `WKWebView` (без маркеров in-app WebView).
    enum WebBrowsing {
        /// Числовой Apple ID в App Store для сегмента `appid/…`; при необходимости задайте в Info `AppStoreAppleAppID`.
        static let appStoreNumericId = "6767186390"
    }
}
