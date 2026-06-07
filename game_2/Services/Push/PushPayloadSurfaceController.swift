import UIKit
import WebKit
final class PushPayloadSurfaceController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }
    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }
    let url: URL
    private var surfaceView: WKWebView!
    private let redirectRecoverySession = RedirectLoopRecovery.Session()
    private let embeddedSurfaceUIDelegate = EmbeddedSurfaceUIDelegate()
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
        let wv = WKWebView(frame: .zero, configuration: EmbeddedSurfaceConfiguration.makeStandard())
        wv.customUserAgent = EmbeddedClientAgentBuilder.standardEmbeddedUserAgent()
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.backgroundColor = .black
        wv.scrollView.backgroundColor = .black
        wv.uiDelegate = embeddedSurfaceUIDelegate
        wv.navigationDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        EmbeddedScrollPolicy.apply(to: wv)
        surfaceView = wv
        view.addSubview(wv)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: safe.topAnchor),
            wv.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
        ])
        surfaceView.load(URLRequest(url: url))
    }
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.surfaceView.layoutIfNeeded()
        })
    }
}
extension PushPayloadSurfaceController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        if let u = EmbeddedDeepLinkPolicy.mainFrameRequestURLIfLoadingInline(navigationAction) {
            redirectRecoverySession.noteMainFrameProvisionalURL(u)
        }
        EmbeddedDeepLinkPolicy.decidePolicyForNavigationAction(navigationAction, preferences: preferences, decisionHandler: decisionHandler)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        redirectRecoverySession.noteProvisionalNavigationStarted()
    }
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        redirectRecoverySession.noteServerRedirect(targetURL: webView.url)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            if await RedirectLoopRecovery.handleTooManyRedirectsRecoveryIfNeeded(
                surfaceView: webView,
                error: error,
                session: redirectRecoverySession,
                fallbackURL: url
            ) { return }
            EmbeddedDeepLinkPolicy.recoverWithGoBackIfUnsupportedURL(surfaceView: webView, error: error)
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            if await RedirectLoopRecovery.handleTooManyRedirectsRecoveryIfNeeded(
                surfaceView: webView,
                error: error,
                session: redirectRecoverySession,
                fallbackURL: url
            ) { return }
            EmbeddedDeepLinkPolicy.recoverWithGoBackIfUnsupportedURL(surfaceView: webView, error: error)
        }
    }
}
