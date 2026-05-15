import Foundation

/// Первый запуск: не отправлять `config.php` и не фиксировать wrapper, пока нет conversion (и при Organic — повтор через 5 с) или не истёк таймаут сплеша.
final class FirstLaunchConfigGate {
    static let shared = FirstLaunchConfigGate()

    private(set) var isReadyForConfigRequest = false

    private var awaitingDeferredOrganicRetry = false
    private var splashDeadline: Date?
    private var splashTimeoutWorkItem: DispatchWorkItem?

    /// Резерв под HTTP `config.php` внутри общего лимита сплеша (10 с по ТЗ).
    private let configHTTPReserve: TimeInterval = 2.5
    private var conversionObserver: NSObjectProtocol?
    private var udlObserver: NSObjectProtocol?
    private var deferredOrganicObserver: NSObjectProtocol?
    private var pendingConfigRefresh = false

    private init() {}

    /// Вызывается со сплеша: весь первый запуск (AF + config) укладывается в `maxDuration` (10 с по ТЗ).
    func beginWaitingForAttribution(maxDuration: TimeInterval) {
        guard AppStartupSettings.resolvedMode == nil else { return }
        guard !isReadyForConfigRequest else { return }

        installObserversIfNeeded()
        splashDeadline = Date().addingTimeInterval(maxDuration)
        scheduleSplashDeadlineFallback()

        if AppsFlyerAttributionService.shared.currentConversionPayload() != nil {
            handleConversionPayloadAvailable()
        }
    }

    /// Сплеш истёк — отправить config с тем, что есть, или завершить пайплайн снаружи.
    func forceReadyForSplashDeadline() {
        awaitingDeferredOrganicRetry = false
        markReady(reason: .splashTimeout)
    }

    func cancelSplashTimeout() {
        splashTimeoutWorkItem?.cancel()
        splashTimeoutWorkItem = nil
    }

    /// `RemoteConfigFetchService` / координатор: отложить запрос до готовности attribution.
    func performConfigFetchWhenReady(_ action: @escaping () -> Void) {
        if AppStartupSettings.resolvedMode != nil || isReadyForConfigRequest {
            action()
            return
        }
        pendingConfigRefresh = true
    }

    private func installObserversIfNeeded() {
        guard conversionObserver == nil else { return }

        conversionObserver = NotificationCenter.default.addObserver(
            forName: .appsFlyerConversionDataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleConversionPayloadAvailable()
        }

        udlObserver = NotificationCenter.default.addObserver(
            forName: .appsFlyerUDLPayloadDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleUDLPayloadAvailable()
        }

        deferredOrganicObserver = NotificationCenter.default.addObserver(
            forName: .appsFlyerDeferredInstallConversionRefreshDidFinish,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.awaitingDeferredOrganicRetry = false
            self?.markReady(reason: .deferredOrganicRefreshFinished)
        }
    }

    private func handleConversionPayloadAvailable() {
        guard AppStartupSettings.resolvedMode == nil else { return }
        guard !isReadyForConfigRequest else { return }

        let payload = AppsFlyerAttributionService.shared.currentConversionPayload()
        let rawForOrganicCheck: [AnyHashable: Any] = payload.map {
            Dictionary(uniqueKeysWithValues: $0.map { (AnyHashable($0.key), $0.value) })
        } ?? [:]

        if AppsFlyerInstallAttribution.shouldScheduleDeferredInstallConversionRefresh(afterReceiving: rawForOrganicCheck) {
            beginOrganicDeferredWait()
            return
        }

        markReady(reason: .conversionAvailable)
    }

    /// Organic: ждём deferred refresh (~5 с), но не дольше чем `splashDeadline` минус резерв под HTTP config.
    private func beginOrganicDeferredWait() {
        awaitingDeferredOrganicRetry = true
        scheduleOrganicDeadlineFallback()
    }

    private func scheduleSplashDeadlineFallback() {
        splashTimeoutWorkItem?.cancel()
        guard let splashDeadline else { return }
        let interval = max(0, splashDeadline.timeIntervalSinceNow)
        let work = DispatchWorkItem { [weak self] in
            self?.forceReadyForSplashDeadline()
        }
        splashTimeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
    }

    private func scheduleOrganicDeadlineFallback() {
        splashTimeoutWorkItem?.cancel()
        guard let splashDeadline else {
            scheduleSplashDeadlineFallback()
            return
        }
        let latestConfigSendTime = splashDeadline.addingTimeInterval(-configHTTPReserve)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.awaitingDeferredOrganicRetry else { return }
            self.awaitingDeferredOrganicRetry = false
            self.markReady(reason: .splashTimeout)
        }
        splashTimeoutWorkItem = work
        let interval = max(0, latestConfigSendTime.timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
    }

    private func handleUDLPayloadAvailable() {
        guard AppStartupSettings.resolvedMode == nil else { return }
        guard !isReadyForConfigRequest else { return }
        guard !awaitingDeferredOrganicRetry else { return }
        if AppsFlyerAttributionService.shared.currentConversionPayload() != nil {
            markReady(reason: .udlWithConversion)
        }
    }

    private enum ReadyReason {
        case conversionAvailable
        case deferredOrganicRefreshFinished
        case udlWithConversion
        case splashTimeout
    }

    private func markReady(reason: ReadyReason) {
        guard AppStartupSettings.resolvedMode == nil else { return }
        guard !isReadyForConfigRequest else { return }
        awaitingDeferredOrganicRetry = false
        isReadyForConfigRequest = true
        splashTimeoutWorkItem?.cancel()
        splashTimeoutWorkItem = nil

        #if DEBUG
        print("[FirstLaunchConfigGate] ready:", String(describing: reason))
        #endif

        flushPendingConfigRefreshIfNeeded()
        NotificationCenter.default.post(name: .firstLaunchConfigGateDidBecomeReady, object: nil)
    }

    private func flushPendingConfigRefreshIfNeeded() {
        guard pendingConfigRefresh else { return }
        pendingConfigRefresh = false
        RemoteConfigFetchService.shared.requestConfigRefresh()
    }

    func requestConfigRefreshWhenReady() {
        if AppStartupSettings.resolvedMode != nil || isReadyForConfigRequest {
            RemoteConfigFetchService.shared.requestConfigRefresh()
            return
        }
        pendingConfigRefresh = true
    }
}

extension Notification.Name {
    static let firstLaunchConfigGateDidBecomeReady = Notification.Name("firstLaunchConfigGateDidBecomeReady")

    /// Organic retry (`start` completion) завершён — можно слать config, даже если payload не изменился.
    static let appsFlyerDeferredInstallConversionRefreshDidFinish = Notification.Name("appsFlyerDeferredInstallConversionRefreshDidFinish")
}
