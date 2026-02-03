#nullable enable
using System;
using UnityEngine;

namespace Collectibles.Coins
{
    /// <summary>
    /// Tracks coins collected in the current level.
    /// Subscribes to CollectibleObserver and exposes events for UI.
    /// </summary>
    public class CoinCollector : MonoBehaviour
    {
        [SerializeField]
        private CollectibleObserver? collectibleObserver;

        private int totalCoinsCollected;

        public int TotalCoinsCollected => totalCoinsCollected;

        public event Action<int>? OnCoinAmountChanged;

        private void Start()
        {
            if (collectibleObserver != null)
            {
                collectibleObserver.OnCoinCollected += HandleCoinCollected;
            }
        }

        private void OnDestroy()
        {
            if (collectibleObserver != null)
            {
                collectibleObserver.OnCoinCollected -= HandleCoinCollected;
            }
        }

        private void HandleCoinCollected(CollectibleCoin coin)
        {
            int value = coin.Collect();
            totalCoinsCollected += value;
            OnCoinAmountChanged?.Invoke(totalCoinsCollected);
        }

        public void ResetCoins()
        {
            totalCoinsCollected = 0;
            OnCoinAmountChanged?.Invoke(totalCoinsCollected);
        }
    }
}
