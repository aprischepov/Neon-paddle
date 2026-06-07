import UIKit
import WebKit
enum EmbeddedSurfaceConfiguration {
    static func makeStandard() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        EmbeddedScrollPolicy.installViewportZoomLock(on: configuration)
        return configuration
    }
}
@MainActor
final class EmbeddedSurfaceUIDelegate: NSObject, WKUIDelegate {
    private var fileUploadCoordinator: AnyObject?
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        if EmbeddedDeepLinkPolicy.tryHandleExternalRequestOutside(navigationAction.request) {
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
        guard let host = webView.embeddedSurfaceHostViewController() else {
            completionHandler(nil)
            return
        }
        let coordinator = EmbeddedFileUploadCoordinator(
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
