import Foundation

/// Разбор JSON ответа `config.php`: успех `ok` + `url` + числовой `expires`; ошибка `ok` + `message`.
private enum RemoteConfigAPIResponseParser {

    static func parseJSON(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func boolFlag(_ json: [String: Any], key: String) -> Bool {
        guard let value = json[key] else { return false }
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        if let s = value as? String { return s.lowercased() == "true" || s == "1" }
        return false
    }

    /// Поле `expires`: число (Unix), допускается строка с цифрами.
    static func expiresUnix(from json: [String: Any]) -> Int? {
        guard let value = json["expires"] else { return nil }
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let d = value as? Double { return Int(d) }
        if let s = value as? String { return Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    static func message(from json: [String: Any]) -> String? {
        guard let raw = json["message"] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// `POST` JSON на `AppConstants.RemoteConfig.endpointURL` с телом из `RemoteConfigRequestBuilder`.
final class RemoteConfigFetchService {
    static let shared = RemoteConfigFetchService()

    private let lock = NSLock()
    private var isFetching = false
    private var pendingRetryAfterCurrentFetch = false

    private init() {}

    /// Отправить конфиг с указанным (или актуальным) conversion payload.
    func performFetch(conversionPayload: [String: Any]?) {
        if AppStartupSettings.resolvedMode == .wrapper { return }
        if AppStartupSettings.resolvedMode == nil, !FirstLaunchConfigGate.shared.isReadyForConfigRequest {
            FirstLaunchConfigGate.shared.requestConfigRefreshWhenReady()
            return
        }
        let payload = conversionPayload ?? AppsFlyerAttributionService.shared.currentConversionPayload()
        guard payload != nil || AppStartupSettings.resolvedMode != nil else {
            #if DEBUG
            print("[RemoteConfig] Skip fetch: no conversion payload on first launch")
            #endif
            return
        }
        lock.lock()
        if isFetching {
            pendingRetryAfterCurrentFetch = true
            lock.unlock()
            return
        }
        isFetching = true
        lock.unlock()

        guard let body = RemoteConfigRequestBuilder.postBodyJSONData(conversionPayload: payload) else {
            finishFetchAndRunPending()
            return
        }

        var request = URLRequest(url: AppConstants.RemoteConfig.endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 7
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer { self?.finishFetchAndRunPending() }

            if let error {
                self?.postFailure(httpStatus: nil, message: error.localizedDescription, json: nil)
                return
            }

            let http = response as? HTTPURLResponse
            let status = http?.statusCode

            guard let data, !data.isEmpty else {
                self?.postFailure(httpStatus: status, message: "Empty response body", json: nil)
                return
            }

            guard let json = RemoteConfigAPIResponseParser.parseJSON(data) else {
                self?.postFailure(httpStatus: status, message: "Invalid JSON", json: nil)
                return
            }

            let ok = RemoteConfigAPIResponseParser.boolFlag(json, key: "ok")
            let inSuccessHTTPRange = status.map { (200...299).contains($0) } ?? false

            if inSuccessHTTPRange, ok {
                guard let urlString = json["url"] as? String, !urlString.isEmpty else {
                    self?.postFailure(httpStatus: status, message: "Missing url", json: json)
                    return
                }
                RemoteConfigStore.savedURLString = urlString
                if let expires = RemoteConfigAPIResponseParser.expiresUnix(from: json) {
                    RemoteConfigStore.savedExpiresUnix = expires
                }
                var successInfo: [String: Any] = [
                    RemoteConfigFetchService.successPayloadUserInfoKey: json,
                ]
                if let status {
                    successInfo[RemoteConfigFetchService.httpStatusUserInfoKey] = status
                }
                NotificationCenter.default.post(
                    name: .remoteConfigDidUpdate,
                    object: nil,
                    userInfo: successInfo
                )
                return
            }

            let message = RemoteConfigAPIResponseParser.message(from: json) ?? "Config rejected"
            self?.postFailure(httpStatus: status, message: message, json: json)
        }.resume()
    }

    static let successPayloadUserInfoKey = "payload"
    static let httpStatusUserInfoKey = "httpStatus"
    static let failureMessageUserInfoKey = "message"
    static let failureJSONUserInfoKey = "json"

    private func postFailure(httpStatus: Int?, message: String, json: [String: Any]?) {
        #if DEBUG
        print("[RemoteConfig] failure", "HTTP:", httpStatus.map(String.init) ?? "—", "message:", message)
        #endif
        var userInfo: [String: Any] = [Self.failureMessageUserInfoKey: message]
        if let httpStatus { userInfo[Self.httpStatusUserInfoKey] = httpStatus }
        if let json { userInfo[Self.failureJSONUserInfoKey] = json }
        NotificationCenter.default.post(name: .remoteConfigDidFail, object: nil, userInfo: userInfo)
    }

    /// После FCM / UDL и т.п. — повторить запрос с актуальным conversion + UDL + клиентскими полями.
    func requestConfigRefresh() {
        if AppStartupSettings.resolvedMode == nil, !FirstLaunchConfigGate.shared.isReadyForConfigRequest {
            FirstLaunchConfigGate.shared.requestConfigRefreshWhenReady()
            return
        }
        performFetch(conversionPayload: AppsFlyerAttributionService.shared.latestConversionPayload)
    }

    private func finishFetchAndRunPending() {
        var shouldRetry = false
        lock.lock()
        isFetching = false
        shouldRetry = pendingRetryAfterCurrentFetch
        pendingRetryAfterCurrentFetch = false
        lock.unlock()

        if shouldRetry {
            performFetch(conversionPayload: AppsFlyerAttributionService.shared.latestConversionPayload)
        }
    }
}

extension Notification.Name {
    /// Успех: `userInfo["payload"]` — `[String: Any]`, `userInfo["httpStatus"]` — `Int` (например 200).
    static let remoteConfigDidUpdate = Notification.Name("remoteConfigDidUpdate")

    /// Ошибка: `userInfo["message"]` — `String`, опционально `httpStatus` (`Int`), `json` — тело ответа если разобралось.
    static let remoteConfigDidFail = Notification.Name("remoteConfigDidFail")
}
