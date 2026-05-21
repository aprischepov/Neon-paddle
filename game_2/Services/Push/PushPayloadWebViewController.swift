import UIKit
import WebKit

/// Root WebView для one-time `data.url` из push. Не связан с config/pre-prompt flow и не сохраняет URL.
final class PushPayloadWebViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    private let url: URL
    private var webView: WKWebView!
    private let redirectRecoverySession = WKWebViewRedirectLoopRecovery.Session()
    private let embeddedWebUIDelegate = EmbeddedWebViewUIDelegate()

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let wv = WKWebView(frame: .zero, configuration: EmbeddedWKWebViewConfiguration.makeStandard())
        wv.customUserAgent = WebViewUserAgentBuilder.standardEmbeddedUserAgent()
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.isOpaque = false
        wv.backgroundColor = .black
        wv.scrollView.backgroundColor = .black
        wv.uiDelegate = embeddedWebUIDelegate
        wv.navigationDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        EmbeddedWebViewScrollPolicy.apply(to: wv)
        webView = wv

        view.addSubview(wv)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: safe.topAnchor),
            wv.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
        ])

        webView.load(URLRequest(url: url))
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.webView.layoutIfNeeded()
        })
    }

}

extension PushPayloadWebViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        if let u = EmbeddedWebViewDeepLinkPolicy.mainFrameWebRequestURLIfLoadingInWebView(navigationAction) {
            redirectRecoverySession.noteMainFrameProvisionalURL(u)
        }
        EmbeddedWebViewDeepLinkPolicy.decidePolicyForNavigationAction(navigationAction, preferences: preferences, decisionHandler: decisionHandler)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        redirectRecoverySession.noteProvisionalNavigationStarted()
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        redirectRecoverySession.noteServerRedirect(targetURL: webView.url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            if await WKWebViewRedirectLoopRecovery.handleTooManyRedirectsRecoveryIfNeeded(
                webView: webView,
                error: error,
                session: redirectRecoverySession,
                fallbackURL: url
            ) { return }
            EmbeddedWebViewDeepLinkPolicy.recoverWithGoBackIfUnsupportedURL(webView: webView, error: error)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            if await WKWebViewRedirectLoopRecovery.handleTooManyRedirectsRecoveryIfNeeded(
                webView: webView,
                error: error,
                session: redirectRecoverySession,
                fallbackURL: url
            ) { return }
            EmbeddedWebViewDeepLinkPolicy.recoverWithGoBackIfUnsupportedURL(webView: webView, error: error)
        }
    }
}
