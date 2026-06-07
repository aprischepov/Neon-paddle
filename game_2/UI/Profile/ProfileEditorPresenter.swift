import UIKit

final class ProfileEditorPresenter: NSObject {
    private weak var host: UIViewController?
    private var photoCoordinator: PlayerProfilePhotoPickerCoordinator?
    private let onProfileChanged: () -> Void

    init(host: UIViewController, onProfileChanged: @escaping () -> Void) {
        self.host = host
        self.onProfileChanged = onProfileChanged
    }

    func presentProfileEditor() {
        guard let host else { return }
        AppLogger.track(AppLogger.Event.profileEditorOpened)
        let alert = UIAlertController(
            title: "Profile",
            message: "Saved on this device only.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Nickname"
            textField.text = PlayerProfileStore.displayName
            textField.autocorrectionType = .yes
            textField.textContentType = .nickname
            textField.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Photo…", style: .default) { [weak self] _ in
            self?.presentPhotoSourceSheet()
        })
        if PlayerProfileStore.hasProfile || PlayerProfileStore.hasAvatarImage {
            alert.addAction(UIAlertAction(title: "Clear profile", style: .destructive) { [weak self] _ in
                PlayerProfileStore.clear()
                self?.onProfileChanged()
                AppLogger.track(AppLogger.Event.profileUpdated, properties: ["action": "clear"])
            })
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            PlayerProfileStore.setDisplayName(alert.textFields?.first?.text)
            self?.onProfileChanged()
            if let name = PlayerProfileStore.displayName {
                AmplitudeAnalyticsService.shared.setUserId(name)
            }
            AppLogger.track(AppLogger.Event.profileUpdated, properties: ["action": "save_nickname"])
        })
        host.present(alert, animated: true)
    }

    private func presentPhotoSourceSheet() {
        guard let host else { return }
        let sheet = UIAlertController(title: "Profile photo", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Photo library", style: .default) { [weak self] _ in
            self?.startPhotoFlow { $0.presentPhotoLibrary() }
        })
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Take photo", style: .default) { [weak self] _ in
                self?.startPhotoFlow { $0.presentCamera() }
            })
        }
        sheet.addAction(UIAlertAction(title: "Choose file…", style: .default) { [weak self] _ in
            self?.startPhotoFlow { $0.presentDocumentPicker() }
        })
        if PlayerProfileStore.hasAvatarImage {
            sheet.addAction(UIAlertAction(title: "Remove photo", style: .destructive) { [weak self] _ in
                PlayerProfileStore.removeAvatarImage()
                self?.onProfileChanged()
                AppLogger.track(AppLogger.Event.profilePhotoChanged, properties: ["action": "remove"])
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = host.view
            pop.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        host.present(sheet, animated: true)
    }

    private func startPhotoFlow(_ start: (PlayerProfilePhotoPickerCoordinator) -> Void) {
        guard let host else { return }
        let coordinator = PlayerProfilePhotoPickerCoordinator(host: host) { [weak self] in
            self?.photoCoordinator = nil
            self?.onProfileChanged()
            AppLogger.track(AppLogger.Event.profilePhotoChanged, properties: ["action": "updated"])
        }
        photoCoordinator = coordinator
        start(coordinator)
    }
}
