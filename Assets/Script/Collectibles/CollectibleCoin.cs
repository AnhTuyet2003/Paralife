#nullable enable
using UnityEngine;

namespace Collectibles.PowerUps
{
    /// <summary>
    /// Base coin collectible that can be attracted by Magnet
    /// and converted by Good Fortune Coin.
    /// </summary>
    [RequireComponent(typeof(Collider2D))]
    public class CollectibleCoin : MonoBehaviour
    {
        [Header("Coin Settings")]
        [SerializeField]
        private int baseValue = 1;

        [SerializeField]
        private SpriteRenderer? spriteRenderer;

        private int multiplier = 1;
        private bool isSpecial;
        private GameObject? specialEffectInstance;

        public bool IsSpecial => isSpecial;
        public int Value => baseValue * multiplier;

        private void Awake()
        {
            var collider = GetComponent<Collider2D>();
            collider.isTrigger = true;
        }

        /// <summary>
        /// Set the value multiplier for this coin.
        /// </summary>
        public void SetMultiplier(int newMultiplier)
        {
            multiplier = newMultiplier;
        }

        /// <summary>
        /// Convert this coin to a special coin with optional visual effects.
        /// </summary>
        /// <param name="sprite">Optional sprite to change to (null = keep current)</param>
        /// <param name="effectPrefab">Optional effect prefab to spawn (null = no effect)</param>
        public void ConvertToSpecial(Sprite? sprite = null, GameObject? effectPrefab = null)
        {
            if (isSpecial)
                return;
            isSpecial = true;

            // Visual change (only if sprite provided)
            if (sprite != null && spriteRenderer != null)
            {
                spriteRenderer.sprite = sprite;
            }

            // Spawn effect overlay (only if prefab provided)
            if (effectPrefab != null)
            {
                specialEffectInstance = Instantiate(effectPrefab, transform);
            }
        }

        /// <summary>
        /// Called when collected by player.
        /// Returns the total value (base * multiplier).
        /// </summary>
        public int Collect()
        {
            int totalValue = Value;
            Debug.Log($"[Coin] Collected worth {totalValue} points (x{multiplier})");

            // Cleanup effect
            if (specialEffectInstance != null)
            {
                Destroy(specialEffectInstance);
            }

            Destroy(gameObject);
            return totalValue;
        }
    }
}
