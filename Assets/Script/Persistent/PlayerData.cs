#nullable enable
using System;
using System.Collections.Generic;

namespace Persistent
{
    /// <summary>
    /// Serializable player data container for JSON persistence.
    /// Raw data only - use accessors for domain-specific logic.
    /// </summary>
    [Serializable]
    public class PlayerData
    {
        /// <summary>
        /// Power-up levels as serializable list.
        /// Level 0 means not unlocked, level 1+ is the upgrade level.
        /// </summary>
        public List<PowerUpLevelEntry> powerUpLevels = new();

        // Future fields:
        // public int coins;
        // public int highScore;
        // public List<string> unlockedItems;
    }
}
