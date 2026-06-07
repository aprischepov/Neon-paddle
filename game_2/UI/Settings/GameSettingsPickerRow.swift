import UIKit

final class GameSettingsPickerRow: UIView {
    private let titleLabel = MainMenuStyling.makeSectionLabel("")
    private let valueLabel = UILabel()
    private let leftButton = UIButton(type: .system)
    private let rightButton = UIButton(type: .system)
    private var onChange: ((Int) -> Void)?
    private var selectedIndex = 0
    private var optionTitles: [String] = []

    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title.uppercased()
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(count: Int, selectedIndex: Int, titles: [String], onChange: @escaping (Int) -> Void) {
        self.onChange = onChange
        self.selectedIndex = selectedIndex
        self.optionTitles = titles
        valueLabel.text = titles[selectedIndex]
        leftButton.removeTarget(nil, action: nil, for: .allEvents)
        rightButton.removeTarget(nil, action: nil, for: .allEvents)
        leftButton.addAction(UIAction { [weak self] _ in
            self?.step(by: -1, count: count)
        }, for: .touchUpInside)
        rightButton.addAction(UIAction { [weak self] _ in
            self?.step(by: 1, count: count)
        }, for: .touchUpInside)
    }

    private func step(by offset: Int, count: Int) {
        let next = (selectedIndex + offset + count) % count
        selectedIndex = next
        valueLabel.text = optionTitles[next]
        onChange?(next)
    }

    func setValue(_ text: String) {
        valueLabel.text = text
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = MainMenuStyling.roundedFont(size: 26, weight: .medium)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center
        leftButton.translatesAutoresizingMaskIntoConstraints = false
        rightButton.translatesAutoresizingMaskIntoConstraints = false
        [leftButton, rightButton].forEach {
            $0.setTitleColor(.white, for: .normal)
            $0.titleLabel?.font = MainMenuStyling.roundedFont(size: 28, weight: .semibold)
        }
        leftButton.setTitle("<", for: .normal)
        rightButton.setTitle(">", for: .normal)
        addSubview(titleLabel)
        addSubview(leftButton)
        addSubview(valueLabel)
        addSubview(rightButton)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 72),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            valueLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 8),
            leftButton.centerYAnchor.constraint(equalTo: valueLabel.centerYAnchor),
            leftButton.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -24),
            rightButton.centerYAnchor.constraint(equalTo: valueLabel.centerYAnchor),
            rightButton.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 24),
        ])
    }
}
