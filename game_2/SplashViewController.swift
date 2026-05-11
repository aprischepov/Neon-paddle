//
//  SplashViewController.swift
//  Glow Bounce
//

import UIKit

final class SplashViewController: UIViewController {
    private let imageView = UIImageView()
    private var splashTask: Task<Void, Never>?
    private var didFinishSplash = false

    /// Between 3–4 seconds before handing off to the game.
    private let splashDuration: TimeInterval = 3.5

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        updateSplashImage()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard splashTask == nil else { return }

        let duration = splashDuration
        splashTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard let self, self.view.window != nil else { return }
            self.transitionToGame()
        }
    }

    deinit {
        splashTask?.cancel()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateSplashImage()
        })
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSplashImage()
    }

    private func updateSplashImage() {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        let isLandscape = view.bounds.width > view.bounds.height
        imageView.image = UIImage(named: isLandscape ? "loadingHorizontal" : "loadingVertical")
    }

    private func transitionToGame() {
        guard !didFinishSplash else { return }
        didFinishSplash = true
        splashTask?.cancel()
        splashTask = nil

        guard let window = view.window else { return }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let gameVC = storyboard.instantiateViewController(withIdentifier: "GameViewController") as? GameViewController else {
            return
        }

        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
            window.rootViewController = gameVC
        }
    }
}
