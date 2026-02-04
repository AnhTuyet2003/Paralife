using Collectibles.Coins;
using Collectibles.PowerUps;
using UnityEngine;

namespace Collectibles
{
    /// <summary>
    /// Destroys collectibles that exit the camera bounds.
    /// Attach to a collider that tracks the camera view area.
    /// </summary>
    public class CollectibleBoundsCleaner : MonoBehaviour
    {
        private void OnTriggerExit2D(Collider2D other)
        {
            if (other.TryGetComponent<CollectibleCoin>(out var coin))
            {
                Destroy(coin.gameObject);
                return;
            }

            if (other.TryGetComponent<PowerUpPickup>(out var powerUp))
            {
                Destroy(powerUp.gameObject);
                return;
            }
        }
    }
}
