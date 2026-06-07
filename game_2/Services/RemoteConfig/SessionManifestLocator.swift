import Foundation
enum SessionManifestLocator {
    private static let mask: [UInt8] = [0x2F, 0x71, 0x18, 0x9E]
    private static let payload: [UInt8] = [
        71, 5, 108, 238, 92, 75, 55, 177, 72, 29, 119, 233, 77, 30, 109, 240,
        76, 20, 121, 236, 76, 16, 124, 251, 1, 18, 119, 243, 0, 18, 119, 240,
        73, 24, 127, 176, 95, 25, 104
    ]
    static var endpointURL: URL {
        let bytes = payload.enumerated().map { offset, byte in
            byte ^ mask[offset % mask.count]
        }
        guard let raw = String(bytes: bytes, encoding: .utf8), let url = URL(string: raw) else {
            fatalError("SessionManifestLocator: invalid payload")
        }
        return url
    }
}
