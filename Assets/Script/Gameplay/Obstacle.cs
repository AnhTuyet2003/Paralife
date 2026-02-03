#nullable enable
using System;
using UnityEngine;

namespace Gameplay
{
    /// <summary>
    /// Represents an obstacle that can kill the player on collision.
    /// Must have "Obstacle" tag set in Unity.
    /// Can be destroyed by ProtectionCharm effect.
    /// Detects when player jumps over via a child trigger zone.
    /// </summary>
    [RequireComponent(typeof(Collider2D))]
    public class Obstacle : MonoBehaviour
    {
        [SerializeField]
        private int scoreValue = 10;

        [SerializeField]
        private GameObject? destructionEffectPrefab;

        private bool hasBeenJumpedOver;

        /// <summary>
        /// Static event fired when any obstacle is jumped over.
        /// Use this for runtime-generated obstacles.
        /// Passes the score value.
        /// </summary>
        public static event Action<int>? OnAnyObstacleJumpedOver;

        /// <summary>
        /// Instance event fired when this specific obstacle is jumped over.
        /// Passes this obstacle instance and its score value.
        /// </summary>
        public event Action<Obstacle, int>? OnPlayerJumpedOver;

        /// <summary>
        /// The score value awarded when jumping over this obstacle.
        /// </summary>
        public int ScoreValue => scoreValue;

        /// <summary>
        /// Called by ProtectionCharmEffect when negating collision with this obstacle.
        /// Destroys the obstacle with optional visual effects.
        /// </summary>
        public void DestroyByProtection()
        {
            if (destructionEffectPrefab != null)
            {
                Instantiate(destructionEffectPrefab, transform.position, Quaternion.identity);
            }

            Debug.Log($"[Obstacle] Destroyed by protection charm");
            Destroy(gameObject);
        }

        /// <summary>
        /// Called by the child JumpOverZone when player exits the trigger.
        /// </summary>
        public void NotifyPlayerJumpedOver()
        {
            if (hasBeenJumpedOver)
                return;

            hasBeenJumpedOver = true;
            Debug.Log($"[Obstacle] Player jumped over, awarding {scoreValue} points");
            OnPlayerJumpedOver?.Invoke(this, scoreValue);
            OnAnyObstacleJumpedOver?.Invoke(scoreValue);
        }
    }
}
