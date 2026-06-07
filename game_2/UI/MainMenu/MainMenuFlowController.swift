import UIKit

enum MainMenuFlowController {
    static func makeRootViewController() -> UIViewController {
        let menu = MainMenuViewController()
        let navigation = UINavigationController(rootViewController: menu)
        navigation.setNavigationBarHidden(true, animated: false)
        return navigation
    }

    static func presentGame(from presenter: UIViewController) {
        presentGameViewController(campaignLevel: nil, from: presenter)
    }

    static func presentCampaignLevel(_ level: CampaignLevel, from presenter: UIViewController) {
        presentGameViewController(campaignLevel: level, from: presenter)
    }

    private static func presentGameViewController(campaignLevel: CampaignLevel?, from presenter: UIViewController) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let gameVC = storyboard.instantiateViewController(withIdentifier: "GameViewController") as? GameViewController else {
            return
        }
        gameVC.campaignLevel = campaignLevel
        gameVC.modalPresentationStyle = .fullScreen
        presenter.present(gameVC, animated: true)
    }
}
