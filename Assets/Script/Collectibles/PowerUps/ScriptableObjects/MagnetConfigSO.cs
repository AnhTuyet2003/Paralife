#nullable enable
using System;
using UnityEngine;

namespace Collectibles.PowerUps
{
    [CreateAssetMenu(fileName = "MagnetConfig", menuName = "Paralife/PowerUps/Magnet")]
    public class MagnetConfigSO : PowerUpConfigSO
    {
        [Serializable]
        public struct LevelData
        {
            public float duration;
            public float attractionRadius;
            public float attractionSpeed;
        }

        [Header("Magnet Settings")]
        [SerializeField]
        private LevelData[] levels = Array.Empty<LevelData>();

        [Header("Attraction Filters")]
        [Tooltip("Tags that should be attracted by the magnet")]
        public string[] attractableTags = { "Coin", "Collectible" };

        [Header("Visuals")]
        [Tooltip("Visual effect prefab shown on player while magnet is active")]
        public GameObject? magnetVisualPrefab;

        private void OnEnable()
        {
            powerUpType = PowerUpType.Magnet;
        }

        public LevelData GetLevelData(int level)
        {
            int index = Mathf.Clamp(level - 1, 0, levels.Length - 1);
            return levels[index];
        }

        /// <summary>
        /// Magnet always has a duration.
        /// </summary>
        public override float? GetDuration(int level) => GetLevelData(level).duration;

        public override IPowerUpEffect CreateEffect(int level)
        {
            return new MagnetEffect(GetLevelData(level), attractableTags, magnetVisualPrefab);
        }
    }
}
