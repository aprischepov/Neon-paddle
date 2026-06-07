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
    private lazy var webView = WKWebView(frame: .zero)
    private let activityIndicator = UIActivityIndicatorView(style: .large)
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
        AppLogger.track(AppLogger.Event.policyPageOpened, properties: [
            "title": pageTitle,
            "url": pageURL.absoluteString
        ])
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
        AppLogger.track(AppLogger.Event.policyPageClosed, properties: [
            "title": pageTitle,
            "url": pageURL.absoluteString
        ])
        dismiss(animated: true)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
        AppLogger.debug("Policy page loaded: \(pageTitle)")
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        logPolicyLoadFailure(error)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        logPolicyLoadFailure(error)
    }
    private func logPolicyLoadFailure(_ error: Error) {
        AppLogger.track(AppLogger.Event.policyPageLoadFailed, properties: [
            "title": pageTitle,
            "url": pageURL.absoluteString,
            "error": error.localizedDescription
        ])
    }
}
enum InlineFramePresenter {
    static func makeSurface(
        url: URL,
        deferRemoteSync: Bool = false,
        oneTimeDeepLink: Bool = false
    ) -> UIViewController {
        AuxiliarySurfaceHost(
            url: url,
            deferRemoteSync: deferRemoteSync,
            oneTimeDeepLink: oneTimeDeepLink
        )
    }
    static func isActiveSurface(_ controller: UIViewController?) -> Bool {
        controller is AuxiliarySurfaceHost
    }
}
private final class AuxiliarySurfaceHost: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }
    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }
    private var loadedURLString: String
    private var surfaceView: WKWebView!
    private var configObserver: NSObjectProtocol?
    private var configFailureObserver: NSObjectProtocol?
    private var didRunEntrySequence = false
    private var didPerformContentLoad = false
    private let deferRemoteSync: Bool
    private let oneTimeDeepLink: Bool
    private var isDisplayingOneTimeDeepLink = false
    private let redirectRecoverySession = RedirectLoopRecovery.Session()
    private let embeddedSurfaceUIDelegate = EmbeddedSurfaceUIDelegate()
    init(url: URL, deferRemoteSync: Bool = false, oneTimeDeepLink: Bool = false) {
        loadedURLString = url.absoluteString
        self.deferRemoteSync = deferRemoteSync
        self.oneTimeDeepLink = oneTimeDeepLink
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
        let config = EmbeddedSurfaceConfiguration.makeStandard()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = EmbeddedClientAgentBuilder.standardEmbeddedUserAgent()
        wv.uiDelegate = embeddedSurfaceUIDelegate
        wv.navigationDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.backgroundColor = .black
        wv.scrollView.backgroundColor = .black
        EmbeddedScrollPolicy.apply(to: wv)
        root.addSubview(wv)
        let safe = root.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: safe.topAnchor),
            wv.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
        ])
        surfaceView = wv
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
        if deferRemoteSync {
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
            self?.surfaceView.layoutIfNeeded()
        })
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRunEntrySequence else { return }
        didRunEntrySequence = true
        if oneTimeDeepLink {
            performInitialContentLoad()
            return
        }
        PushNotificationPrePromptCoordinator.runIfNeededBeforeSurfaceContent(from: self) { [weak self] in
            self?.performInitialContentLoad()
        }
    }
    private func performInitialContentLoad() {
        if oneTimeDeepLink, let url = URL(string: loadedURLString) {
            loadOneTimeDeepLink(url)
            return
        }
        if deferRemoteSync { return }
        loadURLString(loadedURLString)
    }
    private func loadURLString(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        loadedURLString = url.absoluteString
        didPerformContentLoad = true
        surfaceView.load(URLRequest(url: url))
    }
    private func finishDeferredLoadUsingSavedURL() {
        guard deferRemoteSync, !didPerformContentLoad else { return }
        guard !isDisplayingOneTimeDeepLink else { return }
        let fallback = RemoteConfigStore.savedURLString ?? loadedURLString
        loadURLString(fallback)
    }
    private func loadOneTimeDeepLink(_ url: URL) {
        loadViewIfNeeded()
        loadedURLString = url.absoluteString
        isDisplayingOneTimeDeepLink = true
        didPerformContentLoad = true
        surfaceView.load(URLRequest(url: url))
    }
    private func reloadFromStoreIfURLChanged() {
        guard AppStartupSettings.resolvedMode == .inlineSurface else { return }
        guard !isDisplayingOneTimeDeepLink else { return }
        guard let next = RemoteConfigStore.savedURLString, !next.isEmpty else { return }
        if didPerformContentLoad, next == loadedURLString { return }
        loadURLString(next)
    }
}
extension AuxiliarySurfaceHost: WKNavigationDelegate {
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
        let fallback = URL(string: loadedURLString)
        Task { @MainActor in
            if await RedirectLoopRecovery.handleTooManyRedirectsRecoveryIfNeeded(
                surfaceView: webView,
                error: error,
                session: redirectRecoverySession,
                fallbackURL: fallback
            ) { return }
            EmbeddedDeepLinkPolicy.recoverWithGoBackIfUnsupportedURL(surfaceView: webView, error: error)
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let fallback = URL(string: loadedURLString)
        Task { @MainActor in
            if await RedirectLoopRecovery.handleTooManyRedirectsRecoveryIfNeeded(
                surfaceView: webView,
                error: error,
                session: redirectRecoverySession,
                fallbackURL: fallback
            ) { return }
            EmbeddedDeepLinkPolicy.recoverWithGoBackIfUnsupportedURL(surfaceView: webView, error: error)
        }
    }
}
