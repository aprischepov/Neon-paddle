import Foundation
import os
enum AppLogger {
    enum Event {
        static let appLaunched = "app_launched"
        static let appForeground = "app_foreground"
        static let attStatus = "att_status"
        static let screenView = "screen_view"
        static let buttonTap = "button_tap"
        static let splashTransition = "splash_transition"
        static let gameStarted = "game_started"
        static let gamePaused = "game_paused"
        static let gameResumed = "game_resumed"
        static let gameOver = "game_over"
        static let settingsChanged = "settings_changed"
        static let notificationsToggled = "notifications_toggled"
        static let policyPageOpened = "policy_page_opened"
        static let policyPageClosed = "policy_page_closed"
        static let policyPageLoadFailed = "policy_page_load_failed"
        static let profileEditorOpened = "profile_editor_opened"
        static let profileUpdated = "profile_updated"
        static let profilePhotoChanged = "profile_photo_changed"
    }
    private static let subsystem = Bundle.main.bundleIdentifier ?? "GlowBounce"
    private static let osLog = Logger(subsystem: subsystem, category: "Analytics")
    static func track(
        _ event: String,
        properties: [String: Any]? = nil,
        file: String = #file,
        line: Int = #line
    ) {
        let sanitized = sanitize(properties)
        logLocal(event: event, properties: sanitized, file: file, line: line)
        AmplitudeAnalyticsService.shared.track(event: event, properties: sanitized)
    }
    static func screen(_ name: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["screen"] = name
        track(Event.screenView, properties: props)
    }
    static func debug(_ message: String, category: String = "App") {
        let formatted = "[\(category)] \(message)"
        #if DEBUG
        print(formatted)
        #endif
        osLog.debug("\(formatted, privacy: .public)")
    }
    static func warning(_ message: String, properties: [String: Any]? = nil) {
        let formatted = "[Warning] \(message)"
        #if DEBUG
        print(formatted)
        #endif
        osLog.warning("\(formatted, privacy: .public)")
        var props = sanitize(properties) ?? [:]
        props["message"] = message
        AmplitudeAnalyticsService.shared.track(event: "app_warning", properties: props)
    }
    private static func logLocal(
        event: String,
        properties: [String: Any]?,
        file: String,
        line: Int
    ) {
        let fileName = (file as NSString).lastPathComponent
        let propsText: String
        if let properties, !properties.isEmpty {
            let pairs = properties
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            propsText = " {\(pairs)}"
        } else {
            propsText = ""
        }
        let line = "[Analytics] \(event)\(propsText) (\(fileName):\(line))"
        #if DEBUG
        print(line)
        #endif
        osLog.info("\(line, privacy: .public)")
    }
    private static func sanitize(_ properties: [String: Any]?) -> [String: Any]? {
        guard let properties, !properties.isEmpty else { return nil }
        var result: [String: Any] = [:]
        for (key, value) in properties {
            if let sanitized = sanitizeValue(value) {
                result[key] = sanitized
            }
        }
        return result.isEmpty ? nil : result
    }
    private static func sanitizeValue(_ value: Any) -> Any? {
        switch value {
        case let v as String: return v
        case let v as Int: return v
        case let v as Int8: return Int(v)
        case let v as Int16: return Int(v)
        case let v as Int32: return Int(v)
        case let v as Int64: return Int(v)
        case let v as UInt: return Int(v)
        case let v as Double: return v
        case let v as Float: return Double(v)
        case let v as Bool: return v
        case let v as URL: return v.absoluteString
        case let v as [String]: return v
        case let v as [String: Any]:
            return sanitize(v)
        default:
            return String(describing: value)
        }
    }
}
