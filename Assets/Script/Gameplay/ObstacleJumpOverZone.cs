#nullable enable
using UnityEngine;

namespace Gameplay
{
    /// <summary>
    /// Attach to a child GameObject with a trigger Collider2D positioned above the obstacle.
    /// Detects when the player jumps over the obstacle.
    /// </summary>
    [RequireComponent(typeof(Collider2D))]
    public class ObstacleJumpOverZone : MonoBehaviour
    {
        private Obstacle? parentObstacle;

        private void Awake()
        {
            parentObstacle = GetComponentInParent<Obstacle>();
            if (parentObstacle == null)
            {
                Debug.LogError("[ObstacleJumpOverZone] No Obstacle component found in parent!");
            }

            // Ensure the collider is a trigger
            var collider = GetComponent<Collider2D>();
            if (!collider.isTrigger)
            {
                Debug.LogWarning("[ObstacleJumpOverZone] Collider should be set as trigger!");
                collider.isTrigger = true;
            }
        }

        private void OnTriggerExit2D(Collider2D other)
        {
            // Check if it's the player exiting (jumped over)
            if (!other.CompareTag("Player"))
                return;

            if (parentObstacle != null)
            {
                parentObstacle.NotifyPlayerJumpedOver();
            }
        }
    }
}
