import Foundation
import UIKit

/// Локальный профиль игрока (ник в UserDefaults, фото в Application Support).
enum PlayerProfileStore {
    private static let displayNameKey = "glowBounce.playerProfile.displayName.v1"
    private static let maxNameLength = 32
    private static let avatarFileName = "avatar.jpg"
    private static let profileFolderName = "GlowBounceProfile"

    private static var profileDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(profileFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static var avatarFileURL: URL {
        profileDirectoryURL.appendingPathComponent(avatarFileName)
    }

    static var displayName: String? {
        let raw = UserDefaults.standard.string(forKey: displayNameKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? nil : raw
    }

    static var hasProfile: Bool { displayName != nil }

    static var hasAvatarImage: Bool {
        FileManager.default.fileExists(atPath: avatarFileURL.path)
    }

    static func loadAvatarImage() -> UIImage? {
        guard hasAvatarImage else { return nil }
        return UIImage(contentsOfFile: avatarFileURL.path)
    }

    /// Сохраняет JPEG локально (до ~512 px по длинной стороне).
    static func saveAvatarImage(_ image: UIImage) throws {
        let prepared = image.profileAvatarPrepared(maxSide: 512)
        guard let data = prepared.jpegData(compressionQuality: 0.88) else {
            throw NSError(domain: "PlayerProfileStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "JPEG encode failed"])
        }
        try data.write(to: avatarFileURL, options: .atomic)
    }

    static func removeAvatarImage() {
        try? FileManager.default.removeItem(at: avatarFileURL)
    }

    static func setDisplayName(_ raw: String?) {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: displayNameKey)
        } else {
            UserDefaults.standard.set(String(trimmed.prefix(maxNameLength)), forKey: displayNameKey)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: displayNameKey)
        UserDefaults.standard.removeObject(forKey: "glowBounce.playerProfile.avatarRingIndex.v1")
        removeAvatarImage()
    }

    static func cardTitleText() -> String {
        displayName ?? "Guest"
    }

    static func cardSubtitleText() -> String {
        hasProfile ? "Tap to edit" : "Tap to set name & photo"
    }

    static func initialsForAvatar() -> String {
        guard let name = displayName, !name.isEmpty else { return "?" }
        let parts = name.split(whereSeparator: { $0.isWhitespace || $0 == "_" || $0 == "-" }).map(String.init)
        if parts.count >= 2 {
            let a = parts[0].prefix(1)
            let b = parts[1].prefix(1)
            return String(a + b).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

private extension UIImage {
    func profileAvatarPrepared(maxSide: CGFloat) -> UIImage {
        let w = size.width
        let h = size.height
        let longest = max(w, h)
        guard longest > maxSide, longest > 0 else { return self }
        let scale = maxSide / longest
        let target = CGSize(width: max(1, w * scale), height: max(1, h * scale))
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
