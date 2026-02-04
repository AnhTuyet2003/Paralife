#nullable enable
using UnityEngine;

namespace Collectibles.PowerUps
{
    /// <summary>
    /// Base ScriptableObject for power-up configuration.
    /// Each derived class defines its own LevelData array and CreateEffect factory.
    /// </summary>
    public abstract class PowerUpConfigSO : ScriptableObject
    {
        [Header("Basic Settings")]
        public PowerUpType powerUpType;
        public string displayName;

        [TextArea]
        public string description;
        public Sprite? icon;

        [Header("Prefab")]
        public GameObject? pickupPrefab;

        /// <summary>
        /// Get duration for the specified level.
        /// Returns null for infinite duration (e.g., usage-only effects).
        /// </summary>
        public abstract float? GetDuration(int level);

        /// <summary>
        /// Create effect instance for the specified level.
        /// </summary>
        public abstract IPowerUpEffect CreateEffect(int level);
    }
}
