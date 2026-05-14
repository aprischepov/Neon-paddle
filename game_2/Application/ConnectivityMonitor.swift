import Foundation
import Network

/// Доступность сети для сценария первого запуска (п. 1.3).
///
/// На **симуляторе** путь часто отражает сеть **Mac** (несколько интерфейсов): выключение Wi‑Fi в симуляторе может не дать `.unsatisfied`, если на Mac активен Ethernet и т.п. Для стресс‑теста офлайна удобнее Network Link Conditioner или физическое устройство.
final class ConnectivityMonitor {
    static let shared = ConnectivityMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.glowbounce.connectivity")
    private let lock = NSLock()
    private(set) var isSatisfied = false

    private init() {}

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.update(path.status == .satisfied)
        }
        monitor.start(queue: queue)
        update(monitor.currentPath.status == .satisfied)
    }

    private func update(_ satisfied: Bool) {
        lock.lock()
        let changed = isSatisfied != satisfied
        isSatisfied = satisfied
        lock.unlock()
        if changed {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .connectivityDidChange, object: nil)
            }
        }
    }

    var isOnline: Bool {
        lock.lock()
        let v = isSatisfied
        lock.unlock()
        return v
    }
}
