import Foundation
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
