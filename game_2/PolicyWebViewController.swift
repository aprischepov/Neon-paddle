import UIKit
import WebKit

final class PolicyWebViewController: UIViewController, WKNavigationDelegate {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    private let pageURL: URL
    private let pageTitle: String
    private lazy var webView: WKWebView = WKWebView(
        frame: .zero,
        configuration: EmbeddedWKWebViewConfiguration.makeStandard()
    )
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let redirectRecoverySession = WKWebViewRedirectLoopRecovery.Session()
    private let embeddedWebUIDelegate = EmbeddedWebViewUIDelegate()

    init(title: String, url: URL) {
        pageTitle = title
        pageURL = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = pageTitle
        view.backgroundColor = .systemBackground
        configureNavigationBar()
        configureWebView()
        configureActivityIndicator()
        webView.load(URLRequest(url: pageURL))
    }

    private func configureNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(close)
        )
    }

    private func configureWebView() {
        webView.navigationDelegate = self
        webView.uiDelegate = embeddedWebUIDelegate
        webView.customUserAgent = WebViewUserAgentBuilder.standardEmbeddedUserAgent()
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func configureActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        activityIndicator.startAnimating()
    }

    @objc private func close() {
        dismiss(animated: true)
    }

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
        activityIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            if await WKWebViewRedirectLoopRecovery.handleTooManyRedirectsRecoveryIfNeeded(
                webView: webView,
                error: error,
                session: redirectRecoverySession,
                fallbackURL: pageURL
            ) {
                activityIndicator.stopAnimating()
                return
            }
            EmbeddedWebViewDeepLinkPolicy.recoverWithGoBackIfUnsupportedURL(webView: webView, error: error)
            activityIndicator.stopAnimating()
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            if await WKWebViewRedirectLoopRecovery.handleTooManyRedirectsRecoveryIfNeeded(
                webView: webView,
                error: error,
                session: redirectRecoverySession,
                fallbackURL: pageURL
            ) {
                activityIndicator.stopAnimating()
                return
            }
            EmbeddedWebViewDeepLinkPolicy.recoverWithGoBackIfUnsupportedURL(webView: webView, error: error)
            activityIndicator.stopAnimating()
        }
    }
}
