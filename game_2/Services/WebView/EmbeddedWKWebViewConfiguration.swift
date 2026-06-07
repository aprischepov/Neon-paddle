import UIKit
import WebKit

/// Общие настройки встроенных WebView: JavaScript, постоянные cookie и данные сайта (localStorage, sessionStorage, IndexedDB — типичные носители «сессии» на стороне клиента).
enum EmbeddedWKWebViewConfiguration {

    /// Персистентное хранилище (`WKWebsiteDataStore.default()` — cookie, **MediaKeys** и др. данные сайта), JS для контента включён, вспомогательные окна из скрипта разрешены.
    ///
    /// **Inline autoplay:** `allowsInlineMediaPlayback` и пустой `mediaTypesRequiringUserActionForPlayback` — видео/аудио может стартовать без перехода в системный полноэкранный плеер и без обязательного тапа (в рамках политик WebKit и атрибутов страницы).
    ///
    /// **Protected media / EME:** в iOS у `WKWebView` нет публичного аналога Chrome «Protected Media Identifier»; доступ к зашифрованному контенту обрабатывает WebKit. Явное использование **дефолтного** `WKWebsiteDataStore` сохраняет ключи/состояние (`WKWebsiteDataTypeMediaKeys` и т.д.), как в обычном браузерном профиле.
    static func makeStandard() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        EmbeddedWebViewScrollPolicy.installViewportZoomLock(on: configuration)

        return configuration
    }
}

/// Обрабатывает `window.open` / навигации без `targetFrame`, иначе часть JS-флоу (логин, оплата) не открывается; загрузку файлов с сайта — через `runOpenPanel` (iOS 18.4+).
@MainActor
final class EmbeddedWebViewUIDelegate: NSObject, WKUIDelegate {
    private var fileUploadCoordinator: AnyObject?

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        if EmbeddedWebViewDeepLinkPolicy.tryHandleNonWebRequestExternally(navigationAction.request) {
            return nil
        }
        webView.load(navigationAction.request)
        return nil
    }

    @available(iOS 18.4, *)
    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor ([URL]?) -> Void
    ) {
        guard let host = webView.embeddedWebViewHostViewController() else {
            completionHandler(nil)
            return
        }
        let coordinator = EmbeddedWebViewFileUploadCoordinator(
            parameters: parameters,
            host: host,
            anchorView: webView,
            completion: { [weak self] urls in
                self?.fileUploadCoordinator = nil
                completionHandler(urls)
            }
        )
        fileUploadCoordinator = coordinator
        coordinator.begin()
    }
}
