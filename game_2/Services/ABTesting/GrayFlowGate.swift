import Foundation

/// Серый post-attribution флоу активен для варианта B или при уже сохранённом режиме WebView/обёртки.
enum GrayFlowGate {
    static var hasPersistedGrayMode: Bool {
        AppStartupSettings.resolvedMode != nil
    }

    static var isVariantB: Bool {
        ABTestingService.shared.string(for: .appVariant)?.uppercased() == "B"
    }

    static var isEnabled: Bool {
        hasPersistedGrayMode || isVariantB
    }
}
