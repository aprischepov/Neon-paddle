import UIKit
import SpriteKit
class GameViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }
    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        AppLogger.screen("game")
        if let view = self.view as! SKView? {
            let scene = GameScene(size: view.bounds.size)
            scene.scaleMode = .resizeFill
            view.presentScene(scene)
            view.ignoresSiblingOrder = true
        }
    }
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
