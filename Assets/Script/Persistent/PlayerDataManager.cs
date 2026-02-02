#nullable enable
using System;
using System.IO;
using UnityEngine;

namespace Persistent
{
    /// <summary>
    /// Manages player persistent data. Loads from and saves to JSON file.
    /// Use domain-specific accessors (PowerUps, etc.) for data operations.
    /// </summary>
    public class PlayerDataManager : MonoBehaviour
    {
        private const string SaveFileName = "playerdata.json";

        private PlayerData data = new();
        private PowerUpDataAccessor? powerUps;

        private string SaveFilePath => Path.Combine(Application.persistentDataPath, SaveFileName);

        public event Action? OnDataLoaded;
        public event Action? OnDataSaved;

        /// <summary>
        /// Access power-up progression data.
        /// </summary>
        public PowerUpDataAccessor PowerUps => powerUps ??= new PowerUpDataAccessor(data, Save);

        private void Awake()
        {
            Load();
        }

        /// <summary>
        /// Load player data from JSON file.
        /// Creates default data if file doesn't exist.
        /// </summary>
        public void Load()
        {
            if (File.Exists(SaveFilePath))
            {
                try
                {
                    string json = File.ReadAllText(SaveFilePath);
                    data = JsonUtility.FromJson<PlayerData>(json) ?? new PlayerData();
                    Debug.Log($"[PlayerDataManager] Loaded from {SaveFilePath}");
                }
                catch (Exception e)
                {
                    Debug.LogWarning(
                        $"[PlayerDataManager] Failed to load: {e.Message}. Using defaults."
                    );
                    data = new PlayerData();
                }
            }
            else
            {
                Debug.Log("[PlayerDataManager] No save file found. Using defaults.");
                data = new PlayerData();
            }

            // Recreate accessors with new data reference
            powerUps = new PowerUpDataAccessor(data, Save);

            OnDataLoaded?.Invoke();
        }

        /// <summary>
        /// Save player data to JSON file.
        /// </summary>
        public void Save()
        {
            try
            {
                string json = JsonUtility.ToJson(data, prettyPrint: true);
                File.WriteAllText(SaveFilePath, json);
                Debug.Log($"[PlayerDataManager] Saved to {SaveFilePath}");
                OnDataSaved?.Invoke();
            }
            catch (Exception e)
            {
                Debug.LogError($"[PlayerDataManager] Failed to save: {e.Message}");
            }
        }

        /// <summary>
        /// Reset all data to defaults and save.
        /// </summary>
        public void ResetData()
        {
            data = new PlayerData();
            powerUps = new PowerUpDataAccessor(data, Save);
            Save();
            Debug.Log("[PlayerDataManager] Data reset to defaults");
        }
    }
}
