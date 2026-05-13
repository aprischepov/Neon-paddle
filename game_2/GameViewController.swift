//
//  GameViewController.swift
//  Glow Bounce
//
//  Created by Artem Prischepov on 1.05.26.
//

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
