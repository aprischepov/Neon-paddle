import Foundation

enum GamePreferencesStore {
    private static let difficultyKey = "selectedDifficulty"
    private static let gameModeKey = "selectedGameMode"

    static var difficulty: AIDifficulty {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: difficultyKey) == nil {
                return .normal
            }
            return AIDifficulty(rawValue: defaults.integer(forKey: difficultyKey)) ?? .normal
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: difficultyKey)
        }
    }

    static var gameMode: GameMode {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: gameModeKey) == nil {
                return .powerUps
            }
            return GameMode(rawValue: defaults.integer(forKey: gameModeKey)) ?? .powerUps
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: gameModeKey)
        }
    }
}
