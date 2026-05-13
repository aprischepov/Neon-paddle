import PhotosUI
import UIKit
import UniformTypeIdentifiers
import WebKit

extension UIView {
    func embeddedWebViewHostViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController
            }
            responder = current.next
        }
        return nil
    }
}

private enum EmbeddedWebViewFileUploadCopy {
    nonisolated static func copyToTemporaryFile(from source: URL, defaultExtension: String) -> URL? {
        let ext = source.pathExtension.isEmpty ? defaultExtension : source.pathExtension
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
            .appendingPathExtension(ext)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    nonisolated static func copySecurityScopedToTemp(_ url: URL) -> URL? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let ext = url.pathExtension.isEmpty ? "bin" : url.pathExtension
        return copyToTemporaryFile(from: url, defaultExtension: ext)
    }

    nonisolated static func writeJPEGToTemp(_ data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
            .appendingPathExtension("jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// Обработка `<input type="file">`: галерея (PHPicker), камера, выбор файлов/папок через системные пикеры; в WebKit передаются копии во временной директории (без запроса полного доступа к ФС).
@available(iOS 18.4, *)
@MainActor
final class EmbeddedWebViewFileUploadCoordinator: NSObject {
    private let parameters: WKOpenPanelParameters
    private weak var host: UIViewController?
    private weak var anchorView: UIView?
    private let completion: ([URL]?) -> Void

    init(
        parameters: WKOpenPanelParameters,
        host: UIViewController,
        anchorView: UIView,
        completion: @escaping ([URL]?) -> Void
    ) {
        self.parameters = parameters
        self.host = host
        self.anchorView = anchorView
        self.completion = completion
    }

    func begin() {
        guard let host else {
            completion(nil)
            return
        }

        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.presentPhotoLibrary(from: host)
        })
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
                self?.presentCamera(from: host)
            })
        }
        alert.addAction(UIAlertAction(title: "Browse Files", style: .default) { [weak self] _ in
            self?.presentDocumentPicker(from: host, foldersOnly: false)
        })
        if parameters.allowsDirectories {
            alert.addAction(UIAlertAction(title: "Choose Folder", style: .default) { [weak self] _ in
                self?.presentDocumentPicker(from: host, foldersOnly: true)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.finish(nil)
        })

        if let popover = alert.popoverPresentationController, let anchor = anchorView {
            popover.sourceView = anchor
            popover.sourceRect = CGRect(x: anchor.bounds.midX, y: anchor.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }

        host.present(alert, animated: true)
    }

    private func finish(_ urls: [URL]?) {
        if let urls, !urls.isEmpty {
            completion(urls)
        } else {
            completion(nil)
        }
    }

    private func presentPhotoLibrary(from host: UIViewController) {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .any(of: [.images, .livePhotos, .videos])
        config.selectionLimit = parameters.allowsMultipleSelection ? 0 : 1
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        host.present(picker, animated: true)
    }

    private func presentCamera(from host: UIViewController) {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier]
        picker.delegate = self
        if let popover = picker.popoverPresentationController, let anchor = anchorView {
            popover.sourceView = anchor
            popover.sourceRect = anchor.bounds
        }
        host.present(picker, animated: true)
    }

    private func presentDocumentPicker(from host: UIViewController, foldersOnly: Bool) {
        let types: [UTType] = foldersOnly ? [.folder] : [.item]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = parameters.allowsMultipleSelection && !foldersOnly
        if let popover = picker.popoverPresentationController, let anchor = anchorView {
            popover.sourceView = anchor
            popover.sourceRect = anchor.bounds
        }
        host.present(picker, animated: true)
    }
}

@available(iOS 18.4, *)
extension EmbeddedWebViewFileUploadCoordinator: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else {
            finish(nil)
            return
        }

        let group = DispatchGroup()
        var collected: [URL] = []
        let lock = NSLock()

        for result in results {
            group.enter()
            let provider = result.itemProvider

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    defer { group.leave() }
                    guard let uiImage = image as? UIImage,
                          let data = uiImage.jpegData(compressionQuality: 0.92),
                          let url = EmbeddedWebViewFileUploadCopy.writeJPEGToTemp(data) else { return }
                    lock.lock()
                    collected.append(url)
                    lock.unlock()
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    defer { group.leave() }
                    guard let url,
                          let copied = EmbeddedWebViewFileUploadCopy.copyToTemporaryFile(from: url, defaultExtension: "mov") else { return }
                    lock.lock()
                    collected.append(copied)
                    lock.unlock()
                }
            } else {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                    defer { group.leave() }
                    guard let url,
                          let copied = EmbeddedWebViewFileUploadCopy.copyToTemporaryFile(from: url, defaultExtension: "jpg") else { return }
                    lock.lock()
                    collected.append(copied)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.finish(collected.isEmpty ? nil : collected)
        }
    }
}

@available(iOS 18.4, *)
extension EmbeddedWebViewFileUploadCoordinator: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        finish(nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage,
              let data = image.jpegData(compressionQuality: 0.92),
              let url = EmbeddedWebViewFileUploadCopy.writeJPEGToTemp(data) else {
            finish(nil)
            return
        }
        finish([url])
    }
}

@available(iOS 18.4, *)
extension EmbeddedWebViewFileUploadCoordinator: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
        finish(nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        controller.dismiss(animated: true)
        guard !urls.isEmpty else {
            finish(nil)
            return
        }
        var out: [URL] = []
        for url in urls {
            if let copied = EmbeddedWebViewFileUploadCopy.copySecurityScopedToTemp(url) {
                out.append(copied)
            }
        }
        finish(out.isEmpty ? nil : out)
    }
}
