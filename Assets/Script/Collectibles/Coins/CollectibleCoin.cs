#nullable enable
using UnityEngine;

namespace Collectibles.Coins
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
        /// <param name="coinPrefab">Optional prefab to copy visuals from (null = keep current)</param>
        /// <param name="effectPrefab">Optional effect prefab to spawn (null = no effect)</param>
        public void ConvertToSpecial(GameObject? coinPrefab = null, GameObject? effectPrefab = null)
        {
            if (isSpecial)
                return;
            isSpecial = true;

            // Copy visuals from prefab (supports animated sprites)
            if (coinPrefab != null && spriteRenderer != null)
            {
                if (coinPrefab.TryGetComponent<SpriteRenderer>(out var prefabRenderer))
                {
                    spriteRenderer.sprite = prefabRenderer.sprite;
                    spriteRenderer.color = prefabRenderer.color;
                }

                // Copy animator if present (for animated coins)
                if (coinPrefab.TryGetComponent<Animator>(out var prefabAnimator))
                {
                    if (!TryGetComponent<Animator>(out var animator))
                        animator = gameObject.AddComponent<Animator>();
                    animator.runtimeAnimatorController = prefabAnimator.runtimeAnimatorController;
                }
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
