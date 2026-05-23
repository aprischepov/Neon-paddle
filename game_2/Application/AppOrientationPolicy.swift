import UIKit

enum AppOrientationPolicy {
    static var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    static var shouldAutorotate: Bool { true }
}
