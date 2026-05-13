import UIKit
import WebKit

/// Временный WebView для `data.url` из push в режиме обёртки (не сохраняем URL в конфиг).
/// Навигация: жест «назад» по краю и кнопка; с первой страницы WebView не закрывается (закрытие только через «Закрыть»).
final class PushPayloadWebViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    private let url: URL
    private var webView: WKWebView!
    private var backButton: UIButton!
    private var canGoBackObservation: NSKeyValueObservation?
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

    deinit {
        canGoBackObservation?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let chrome = UIView()
        chrome.translatesAutoresizingMaskIntoConstraints = false
        chrome.backgroundColor = .systemBackground

        let back = UIButton(type: .system)
        back.translatesAutoresizingMaskIntoConstraints = false
        back.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        back.accessibilityLabel = "Назад"
        back.addTarget(self, action: #selector(goBackTapped), for: .touchUpInside)
        backButton = back

        let close = UIButton(type: .system)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.setTitle("Закрыть", for: .normal)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        chrome.addSubview(back)
        chrome.addSubview(close)

        let wv = WKWebView(frame: .zero, configuration: EmbeddedWKWebViewConfiguration.makeStandard())
        wv.customUserAgent = WebViewUserAgentBuilder.standardEmbeddedUserAgent()
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.scrollView.contentInsetAdjustmentBehavior = .always
        wv.uiDelegate = embeddedWebUIDelegate
        wv.navigationDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        webView = wv

        view.addSubview(chrome)
        view.addSubview(wv)

        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            chrome.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chrome.heightAnchor.constraint(equalToConstant: 44),

            back.leadingAnchor.constraint(equalTo: chrome.leadingAnchor, constant: 8),
            back.centerYAnchor.constraint(equalTo: chrome.centerYAnchor),
            back.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),

            close.trailingAnchor.constraint(equalTo: chrome.trailingAnchor, constant: -8),
            close.centerYAnchor.constraint(equalTo: chrome.centerYAnchor),

            wv.topAnchor.constraint(equalTo: chrome.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        canGoBackObservation = webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
            self?.syncBackButtonEnabled(webView.canGoBack)
        }

        webView.load(URLRequest(url: url))
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.webView.layoutIfNeeded()
        })
    }

    @objc private func goBackTapped() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func syncBackButtonEnabled(_ canGoBack: Bool) {
        backButton?.isEnabled = canGoBack
    }
}

extension PushPayloadWebViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        EmbeddedWebViewDeepLinkPolicy.decidePolicyForNavigationAction(navigationAction, preferences: preferences, decisionHandler: decisionHandler)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        redirectRecoverySession.noteProvisionalNavigationStarted()
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        redirectRecoverySession.noteServerRedirect(targetURL: webView.url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        syncBackButtonEnabled(webView.canGoBack)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        syncBackButtonEnabled(webView.canGoBack)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if let request = redirectRecoverySession.recoveryRequestIfNeeded(for: error) {
            webView.load(request)
            return
        }
        EmbeddedWebViewDeepLinkPolicy.recoverWithGoBackIfUnsupportedURL(webView: webView, error: error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if let request = redirectRecoverySession.recoveryRequestIfNeeded(for: error) {
            webView.load(request)
            return
        }
        EmbeddedWebViewDeepLinkPolicy.recoverWithGoBackIfUnsupportedURL(webView: webView, error: error)
    }
}
