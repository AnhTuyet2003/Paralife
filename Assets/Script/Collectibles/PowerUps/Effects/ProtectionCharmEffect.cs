#nullable enable
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
        private readonly GameObject? shieldVisualPrefab;

        // Stored during Apply for Cancel/TryNegateCollision
        private PlayerLoseConditionObserver? loseObserver;
        private Rigidbody2D? playerRb;
        private Transform? playerTransform;
        private GameObject? shieldVisualInstance;
        private int remainingUsages;

        public ProtectionCharmEffect(
            ProtectionCharmConfigSO.LevelData levelData,
            GameObject? shieldVisualPrefab
        )
        {
            this.levelData = levelData;
            this.shieldVisualPrefab = shieldVisualPrefab;
            this.remainingUsages = levelData.usageCount;
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
            if (shieldVisualPrefab != null)
            {
                shieldVisualInstance = Object.Instantiate(shieldVisualPrefab, playerTransform);
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
            if (shieldVisualInstance != null)
            {
                Object.Destroy(shieldVisualInstance);
                shieldVisualInstance = null;
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
                playerRb.velocity = new Vector2(playerRb.velocity.x, levelData.holeRecoveryForce);
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
