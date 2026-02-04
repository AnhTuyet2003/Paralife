#nullable enable
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace Collectibles.PowerUps
{
    /// <summary>
    /// Holds all power-up configurations. Resolves config by type.
    /// Acts as a Flyweight factory for power-up data.
    /// </summary>
    public class PowerUpCatalog : MonoBehaviour
    {
        [SerializeField]
        private List<PowerUpConfigSO> powerUpConfigs = new();

        private Dictionary<PowerUpType, PowerUpConfigSO>? configsByType;

        private void Awake()
        {
            configsByType = powerUpConfigs.Where(c => c != null).ToDictionary(c => c.powerUpType);
        }

        /// <summary>
        /// Get the configuration for a power-up type.
        /// </summary>
        public PowerUpConfigSO? GetConfig(PowerUpType type)
        {
            if (configsByType == null)
                return null;
            return configsByType.TryGetValue(type, out var config) ? config : null;
        }

        /// <summary>
        /// Create an effect instance for the given type at the specified level.
        /// </summary>
        public IPowerUpEffect? CreateEffect(PowerUpType type, int level)
        {
            var config = GetConfig(type);
            if (config == null)
            {
                Debug.LogWarning($"[PowerUpCatalog] No config found for {type}");
                return null;
            }

            return config.CreateEffect(level);
        }

        /// <summary>
        /// Get duration for a power-up type at the specified level.
        /// Returns null for infinite duration effects.
        /// </summary>
        public float? GetDuration(PowerUpType type, int level)
        {
            var config = GetConfig(type);
            return config != null ? config.GetDuration(level) : null;
        }
    }
}
