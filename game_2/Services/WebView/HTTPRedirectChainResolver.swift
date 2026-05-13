import Foundation

/// Ручной обход цепочки HTTP 3xx: не ограничен лимитом авто-редиректов WebKit/`URLSession` (~16).
enum HTTPRedirectChainResolver {
    private final class NoAutoRedirectDelegate: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            completionHandler(nil)
        }
    }

    /// Возвращает URL последнего ответа без 3xx (или последний из цепочки при достижении `maxHops`).
    static func resolve(byFollowingRedirectsFrom start: URL, maxHops: Int = 128, userAgent: String?) async throws -> URL {
        let delegate = NoAutoRedirectDelegate()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 120
        configuration.httpShouldSetCookies = true
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        var current = start
        for _ in 0..<maxHops {
            var request = URLRequest(url: current)
            request.httpMethod = "GET"
            if let userAgent {
                request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            }
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return current }
            guard (300..<400).contains(http.statusCode) else { return current }
            guard let location = http.value(forHTTPHeaderField: "Location") else { return current }
            guard let next = URL(string: location, relativeTo: current)?.absoluteURL else { return current }
            guard next != current else { return current }
            current = next
        }
        return current
    }
}
