using UnityEngine;

namespace Collectibles.PowerUps
{
    /// <summary>
    /// MonoBehaviour component for power-up pickups placed in the scene.
    /// Can be manually placed or spawned at runtime.
    /// Level is determined by player progression, not by the pickup itself.
    /// </summary>
    [RequireComponent(typeof(Collider2D))]
    public class PowerUpPickup : MonoBehaviour
    {
        [Header("Configuration")]
        [SerializeField]
        private PowerUpType powerUpType;

        [Header("Visual")]
        [SerializeField]
        private SpriteRenderer spriteRenderer;

        public PowerUpType PowerUpType => powerUpType;

        private bool isCollected;

        private void Awake()
        {
            // Ensure collider is a trigger
            var collider = GetComponent<Collider2D>();
            collider.isTrigger = true;
        }

        /// <summary>
        /// Initialize the pickup type (used for runtime spawning).
        /// </summary>
        public void Initialize(PowerUpType type)
        {
            this.powerUpType = type;
        }

        /// <summary>
        /// Called by PowerUpResolver when this pickup is collected.
        /// </summary>
        public void Collect()
        {
            if (isCollected)
                return;
            isCollected = true;

            // Could add visual/audio feedback here

            Destroy(gameObject);
        }
    }
}
