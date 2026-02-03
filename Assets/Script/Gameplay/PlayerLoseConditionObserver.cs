using System;
using UnityEngine;

namespace Gameplay
{
    /// <summary>
    /// Attach to Player GameObject. Receives OnCollisionEnter2D events,
    /// checks for Obstacle/Hole tags, allows negation, and broadcasts lose condition events.
    /// </summary>
    public class PlayerLoseConditionObserver : MonoBehaviour
    {
        /// <summary>
        /// Fired when player hits an obstacle. Passes the tag.
        /// </summary>
        public event Action<string> OnObstacleHit;

        /// <summary>
        /// Fired when player falls into a hole.
        /// </summary>
        public event Action OnHoleFall;

        /// <summary>
        /// Injected by effects (e.g., ProtectionCharm) to negate collisions at runtime.
        /// Receives the full Collision2D to access the collided object.
        /// Return true to negate the collision.
        /// </summary>
        public Func<Collision2D, bool> CollisionNegator;

        private void OnCollisionEnter2D(Collision2D collision)
        {
            string tag = collision.gameObject.tag;

            // Only handle lose conditions
            if (tag != "Obstacle" && tag != "Hole")
                return;

            // Check if any effect wants to negate this collision
            if (CollisionNegator != null && CollisionNegator(collision))
                return; // Negated, don't propagate

            // Broadcast the appropriate event
            if (tag == "Hole")
                OnHoleFall?.Invoke();
            else
                OnObstacleHit?.Invoke(tag);
        }
    }
}
