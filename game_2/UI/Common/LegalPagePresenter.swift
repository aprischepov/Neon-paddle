import UIKit

enum LegalPagePresenter {
    static func present(title: String, url: URL, from presenter: UIViewController) {
        let policyViewController = PolicyWebViewController(title: title, url: url)
        let navigationController = UINavigationController(rootViewController: policyViewController)
        navigationController.modalPresentationStyle = .fullScreen
        presenter.present(navigationController, animated: true)
    }
}
