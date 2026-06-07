import UIKit
import SpriteKit

class GameViewController: UIViewController {
    var campaignLevel: CampaignLevel?
    private var presentedScene: GameScene?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        AppLogger.screen(campaignLevel == nil ? "game" : "campaign_level")
        if let view = self.view as! SKView? {
            let scene = GameScene(size: view.bounds.size)
            scene.gameDelegate = self
            scene.campaignLevel = campaignLevel
            scene.scaleMode = .resizeFill
            view.isMultipleTouchEnabled = true
            view.presentScene(scene)
            view.ignoresSiblingOrder = true
            presentedScene = scene
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

extension GameViewController: GameSceneDelegate {
    func gameSceneDidRequestMainMenu(_ scene: GameScene) {
        if campaignLevel != nil || scene.campaignLevel != nil {
            dismiss(animated: true)
            return
        }
        if presentingViewController != nil {
            dismiss(animated: true)
            return
        }
        if let navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
            return
        }
        guard let window = view.window else { return }
        let root = MainMenuFlowController.makeRootViewController()
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
            window.rootViewController = root
        }
    }

    func gameSceneDidFinishCampaignLevel(_ scene: GameScene, levelID: Int, stars: Int, won: Bool) {
        AppLogger.track("campaign_level_finished", properties: [
            "level_id": levelID,
            "stars": stars,
            "won": won,
        ])
    }

    func gameSceneDidRequestNextCampaignLevel(_ scene: GameScene, level: CampaignLevel) {
        campaignLevel = level
        presentedScene = scene
    }
}
