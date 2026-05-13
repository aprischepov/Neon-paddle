import UIKit
import WebKit

/// Полноэкранный WebView для сохранённого URL конфига (режим WebView). П. 2.1: при новом успешном ответе эндпоинта подгружает обновлённый `url`; при ошибке сети страница остаётся на последней загруженной.
/// Загрузка контента откладывается до кастомного push-пре-промпта (если он показывается), чтобы не блокировать старт WebView при сбоях FCM.
/// Навигация: системный жест «назад» по краю (`allowsBackForwardNavigationGestures`) и кнопка; с первой страницы истории WebView не закрывается.
final class ConfigWebViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    private var loadedURLString: String
    private var webView: WKWebView!
    private var backButton: UIButton!
    private var canGoBackObservation: NSKeyValueObservation?
    private var configObserver: NSObjectProtocol?
    private var didRunWebViewEntrySequence = false
    private let redirectRecoverySession = WKWebViewRedirectLoopRecovery.Session()
    private let embeddedWebUIDelegate = EmbeddedWebViewUIDelegate()

    init(url: URL) {
        self.loadedURLString = url.absoluteString
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        canGoBackObservation?.invalidate()
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
        }
    }

    override func loadView() {
        let root = UIView()
        root.backgroundColor = .black

        let chrome = UIView()
        chrome.translatesAutoresizingMaskIntoConstraints = false
        chrome.backgroundColor = .black

        let back = UIButton(type: .system)
        back.translatesAutoresizingMaskIntoConstraints = false
        back.tintColor = .white
        back.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        back.accessibilityLabel = "Назад"
        back.addTarget(self, action: #selector(goBackTapped), for: .touchUpInside)
        backButton = back
        chrome.addSubview(back)

        let config = EmbeddedWKWebViewConfiguration.makeStandard()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = WebViewUserAgentBuilder.standardEmbeddedUserAgent()
        wv.uiDelegate = embeddedWebUIDelegate
        wv.navigationDelegate = self
        wv.scrollView.contentInsetAdjustmentBehavior = .always
        wv.allowsBackForwardNavigationGestures = true
        wv.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(chrome)
        root.addSubview(wv)

        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor),
            chrome.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            chrome.heightAnchor.constraint(equalToConstant: 44),

            back.leadingAnchor.constraint(equalTo: chrome.leadingAnchor, constant: 4),
            back.centerYAnchor.constraint(equalTo: chrome.centerYAnchor),
            back.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            back.heightAnchor.constraint(equalTo: chrome.heightAnchor),

            wv.topAnchor.constraint(equalTo: chrome.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: root.safeAreaLayoutGuide.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: root.safeAreaLayoutGuide.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: root.safeAreaLayoutGuide.bottomAnchor),
        ])

        webView = wv
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        canGoBackObservation = webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
            self?.syncBackButtonEnabled(webView.canGoBack)
        }

        configObserver = NotificationCenter.default.addObserver(
            forName: .remoteConfigDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadFromStoreIfURLChanged()
        }
    }

    @objc private func goBackTapped() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    private func syncBackButtonEnabled(_ canGoBack: Bool) {
        backButton?.isEnabled = canGoBack
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.webView.layoutIfNeeded()
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if didRunWebViewEntrySequence {
            applyPendingPushURLIfNeeded()
            return
        }
        didRunWebViewEntrySequence = true
        PushNotificationPrePromptCoordinator.runIfNeededBeforeWebContent(from: self) { [weak self] in
            self?.performInitialContentLoad()
            self?.applyPendingPushURLIfNeeded()
        }
    }

    private func performInitialContentLoad() {
        if let pending = PendingPushURLStore.consumePending(), let url = URL(string: pending) {
            loadPushOpenedURL(url)
            return
        }
        guard let url = URL(string: loadedURLString) else { return }
        webView.load(URLRequest(url: url))
    }

    /// Одноразовая загрузка ссылки из push (`data.url`). Не записывает URL в `RemoteConfigStore`.
    func loadPushOpenedURL(_ url: URL) {
        loadedURLString = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    private func applyPendingPushURLIfNeeded() {
        guard let pending = PendingPushURLStore.consumePending(), let url = URL(string: pending) else { return }
        loadPushOpenedURL(url)
    }

    private func reloadFromStoreIfURLChanged() {
        guard AppStartupSettings.resolvedMode == .webView else { return }
        guard let next = RemoteConfigStore.savedURLString, !next.isEmpty, next != loadedURLString else { return }
        guard let url = URL(string: next) else { return }
        loadedURLString = next
        webView.load(URLRequest(url: url))
    }
}

extension ConfigWebViewController: WKNavigationDelegate {
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
