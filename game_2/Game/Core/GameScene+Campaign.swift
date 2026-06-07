import Foundation

extension GameScene {
    var matchDifficulty: AIDifficulty {
        campaignLevel?.difficulty ?? GamePreferencesStore.difficulty
    }

    var matchGameMode: GameMode {
        campaignLevel?.gameMode ?? GamePreferencesStore.gameMode
    }

    var shouldRecordLeaderboard: Bool {
        campaignLevel == nil && GamePreferencesStore.gameMode.recordsLeaderboard
    }

    func applyCampaignMatchSettings() {
        if let level = campaignLevel {
            selectedScoreLimit = level.scoreLimit
        } else {
            selectedScoreLimit = 11
        }
    }

    func campaignStarsForCurrentResult(playerWon: Bool) -> Int {
        guard let level = campaignLevel else { return 0 }
        return CampaignStarsCalculator.stars(
            playerWon: playerWon,
            playerScore: playerScore,
            enemyScore: enemyScore
        )
    }

    func notifyCampaignResult(playerWon: Bool) {
        guard let level = campaignLevel else { return }
        let stars = campaignStarsForCurrentResult(playerWon: playerWon)
        if playerWon {
            CampaignProgressStore.recordWin(levelID: level.id, stars: stars)
        }
        gameDelegate?.gameSceneDidFinishCampaignLevel(
            self,
            levelID: level.id,
            stars: stars,
            won: playerWon
        )
    }
}
