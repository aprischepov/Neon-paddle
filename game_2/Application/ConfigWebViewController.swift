import UIKit
import WebKit

/// Полноэкранный WebView для сохранённого URL конфига (режим WebView). П. 2.1: при новом успешном ответе эндпоинта подгружает обновлённый `url`; при ошибке сети страница остаётся на последней загруженной.
/// Загрузка контента откладывается до кастомного push-пре-промпта (если он показывается), чтобы не блокировать старт WebView при сбоях FCM.
/// Навигация назад — только системный жест по краю; с первой страницы истории WebView не закрывается.
final class ConfigWebViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    private var loadedURLString: String
    private var webView: WKWebView!
    private var configObserver: NSObjectProtocol?
    private var configFailureObserver: NSObjectProtocol?
    private var didRunWebViewEntrySequence = false
    private var didPerformContentLoad = false
    /// П. 2.1: при истёкшем `expires` не показывать кэшированный URL до ответа `config.php`.
    private let deferContentLoadUntilConfigRefresh: Bool
    /// После tap по push не подменять WebView URL ответом `config.php` до следующего запуска VC.
    private var isDisplayingOneTimePushURL = false
    private let redirectRecoverySession = WKWebViewRedirectLoopRecovery.Session()
    private let embeddedWebUIDelegate = EmbeddedWebViewUIDelegate()

    init(url: URL, deferContentLoadUntilConfigRefresh: Bool = false) {
        self.loadedURLString = url.absoluteString
        self.deferContentLoadUntilConfigRefresh = deferContentLoadUntilConfigRefresh
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
        }
        if let configFailureObserver {
            NotificationCenter.default.removeObserver(configFailureObserver)
        }
    }

    override func loadView() {
        let root = UIView()
        root.backgroundColor = .black

        let config = EmbeddedWKWebViewConfiguration.makeStandard()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = WebViewUserAgentBuilder.standardEmbeddedUserAgent()
        wv.uiDelegate = embeddedWebUIDelegate
        wv.navigationDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.backgroundColor = .black
        wv.scrollView.backgroundColor = .black
        EmbeddedWebViewScrollPolicy.apply(to: wv)

        root.addSubview(wv)

        let safe = root.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: safe.topAnchor),
            wv.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
        ])

        webView = wv
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        configObserver = NotificationCenter.default.addObserver(
            forName: .remoteConfigDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadFromStoreIfURLChanged()
        }

        if deferContentLoadUntilConfigRefresh {
            configFailureObserver = NotificationCenter.default.addObserver(
                forName: .remoteConfigDidFail,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.finishDeferredLoadUsingSavedURL()
            }
        }
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
        if deferContentLoadUntilConfigRefresh {
            return
        }
        loadURLString(loadedURLString)
    }

    private func loadURLString(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        loadedURLString = url.absoluteString
        didPerformContentLoad = true
        webView.load(URLRequest(url: url))
    }

    /// После неуспешного refresh конфига — последний сохранённый URL (п. 2.1 fallback).
    private func finishDeferredLoadUsingSavedURL() {
        guard deferContentLoadUntilConfigRefresh, !didPerformContentLoad else { return }
        let fallback = RemoteConfigStore.savedURLString ?? loadedURLString
        loadURLString(fallback)
    }

    /// Одноразовая загрузка ссылки из push (`data.url`). Не записывает URL в `RemoteConfigStore`.
    func loadPushOpenedURL(_ url: URL) {
        loadedURLString = url.absoluteString
        isDisplayingOneTimePushURL = true
        webView.load(URLRequest(url: url))
    }

    private func applyPendingPushURLIfNeeded() {
        guard let pending = PendingPushURLStore.consumePending(), let url = URL(string: pending) else { return }
        loadPushOpenedURL(url)
    }

    private func reloadFromStoreIfURLChanged() {
        guard AppStartupSettings.resolvedMode == .webView else { return }
        guard !isDisplayingOneTimePushURL else { return }
        guard let next = RemoteConfigStore.savedURLString, !next.isEmpty else { return }
        if didPerformContentLoad, next == loadedURLString { return }
        loadURLString(next)
    }
}

extension ConfigWebViewController: WKNavigationDelegate {
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

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let fallback = URL(string: loadedURLString)
        Task { @MainActor in
            if await WKWebViewRedirectLoopRecovery.handleTooManyRedirectsRecoveryIfNeeded(
                webView: webView,
                error: error,
                session: redirectRecoverySession,
                fallbackURL: fallback
            ) { return }
            EmbeddedWebViewDeepLinkPolicy.recoverWithGoBackIfUnsupportedURL(webView: webView, error: error)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let fallback = URL(string: loadedURLString)
        Task { @MainActor in
            if await WKWebViewRedirectLoopRecovery.handleTooManyRedirectsRecoveryIfNeeded(
                webView: webView,
                error: error,
                session: redirectRecoverySession,
                fallbackURL: fallback
            ) { return }
            EmbeddedWebViewDeepLinkPolicy.recoverWithGoBackIfUnsupportedURL(webView: webView, error: error)
        }
    }
}
