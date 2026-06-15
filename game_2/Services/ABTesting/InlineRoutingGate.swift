import Foundation
enum InlineRoutingGate {
    static var hasPersistedRoutingDecision: Bool {
        AppStartupSettings.resolvedMode != nil
    }
    static var isVariantB: Bool {
        ABTestingService.shared.string(for: .appVariant)?.uppercased() == "B"
    }
    static var isEnabled: Bool {
        hasPersistedRoutingDecision || isVariantB
    }
}
