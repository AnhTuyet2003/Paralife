#nullable enable
using UnityEngine;

namespace Collectibles.PowerUps
{
    /// <summary>
    /// Attracts nearby collectibles toward the player.
    /// </summary>
    public class MagnetEffect : PowerUpEffectBase
    {
        public override PowerUpType Type => PowerUpType.Magnet;
        public override bool HasDuration => true;

        private readonly MagnetConfigSO.LevelData levelData;
        private readonly string[] attractableTags;
        private readonly GameObject? magnetVisualPrefab;
        private GameObject? magnetVisualInstance;

        public MagnetEffect(
            MagnetConfigSO.LevelData levelData,
            string[] attractableTags,
            GameObject? magnetVisualPrefab
        )
        {
            this.levelData = levelData;
            this.attractableTags = attractableTags;
            this.magnetVisualPrefab = magnetVisualPrefab;
        }

        public override void Apply(CatMove player)
        {
            base.Apply(player);

            if (magnetVisualPrefab != null)
            {
                magnetVisualInstance = Object.Instantiate(magnetVisualPrefab, player.transform);
            }

            Debug.Log(
                $"[Magnet] Applied with radius {levelData.attractionRadius}, speed {levelData.attractionSpeed}"
            );
        }

        public override void Cancel()
        {
            base.Cancel();

            if (magnetVisualInstance != null)
            {
                Object.Destroy(magnetVisualInstance);
                magnetVisualInstance = null;
            }
        }

        public override void Update(CatMove player, float deltaTime, float remainingDuration)
        {
            if (!isActive)
                return;

            // Find collectibles in radius
            Collider2D[] colliders = Physics2D.OverlapCircleAll(
                player.transform.position,
                levelData.attractionRadius
            );

            foreach (var collider in colliders)
            {
                if (IsAttractable(collider.gameObject))
                {
                    // Move toward player
                    Vector3 direction = (
                        player.transform.position - collider.transform.position
                    ).normalized;
                    collider.transform.position +=
                        deltaTime * levelData.attractionSpeed * direction;
                }
            }
        }

        private bool IsAttractable(GameObject obj)
        {
            foreach (string tag in attractableTags)
            {
                if (obj.CompareTag(tag))
                    return true;
            }
            return false;
        }
    }
}
