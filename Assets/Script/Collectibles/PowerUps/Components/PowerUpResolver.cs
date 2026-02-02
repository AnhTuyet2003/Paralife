#nullable enable
using System;
using System.Collections.Generic;
using Persistent;
using UnityEngine;

namespace Collectibles.PowerUps
{
    /// <summary>
    /// Manages active power-up effects: activation, duration tracking, expiration, spawning.
    /// </summary>
    public class PowerUpResolver : MonoBehaviour
    {
        [SerializeField]
        private CatMove? player;

        [SerializeField]
        private PowerUpCatalog? catalog;

        [SerializeField]
        private Transform? spawnContainer;

        private PowerUpDataAccessor? powerUpData;

        private readonly Dictionary<PowerUpType, IPowerUpEffect> activeEffects = new();
        private readonly Dictionary<PowerUpType, float?> remainingDurations = new();

        public event Action<PowerUpType>? OnPowerUpActivated;
        public event Action<PowerUpType>? OnPowerUpDeactivated;

        private void Start()
        {
            if (player == null)
                player = FindObjectOfType<CatMove>();

            if (catalog == null)
                catalog = FindObjectOfType<PowerUpCatalog>();

            var playerDataManager = FindObjectOfType<PlayerDataManager>();
            if (playerDataManager != null)
                powerUpData = playerDataManager.PowerUps;

            // Subscribe to collectible observer for automatic activation
            var collectibleObserver =
                player != null ? player.GetComponent<CollectibleObserver>() : null;
            if (collectibleObserver != null)
            {
                collectibleObserver.OnPowerUpCollected += OnPowerUpPickedUp;
            }
        }

        private void OnDestroy()
        {
            // Unsubscribe
            var collectibleObserver =
                player != null ? player.GetComponent<CollectibleObserver>() : null;
            if (collectibleObserver != null)
            {
                collectibleObserver.OnPowerUpCollected -= OnPowerUpPickedUp;
            }

            // Cancel all active effects
            CancelAllPowerUps();
        }

        private void Update()
        {
            var toRemove = new List<PowerUpType>();

            foreach (var kvp in activeEffects)
            {
                var type = kvp.Key;
                var effect = kvp.Value;

                float? remaining = remainingDurations.TryGetValue(type, out var r) ? r : null;

                // Decrement duration for timed effects (only if duration is not null/infinite)
                if (effect.HasDuration && remaining.HasValue)
                {
                    remaining = remaining.Value - Time.deltaTime;
                    remainingDurations[type] = remaining;
                }

                // Update the effect (pass 0 if infinite duration)
                if (player != null)
                    effect.Update(player, Time.deltaTime, remaining ?? 0f);

                // Check expiration (only for effects with finite duration)
                if (effect.HasDuration && remaining.HasValue && remaining.Value <= 0)
                {
                    effect.OnExpired();
                    toRemove.Add(type);
                }
            }

            // Remove expired effects
            foreach (var type in toRemove)
            {
                RemoveEffect(type);
            }
        }

        private void OnPowerUpPickedUp(PowerUpPickup pickup)
        {
            ActivatePowerUp(pickup.PowerUpType);
            pickup.Collect();
        }

        /// <summary>
        /// Activate a power-up using the player's current level for that type.
        /// </summary>
        public void ActivatePowerUp(PowerUpType type)
        {
            int level = powerUpData?.GetLevel(type) ?? 1;
            ActivatePowerUp(type, level);
        }

        /// <summary>
        /// Activate a power-up at a specific level (for testing or special cases).
        /// If same type is active, refreshes duration instead (if it has duration).
        /// </summary>
        public void ActivatePowerUp(PowerUpType type, int level)
        {
            float? duration = catalog != null ? catalog.GetDuration(type, level) : null;

            // Stacking: refresh duration if already active
            if (activeEffects.TryGetValue(type, out var existing))
            {
                if (existing.HasDuration && duration.HasValue)
                {
                    remainingDurations[type] = duration;
                    Debug.Log($"[PowerUpResolver] {type} duration refreshed to {duration}s");
                }
                return;
            }

            // Create and apply new effect
            if (catalog == null || player == null)
                return;

            var effect = catalog.CreateEffect(type, level);
            if (effect == null)
                return;

            effect.OnEffectDepleted += OnEffectDepleted;
            activeEffects[type] = effect;
            remainingDurations[type] = duration; // null for infinite duration
            effect.Apply(player);

            OnPowerUpActivated?.Invoke(type);

            string durationStr = duration.HasValue ? $"{duration}s" : "infinite";
            Debug.Log(
                $"[PowerUpResolver] {type} activated at level {level}, duration: {durationStr}"
            );
        }

        /// <summary>
        /// Cancel a specific power-up type.
        /// </summary>
        public void CancelPowerUp(PowerUpType type)
        {
            if (!activeEffects.ContainsKey(type))
                return;
            RemoveEffect(type);
        }

        /// <summary>
        /// Cancel all active power-ups.
        /// </summary>
        public void CancelAllPowerUps()
        {
            var types = new List<PowerUpType>(activeEffects.Keys);
            foreach (var type in types)
            {
                RemoveEffect(type);
            }
        }

        /// <summary>
        /// Check if a power-up type is currently active.
        /// </summary>
        public bool IsPowerUpActive(PowerUpType type) => activeEffects.ContainsKey(type);

        /// <summary>
        /// Get remaining duration for a power-up type.
        /// Returns null if not active or if infinite duration.
        /// </summary>
        public float? GetRemainingDuration(PowerUpType type)
        {
            return remainingDurations.TryGetValue(type, out var r) ? r : null;
        }

        /// <summary>
        /// Spawn a power-up pickup at the specified position.
        /// </summary>
        public PowerUpPickup? SpawnPowerUp(PowerUpType type, Vector3 position)
        {
            var config = catalog != null ? catalog.GetConfig(type) : null;
            if (config == null || config.pickupPrefab == null)
            {
                Debug.LogWarning(
                    $"[PowerUpResolver] Cannot spawn {type}: missing config or prefab"
                );
                return null;
            }

            var parent = spawnContainer != null ? spawnContainer : transform;
            var obj = Instantiate(config.pickupPrefab, position, Quaternion.identity, parent);

            if (!obj.TryGetComponent<PowerUpPickup>(out var pickup))
            {
                pickup = obj.AddComponent<PowerUpPickup>();
            }
            pickup.Initialize(type);

            Debug.Log($"[PowerUpResolver] Spawned {type} at {position}");
            return pickup;
        }

        private void OnEffectDepleted(IPowerUpEffect effect)
        {
            RemoveEffect(effect.Type);
        }

        private void RemoveEffect(PowerUpType type)
        {
            if (!activeEffects.TryGetValue(type, out var effect))
                return;

            effect.OnEffectDepleted -= OnEffectDepleted;
            effect.Cancel();
            activeEffects.Remove(type);
            remainingDurations.Remove(type);

            OnPowerUpDeactivated?.Invoke(type);
            Debug.Log($"[PowerUpResolver] {type} deactivated");
        }
    }
}
