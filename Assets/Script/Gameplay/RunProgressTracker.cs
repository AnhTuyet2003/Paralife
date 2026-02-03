#nullable enable
using System;
using Collectibles.Coins;
using UnityEngine;

namespace Gameplay
{
    /// <summary>
    /// Tracks distance traveled and score accumulated during a run.
    /// Subscribes to CoinCollector for score updates from coins.
    /// Subscribes to Obstacle.OnAnyObstacleJumpedOver for obstacle score.
    /// </summary>
    public class RunProgressTracker : MonoBehaviour
    {
        [SerializeField]
        private Transform? playerTransform;

        [SerializeField]
        private CoinCollector? coinCollector;

        private Vector3 spawnPosition;
        private int lastBroadcastedDistance = -1;
        private bool isTracking;

        public int CurrentDistance { get; private set; }
        public int CurrentScore { get; private set; }

        public event Action<int>? OnDistanceChanged;
        public event Action<int>? OnScoreChanged;

        private void Start()
        {
            if (coinCollector != null)
            {
                coinCollector.OnCoinValueCollected += HandleScoreAdded;
            }

            Obstacle.OnAnyObstacleJumpedOver += HandleScoreAdded;
        }

        private void OnDestroy()
        {
            if (coinCollector != null)
            {
                coinCollector.OnCoinValueCollected -= HandleScoreAdded;
            }

            Obstacle.OnAnyObstacleJumpedOver -= HandleScoreAdded;
        }

        private void Update()
        {
            if (!isTracking || playerTransform == null)
                return;

            UpdateDistance();
        }

        public void StartTracking(Vector3 startPosition)
        {
            spawnPosition = startPosition;
            isTracking = true;
            Reset();
        }

        public void StopTracking()
        {
            isTracking = false;
        }

        public void Reset()
        {
            CurrentDistance = 0;
            CurrentScore = 0;
            lastBroadcastedDistance = -1;
            OnDistanceChanged?.Invoke(CurrentDistance);
            OnScoreChanged?.Invoke(CurrentScore);
        }

        private void UpdateDistance()
        {
            if (playerTransform == null)
                return;

            float newDistance = Mathf.Max(0f, playerTransform.position.x - spawnPosition.x);
            int flooredDistance = Mathf.FloorToInt(newDistance);

            if (flooredDistance != lastBroadcastedDistance)
            {
                CurrentDistance = flooredDistance;
                lastBroadcastedDistance = flooredDistance;
                OnDistanceChanged?.Invoke(CurrentDistance);
            }
        }

        private void HandleScoreAdded(int value)
        {
            CurrentScore += value;
            OnScoreChanged?.Invoke(CurrentScore);
        }
    }
}
