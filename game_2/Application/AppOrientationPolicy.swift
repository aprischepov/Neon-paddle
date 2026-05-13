import UIKit

/// Автоповорот по сенсорам / системным жестам; при системной блокировке ориентации iOS сам ограничивает поворот.
enum AppOrientationPolicy {
    static var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    static var shouldAutorotate: Bool { true }
}
