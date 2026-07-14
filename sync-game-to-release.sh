#!/bin/bash
# Синхронизирует игровые файлы из store-clean в release.
# Запускать стоя на ветке release.
# Использование: ./sync-game-to-release.sh

set -e

CURRENT=$(git branch --show-current)
if [ "$CURRENT" != "release" ]; then
  echo "❌ Запусти скрипт находясь на ветке release (сейчас: $CURRENT)"
  exit 1
fi

echo "⬇️  Забираю игровые файлы из store-clean..."

git checkout store-clean -- \
  game_2/Game \
  game_2/UI \
  game_2/Campaign \
  game_2/Achievements \
  game_2/GameViewController.swift \
  game_2/PolicyWebViewController.swift \
  game_2/AppConstants.swift \
  game_2/Services/LocalLeaderboardStore.swift \
  game_2/Services/PlayerProfileStore.swift \
  game_2/Settings/GameMenuAppearance.swift \
  game_2/Settings/GameSettingsProfileCard.swift \
  game_2/Settings/PlayerProfilePhotoPickerCoordinator.swift

echo "✅ Файлы скопированы. Проверь изменения: git diff --staged"
echo "   Затем: git commit -m 'sync game updates from store-clean'"
