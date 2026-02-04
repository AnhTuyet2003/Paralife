#nullable enable
using Collectibles.Coins;
using UnityEngine;

namespace Collectibles.PowerUps
{
    /// <summary>
    /// Converts nearby coins to special coins with configurable value multipliers.
    /// </summary>
    public class GoodFortuneCoinEffect : PowerUpEffectBase
    {
        public override PowerUpType Type => PowerUpType.GoodFortuneCoin;
        public override bool HasDuration => true;

        private readonly GoodFortuneCoinConfigSO.LevelData levelData;
        private readonly GameObject? auraVisualPrefab;
        private readonly float auraBaseRadius;
        private GameObject? auraVisualInstance;

        public GoodFortuneCoinEffect(
            GoodFortuneCoinConfigSO.LevelData levelData,
            GameObject? auraVisualPrefab,
            float auraBaseRadius = 1f
        )
        {
            this.levelData = levelData;
            this.auraVisualPrefab = auraVisualPrefab;
            this.auraBaseRadius = auraBaseRadius;
        }

        public override void Apply(CatMove player)
        {
            base.Apply(player);

            if (auraVisualPrefab != null)
            {
                auraVisualInstance = Object.Instantiate(auraVisualPrefab, player.transform);
                float desiredScale = levelData.conversionRadius / auraBaseRadius;
                Vector3 parentScale = player.transform.lossyScale;
                auraVisualInstance.transform.localScale = new Vector3(
                    parentScale.x != 0 ? desiredScale / parentScale.x : desiredScale,
                    parentScale.y != 0 ? desiredScale / parentScale.y : desiredScale,
                    parentScale.z != 0 ? desiredScale / parentScale.z : desiredScale
                );
            }

            ConvertNearbyCoins(player.transform.position);
        }

        public override void Update(CatMove player, float deltaTime, float remainingDuration)
        {
            if (!isActive)
                return;

            // Continuously convert any new coins that enter range
            ConvertNearbyCoins(player.transform.position);
        }

        public override void Cancel()
        {
            base.Cancel();

            if (auraVisualInstance != null)
            {
                Object.Destroy(auraVisualInstance);
                auraVisualInstance = null;
            }
        }

        private void ConvertNearbyCoins(Vector3 position)
        {
            // Find all colliders in radius
            Collider2D[] colliders = Physics2D.OverlapCircleAll(
                position,
                levelData.conversionRadius
            );

            foreach (var collider in colliders)
            {
                if (collider.TryGetComponent<CollectibleCoin>(out var coin))
                {
                    ConvertCoin(coin);
                }
            }
        }

        private void ConvertCoin(CollectibleCoin coin)
        {
            // Skip if already converted
            if (coin.IsSpecial)
                return;

            // Determine if this is a special (higher multiplier) conversion
            bool isSpecialConversion = Random.value < levelData.specialChance;

            int multiplier = isSpecialConversion
                ? levelData.specialMultiplier
                : levelData.normalMultiplier;

            GameObject? coinPrefab = isSpecialConversion
                ? levelData.specialCoinPrefab
                : levelData.normalCoinPrefab;

            GameObject? effectPrefab = isSpecialConversion
                ? levelData.specialConversionEffect
                : levelData.normalConversionEffect;

            // Apply conversion
            coin.SetMultiplier(multiplier);
            coin.ConvertToSpecial(coinPrefab, effectPrefab);

            Debug.Log(
                $"[GoodFortuneCoin] Converted coin with x{multiplier} multiplier{(isSpecialConversion ? " (special!)" : "")}"
            );
        }
    }
}
