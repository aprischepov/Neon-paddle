import UIKit

final class SplashViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        AppOrientationPolicy.shouldAutorotate
    }

    private let imageView = UIImageView()
    private let loadingStack = UIStackView()
    private let spinnerImageView = UIImageView()
    private let loadingImageView = UIImageView()

    private let loadingStackSpacing: CGFloat = 20
    private let spinnerImageSize: CGFloat = 56
    private let loadingImageMaxWidthRatio: CGFloat = 0.5
    private let spinnerRotationDuration: TimeInterval = 1.2
    private let spinnerRotationKey = "spinnerRotation"

    override func viewDidLoad() {
        super.viewDidLoad()
        AppLogger.screen("splash")
        view.backgroundColor = .black

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        view.addSubview(imageView)
        configureLoadingStack()

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        updateSplashImage()
    }

    private func configureLoadingStack() {
        loadingStack.translatesAutoresizingMaskIntoConstraints = false
        loadingStack.axis = .vertical
        loadingStack.spacing = loadingStackSpacing
        loadingStack.alignment = .center
        loadingStack.isAccessibilityElement = false

        spinnerImageView.translatesAutoresizingMaskIntoConstraints = false
        spinnerImageView.image = UIImage(named: "spinner")
        spinnerImageView.contentMode = .scaleAspectFit

        loadingImageView.translatesAutoresizingMaskIntoConstraints = false
        let loadingImage = UIImage(named: "loading")
        loadingImageView.image = loadingImage
        loadingImageView.contentMode = .scaleAspectFit

        loadingStack.addArrangedSubview(spinnerImageView)
        loadingStack.addArrangedSubview(loadingImageView)
        view.addSubview(loadingStack)
        view.bringSubviewToFront(loadingStack)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            loadingStack.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            loadingStack.centerYAnchor.constraint(equalTo: safe.centerYAnchor),

            spinnerImageView.widthAnchor.constraint(equalToConstant: spinnerImageSize),
            spinnerImageView.heightAnchor.constraint(equalToConstant: spinnerImageSize),

            loadingImageView.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, multiplier: loadingImageMaxWidthRatio),
        ])

        if let loadingImage, loadingImage.size.width > 0 {
            loadingImageView.heightAnchor.constraint(
                equalTo: loadingImageView.widthAnchor,
                multiplier: loadingImage.size.height / loadingImage.size.width
            ).isActive = true
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSpinnerRotation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.transitionToGame()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.updateSplashImage() })
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSplashImage()
    }

    private func updateSplashImage() {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        let isLandscape = view.bounds.width > view.bounds.height
        imageView.image = UIImage(named: isLandscape ? "splashHorizontal" : "splashVertical")
    }

    private func startSpinnerRotation() {
        guard spinnerImageView.layer.animation(forKey: spinnerRotationKey) == nil else { return }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = spinnerRotationDuration
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        spinnerImageView.layer.add(rotation, forKey: spinnerRotationKey)
    }

    private func transitionToGame() {
        guard let window = view.window else { return }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let gameVC = storyboard.instantiateViewController(withIdentifier: "GameViewController") as? GameViewController else {
            AppLogger.warning("Failed to instantiate GameViewController from storyboard")
            return
        }
        AppLogger.track(AppLogger.Event.splashTransition)
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
            window.rootViewController = gameVC
        }
    }
}
