#nullable enable
using System;
using Collectibles;
using Collectibles.Coins;
using Collectibles.PowerUps;
using Gameplay;
using UnityEngine;

namespace Audio
{
    /// <summary>
    /// Centralized audio player that listens to game events and plays appropriate sounds.
    /// Manages both sound effects and background music with volume control.
    /// </summary>
    public class AudioPlayer : MonoBehaviour
    {
        private const string SfxVolumeKey = "SfxVolume";
        private const string MusicVolumeKey = "MusicVolume";

        [Header("Audio Sources")]
        [SerializeField]
        private AudioSource? sfxSource;

        [SerializeField]
        private AudioSource? musicSource;

        [Header("UI Sounds")]
        [SerializeField]
        private AudioClip? buttonClickSound;

        [Header("Gameplay Sounds")]
        [SerializeField]
        private AudioClip? coinCollectSound;

        [SerializeField]
        private AudioClip? powerUpCollectSound;

        [SerializeField]
        private AudioClip? powerUpExpiredSound;

        [Header("Death Sounds")]
        [SerializeField]
        private AudioClip? obstacleHitSound;

        [SerializeField]
        private AudioClip? holeFallSound;

        [Header("Background Music")]
        [SerializeField]
        private AudioClip? menuMusic;

        [SerializeField]
        private AudioClip? gameplayMusic;

        [Header("Event Sources")]
        [SerializeField]
        private CoinCollector? coinCollector;

        [SerializeField]
        private CollectibleObserver? collectibleObserver;

        [SerializeField]
        private PowerUpResolver? powerUpResolver;

        [SerializeField]
        private PlayerLoseConditionObserver? loseConditionObserver;

        private float sfxVolume = 1f;
        private float musicVolume = 1f;

        private void Awake()
        {
            LoadVolumeSettings();
        }

        private void Start()
        {
            SubscribeToEvents();
        }

        private void OnDestroy()
        {
            UnsubscribeFromEvents();
        }

        private void SubscribeToEvents()
        {
            if (coinCollector != null)
            {
                coinCollector.OnCoinValueCollected += OnCoinCollected;
            }

            if (collectibleObserver != null)
            {
                collectibleObserver.OnPowerUpCollected += OnPowerUpCollected;
            }

            if (powerUpResolver != null)
            {
                powerUpResolver.OnPowerUpDeactivated += OnPowerUpExpired;
            }

            if (loseConditionObserver != null)
            {
                loseConditionObserver.OnObstacleHit += OnObstacleHit;
                loseConditionObserver.OnHoleFall += OnHoleFall;
            }
        }

        private void UnsubscribeFromEvents()
        {
            if (coinCollector != null)
            {
                coinCollector.OnCoinValueCollected -= OnCoinCollected;
            }

            if (collectibleObserver != null)
            {
                collectibleObserver.OnPowerUpCollected -= OnPowerUpCollected;
            }

            if (powerUpResolver != null)
            {
                powerUpResolver.OnPowerUpDeactivated -= OnPowerUpExpired;
            }

            if (loseConditionObserver != null)
            {
                loseConditionObserver.OnObstacleHit -= OnObstacleHit;
                loseConditionObserver.OnHoleFall -= OnHoleFall;
            }
        }

        private void LoadVolumeSettings()
        {
            sfxVolume = PlayerPrefs.GetInt(SfxVolumeKey, 100) / 100f;
            musicVolume = PlayerPrefs.GetInt(MusicVolumeKey, 100) / 100f;
            ApplyVolumeSettings();
        }

        private void ApplyVolumeSettings()
        {
            if (sfxSource != null)
            {
                sfxSource.volume = sfxVolume;
            }

            if (musicSource != null)
            {
                musicSource.volume = musicVolume;
            }
        }

        #region Volume Control

        public float SfxVolume => sfxVolume;
        public float MusicVolume => musicVolume;

        public void SetSfxVolume(int volumePercent)
        {
            sfxVolume = Mathf.Clamp01(volumePercent / 100f);
            PlayerPrefs.SetInt(SfxVolumeKey, volumePercent);
            PlayerPrefs.Save();
            ApplyVolumeSettings();
        }

        public void SetMusicVolume(int volumePercent)
        {
            musicVolume = Mathf.Clamp01(volumePercent / 100f);
            PlayerPrefs.SetInt(MusicVolumeKey, volumePercent);
            PlayerPrefs.Save();
            ApplyVolumeSettings();
        }

        #endregion

        #region Music Control

        public void PlayMenuMusic()
        {
            PlayMusic(menuMusic);
        }

        public void PlayGameplayMusic()
        {
            PlayMusic(gameplayMusic);
        }

        public void StopMusic()
        {
            if (musicSource != null)
            {
                musicSource.Stop();
            }
        }

        private void PlayMusic(AudioClip? clip)
        {
            if (musicSource == null || clip == null)
                return;

            if (musicSource.clip == clip && musicSource.isPlaying)
                return;

            musicSource.clip = clip;
            musicSource.loop = true;
            musicSource.Play();
        }

        #endregion

        #region Sound Effects

        public void PlayButtonClick()
        {
            PlaySfx(buttonClickSound);
        }

        private void OnCoinCollected(int value)
        {
            PlaySfx(coinCollectSound);
        }

        private void OnPowerUpCollected(PowerUpPickup pickup)
        {
            PlaySfx(powerUpCollectSound);
        }

        private void OnPowerUpExpired(PowerUpType type)
        {
            PlaySfx(powerUpExpiredSound);
        }

        private void OnObstacleHit(string tag)
        {
            PlaySfx(obstacleHitSound);
        }

        private void OnHoleFall()
        {
            PlaySfx(holeFallSound);
        }

        private void PlaySfx(AudioClip? clip)
        {
            if (sfxSource == null || clip == null)
                return;

            sfxSource.PlayOneShot(clip, sfxVolume);
        }

        #endregion
    }
}
