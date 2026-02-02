#nullable enable
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

        public GoodFortuneCoinEffect(GoodFortuneCoinConfigSO.LevelData levelData)
        {
            this.levelData = levelData;
        }

        public override void Apply(CatMove player)
        {
            base.Apply(player);
            ConvertNearbyCoins(player.transform.position);
        }

        public override void Update(CatMove player, float deltaTime, float remainingDuration)
        {
            if (!isActive)
                return;

            // Continuously convert any new coins that enter range
            ConvertNearbyCoins(player.transform.position);
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

            Sprite? sprite = isSpecialConversion
                ? levelData.specialConversionSprite
                : levelData.normalConversionSprite;

            GameObject? effectPrefab = isSpecialConversion
                ? levelData.specialConversionEffect
                : levelData.normalConversionEffect;

            // Apply conversion
            coin.SetMultiplier(multiplier);
            coin.ConvertToSpecial(sprite, effectPrefab);

            Debug.Log(
                $"[GoodFortuneCoin] Converted coin with x{multiplier} multiplier{(isSpecialConversion ? " (special!)" : "")}"
            );
        }
    }
}
