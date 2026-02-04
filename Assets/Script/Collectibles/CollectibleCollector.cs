using System;
using Collectibles.Coins;
using Collectibles.PowerUps;
using UnityEngine;

namespace Collectibles
{
    /// <summary>
    /// Attach to Player GameObject. Receives OnTriggerEnter2D events,
    /// checks for Coin/PowerUp components, and broadcasts collection events.
    /// </summary>
    public class CollectibleObserver : MonoBehaviour
    {
        /// <summary>
        /// Fired when player collects a coin.
        /// </summary>
        public event Action<CollectibleCoin> OnCoinCollected;

        /// <summary>
        /// Fired when player collects a power-up pickup.
        /// </summary>
        public event Action<PowerUpPickup> OnPowerUpCollected;

        private void OnTriggerEnter2D(Collider2D other)
        {
            // Check for Coin component
            if (other.TryGetComponent<CollectibleCoin>(out var coin))
            {
                OnCoinCollected?.Invoke(coin);
                return;
            }

            // Check for PowerUp component
            if (other.TryGetComponent<PowerUpPickup>(out var powerUp))
            {
                OnPowerUpCollected?.Invoke(powerUp);
                return;
            }
        }
    }
}
