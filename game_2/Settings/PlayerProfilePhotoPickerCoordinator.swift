import UIKit
import UniformTypeIdentifiers

/// Камера / галерея / файлы для аватара профиля. Держите сильную ссылку, пока пикер на экране.
final class PlayerProfilePhotoPickerCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate {
    private weak var host: UIViewController?
    private let onFinish: () -> Void
    private var retainSelf: PlayerProfilePhotoPickerCoordinator?

    init(host: UIViewController, onFinish: @escaping () -> Void) {
        self.host = host
        self.onFinish = onFinish
        super.init()
        retainSelf = self
    }

    func presentPhotoLibrary() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = true
        configurePopover(for: picker)
        host?.present(picker, animated: true)
    }

    func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            end()
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = self
        picker.allowsEditing = true
        configurePopover(for: picker)
        host?.present(picker, animated: true)
    }

    func presentDocumentPicker() {
        let types: [UTType] = [.image, .jpeg, .png, .heic, .gif]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        configurePopover(for: picker)
        host?.present(picker, animated: true)
    }

    private func configurePopover(for picker: UIViewController) {
        guard let pop = picker.popoverPresentationController, let v = host?.view else { return }
        pop.sourceView = v
        pop.sourceRect = CGRect(x: v.bounds.midX, y: v.bounds.midY, width: 1, height: 1)
        pop.permittedArrowDirections = []
    }

    private func end() {
        retainSelf = nil
        onFinish()
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in
            self?.end()
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        if let image {
            try? PlayerProfileStore.saveAvatarImage(image)
        }
        picker.dismiss(animated: true) { [weak self] in
            self?.end()
        }
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        end()
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        defer { end() }
        guard let url = urls.first else { return }
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer {
            if gotAccess { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return }
        try? PlayerProfileStore.saveAvatarImage(image)
    }
}
