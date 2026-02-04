using System;

namespace Collectibles.PowerUps
{
    /// <summary>
    /// Command pattern interface for power-up effects.
    /// Each power-up is a POCO that defines its effect behavior.
    /// Duration and lifecycle are managed by PowerUpResolver.
    /// </summary>
    public interface IPowerUpEffect
    {
        /// <summary>
        /// Unique identifier for stacking logic and catalog lookup.
        /// </summary>
        PowerUpType Type { get; }

        /// <summary>
        /// False for usage-based effects, True for timed effects.
        /// </summary>
        bool HasDuration { get; }

        /// <summary>
        /// Apply the effect to the player.
        /// Called by PowerUpResolver when activating.
        /// </summary>
        void Apply(CatMove player);

        /// <summary>
        /// Cancel/cleanup the effect.
        /// Called by PowerUpResolver when deactivating.
        /// </summary>
        void Cancel();

        /// <summary>
        /// Called each frame while active.
        /// Resolver passes remaining duration for effects that need it.
        /// </summary>
        /// <param name="player">The player to apply the effect to</param>
        /// <param name="deltaTime">Time since last frame</param>
        /// <param name="remainingDuration">Remaining duration in seconds (managed by resolver)</param>
        void Update(CatMove player, float deltaTime, float remainingDuration);

        /// <summary>
        /// Called by resolver when duration expires (for cleanup before Cancel).
        /// </summary>
        void OnExpired();

        /// <summary>
        /// Fired when effect is no longer effective (e.g., charm depleted).
        /// PowerUpResolver subscribes to this to clean up.
        /// </summary>
        event Action<IPowerUpEffect> OnEffectDepleted;
    }
}
