using System;
using UnityEngine;

namespace Collectibles.PowerUps
{
    /// <summary>
    /// Base class providing common functionality for power-up effects.
    /// Derived classes implement specific effect behavior.
    /// </summary>
    public abstract class PowerUpEffectBase : IPowerUpEffect
    {
        public abstract PowerUpType Type { get; }
        public virtual bool HasDuration => true;

        public event Action<IPowerUpEffect> OnEffectDepleted;

        protected bool isActive;

        public virtual void Apply(CatMove player)
        {
            isActive = true;
            Debug.Log($"[PowerUp] {Type} applied");
        }

        public virtual void Cancel()
        {
            isActive = false;
            Debug.Log($"[PowerUp] {Type} cancelled");
        }

        public virtual void Update(CatMove player, float deltaTime, float remainingDuration)
        {
            // Override in derived classes for per-frame logic
        }

        public virtual void OnExpired()
        {
            Debug.Log($"[PowerUp] {Type} expired");
        }

        /// <summary>
        /// Call this to signal that the effect is no longer effective.
        /// PowerUpResolver will clean up in response.
        /// </summary>
        protected void InvokeOnEffectDepleted()
        {
            OnEffectDepleted?.Invoke(this);
        }
    }
}
