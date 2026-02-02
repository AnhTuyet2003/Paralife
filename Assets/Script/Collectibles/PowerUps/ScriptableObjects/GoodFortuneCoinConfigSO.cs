#nullable enable
using System;
using UnityEngine;

namespace Collectibles.PowerUps
{
    [CreateAssetMenu(
        fileName = "GoodFortuneCoinConfig",
        menuName = "Paralife/PowerUps/Good Fortune Coin"
    )]
    public class GoodFortuneCoinConfigSO : PowerUpConfigSO
    {
        [Serializable]
        public struct LevelData
        {
            public float duration;

            [Tooltip("Radius to search for coins to convert")]
            public float conversionRadius;

            [Header("Multipliers")]
            [Tooltip("Multiplier for normal conversion (e.g., 2 for x2)")]
            public int normalMultiplier;

            [Tooltip("Multiplier for special conversion (e.g., 3 for x3)")]
            public int specialMultiplier;

            [Tooltip("Chance to get special multiplier instead of normal (0-1)")]
            [Range(0f, 1f)]
            public float specialChance;

            [Header("Visuals (Optional)")]
            [Tooltip("Sprite for normal converted coins (optional)")]
            public Sprite? normalConversionSprite;

            [Tooltip("Sprite for special converted coins (optional)")]
            public Sprite? specialConversionSprite;

            [Tooltip("Effect prefab for normal converted coins (optional)")]
            public GameObject? normalConversionEffect;

            [Tooltip("Effect prefab for special converted coins (optional)")]
            public GameObject? specialConversionEffect;
        }

        [Header("Good Fortune Coin Settings")]
        [SerializeField]
        private LevelData[] levels = Array.Empty<LevelData>();

        private void OnEnable()
        {
            powerUpType = PowerUpType.GoodFortuneCoin;
        }

        public LevelData GetLevelData(int level)
        {
            int index = Mathf.Clamp(level - 1, 0, levels.Length - 1);
            return levels[index];
        }

        /// <summary>
        /// Good Fortune Coin always has a duration.
        /// </summary>
        public override float? GetDuration(int level) => GetLevelData(level).duration;

        public override IPowerUpEffect CreateEffect(int level)
        {
            return new GoodFortuneCoinEffect(GetLevelData(level));
        }
    }
}
