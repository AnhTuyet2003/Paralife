#nullable enable
using System;
using Collectibles.PowerUps;

namespace Persistent
{
    /// <summary>
    /// Serializable entry for power-up level.
    /// </summary>
    [Serializable]
    public struct PowerUpLevelEntry
    {
        public PowerUpType type;
        public int level;

        public PowerUpLevelEntry(PowerUpType type, int level)
        {
            this.type = type;
            this.level = level;
        }
    }

    /// <summary>
    /// Provides read/write access to power-up progression data.
    /// Wraps PlayerData and notifies on changes for persistence.
    /// </summary>
    public class PowerUpDataAccessor
    {
        private readonly PlayerData data;
        private readonly Action? onDataChanged;

        public PowerUpDataAccessor(PlayerData data, Action? onDataChanged = null)
        {
            this.data = data;
            this.onDataChanged = onDataChanged;
        }

        /// <summary>
        /// Get the level for a power-up type.
        /// Returns 1 if not set (default level).
        /// </summary>
        public int GetLevel(PowerUpType type)
        {
            foreach (var entry in data.powerUpLevels)
            {
                if (entry.type == type)
                    return entry.level;
            }
            return 1;
        }

        /// <summary>
        /// Set the level for a power-up type.
        /// </summary>
        public void SetLevel(PowerUpType type, int level)
        {
            for (int i = 0; i < data.powerUpLevels.Count; i++)
            {
                if (data.powerUpLevels[i].type == type)
                {
                    data.powerUpLevels[i] = new PowerUpLevelEntry(type, level);
                    onDataChanged?.Invoke();
                    return;
                }
            }
            data.powerUpLevels.Add(new PowerUpLevelEntry(type, level));
            onDataChanged?.Invoke();
        }

        /// <summary>
        /// Upgrade a power-up by one level.
        /// </summary>
        public void Upgrade(PowerUpType type)
        {
            int currentLevel = GetLevel(type);
            SetLevel(type, currentLevel + 1);
        }
    }
}
