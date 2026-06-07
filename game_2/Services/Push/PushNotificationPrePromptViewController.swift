import SwiftUI
import UIKit

/// Кастомный запрос уведомлений до WebView: SwiftUI внутри `UIHostingController`.
final class PushNotificationPrePromptViewController: UIViewController, PushNotificationPrePromptScreenHost {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    private let onAllow: () -> Void
    private let onSkip: () -> Void
    private var didHandleChoice = false
    private let screenModel: PushNotificationPrePromptScreenModel
    private let hostingController: UIHostingController<PushNotificationPrePromptView>

    init(onAllow: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.onAllow = onAllow
        self.onSkip = onSkip
        let model = PushNotificationPrePromptScreenModel()
        self.screenModel = model
        self.hostingController = UIHostingController(rootView: PushNotificationPrePromptView(model: model))
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
        model.host = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController.didMove(toParent: self)
    }

    // MARK: - PushNotificationPrePromptScreenHost

    func pushPrePromptAllowTapped() {
        guard !didHandleChoice else { return }
        didHandleChoice = true
        dismiss(animated: true) { self.onAllow() }
    }

    func pushPrePromptSkipTapped() {
        guard !didHandleChoice else { return }
        didHandleChoice = true
        dismiss(animated: true) { self.onSkip() }
    }
}
