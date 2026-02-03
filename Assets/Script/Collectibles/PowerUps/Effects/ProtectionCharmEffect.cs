#nullable enable
using Gameplay;
using UnityEngine;

namespace Collectibles.PowerUps
{
    /// <summary>
    /// Negates collisions with obstacles/holes.
    /// Expires when either duration runs out OR all usages are consumed.
    /// For holes, also applies upward force to save the player.
    /// </summary>
    public class ProtectionCharmEffect : PowerUpEffectBase
    {
        public override PowerUpType Type => PowerUpType.ProtectionCharm;

        /// <summary>
        /// HasDuration is true unless this level has infinite duration.
        /// </summary>
        public override bool HasDuration => !levelData.HasInfiniteDuration;

        private readonly ProtectionCharmConfigSO.LevelData levelData;
        private int remainingUsages;

        private readonly GameObject? auraVisualPrefab;
        private readonly float auraLocalScale;
        private GameObject? auraVisualInstance;

        // Stored during Apply for Cancel/TryNegateCollision
        private PlayerLoseConditionObserver? loseObserver;
        private Rigidbody2D? playerRb;
        private Transform? playerTransform;

        public ProtectionCharmEffect(
            ProtectionCharmConfigSO.LevelData levelData,
            GameObject? auraVisualPrefab,
            float auraLocalScale = 1.25f
        )
        {
            this.levelData = levelData;
            this.remainingUsages = levelData.usageCount;

            this.auraVisualPrefab = auraVisualPrefab;
            this.auraLocalScale = auraLocalScale;
        }

        public override void Apply(CatMove player)
        {
            base.Apply(player);

            // Store references needed for Cancel and TryNegateCollision
            playerRb = player.rb;
            playerTransform = player.transform;

            // Find observer on player
            loseObserver = player.GetComponent<PlayerLoseConditionObserver>();
            if (loseObserver != null)
            {
                // Inject our negation function
                loseObserver.CollisionNegator = TryNegateCollision;
            }

            // Show shield visual
            if (auraVisualPrefab != null)
            {
                auraVisualInstance = Object.Instantiate(auraVisualPrefab, playerTransform);

                // Get player's world scale and adjust aura local scale proportionally
                Vector3 playerWorldScale = playerTransform.lossyScale;
                float scaleFactor = 1f / playerWorldScale.x; // or average of all axes if non-uniform
                auraVisualInstance.transform.localScale =
                    Vector3.one * (auraLocalScale * scaleFactor);
            }

            Debug.Log(
                $"[ProtectionCharm] Applied with {remainingUsages} usages, duration: {(HasDuration ? levelData.duration + "s" : "infinite")}"
            );
        }

        public override void Cancel()
        {
            base.Cancel();

            // Remove our negation function
            if (loseObserver != null)
            {
                loseObserver.CollisionNegator = null;
            }

            // Destroy shield visual
            if (auraVisualInstance != null)
            {
                Object.Destroy(auraVisualInstance);
                auraVisualInstance = null;
            }

            // Clear references
            loseObserver = null;
            playerRb = null;
            playerTransform = null;
        }

        public override void OnExpired()
        {
            base.OnExpired();
            Debug.Log(
                $"[ProtectionCharm] Duration expired with {remainingUsages} usages remaining"
            );
        }

        private bool TryNegateCollision(string tag)
        {
            if (remainingUsages <= 0)
                return false; // No usages left, can't negate

            if (tag == "Hole" && playerRb != null)
            {
                // Apply upward force to save from hole
                playerRb.velocity =
                    new Vector2(playerRb.velocity.x, 0f) + levelData.holeRecoveryForce;
            }

            // Consume one usage
            remainingUsages--;
            Debug.Log($"[ProtectionCharm] Negated {tag}, {remainingUsages} usages remaining");

            // Check if all usages consumed
            if (remainingUsages <= 0)
            {
                InvokeOnEffectDepleted();
            }

            return true; // Negate the collision
        }
    }
}
