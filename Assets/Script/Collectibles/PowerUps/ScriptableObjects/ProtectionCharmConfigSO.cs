#nullable enable
using System;
using UnityEngine;

namespace Collectibles.PowerUps
{
    [CreateAssetMenu(
        fileName = "ProtectionCharmConfig",
        menuName = "Paralife/PowerUps/Protection Charm"
    )]
    public class ProtectionCharmConfigSO : PowerUpConfigSO
    {
        [Serializable]
        public struct LevelData
        {
            [Tooltip(
                "Duration in seconds. Set to 0 or negative for infinite duration (usage-only mode)"
            )]
            public float duration;

            [Tooltip("Number of hits this charm can negate")]
            public int usageCount;

            [Tooltip("Upward force applied when saving from hole")]
            public float holeRecoveryForce;

            /// <summary>
            /// True if this level has infinite duration (only expires by usage depletion)
            /// </summary>
            public readonly bool HasInfiniteDuration => duration <= 0f;
        }

        [Header("Protection Charm Settings")]
        [SerializeField]
        private LevelData[] levels = Array.Empty<LevelData>();

        [Header("Visuals")]
        public GameObject? shieldVisualPrefab;

        private void OnEnable()
        {
            powerUpType = PowerUpType.ProtectionCharm;
        }

        public LevelData GetLevelData(int level)
        {
            int index = Mathf.Clamp(level - 1, 0, levels.Length - 1);
            return levels[index];
        }

        /// <summary>
        /// Returns duration for the level, or null if infinite duration.
        /// </summary>
        public override float? GetDuration(int level)
        {
            var data = GetLevelData(level);
            return data.HasInfiniteDuration ? null : data.duration;
        }

        public override IPowerUpEffect CreateEffect(int level)
        {
            return new ProtectionCharmEffect(GetLevelData(level), shieldVisualPrefab);
        }
    }
}
