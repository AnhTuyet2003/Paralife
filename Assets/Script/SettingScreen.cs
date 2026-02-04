#nullable enable
using System;
using Audio;
using UnityEngine;
using UnityEngine.UIElements;

[RequireComponent(typeof(UIDocument))]
public class SettingScreen : MonoBehaviour
{
    private const string SfxVolumeKey = "SfxVolume";
    private const string MusicVolumeKey = "MusicVolume";

    private UIDocument _uiDocument = null!;

    private SliderInt _sfxVolumeSlider = null!;
    private SliderInt _musicVolumeSlider = null!;
    private Button _returnButton = null!;
    private Button _applyButton = null!;

    private AudioPlayer? _audioPlayer;
    private Action? _onReturnClicked;

    void Awake()
    {
        _uiDocument = GetComponent<UIDocument>();

        _sfxVolumeSlider = _uiDocument.rootVisualElement.Q<SliderInt>("SoundEffectVolumeSlider");
        _musicVolumeSlider = _uiDocument.rootVisualElement.Q<SliderInt>("MusicVolumeSlider");
        _returnButton = _uiDocument.rootVisualElement.Q<Button>("ReturnOption");
        _applyButton = _uiDocument.rootVisualElement.Q<Button>("ApplyOption");

        _returnButton.clicked += OnReturnButtonClicked;
        _applyButton.clicked += OnApplyButtonClicked;
    }

    public void Initialize(Action onReturnClicked, AudioPlayer? audioPlayer)
    {
        _onReturnClicked = onReturnClicked;
        _audioPlayer = audioPlayer;
    }

    public void Show()
    {
        LoadSettings();
        _uiDocument.rootVisualElement.style.display = DisplayStyle.Flex;
    }

    public void Hide()
    {
        _uiDocument.rootVisualElement.style.display = DisplayStyle.None;
    }

    private void LoadSettings()
    {
        int sfxVolume = PlayerPrefs.GetInt(SfxVolumeKey, 100);
        int musicVolume = PlayerPrefs.GetInt(MusicVolumeKey, 100);

        _sfxVolumeSlider.value = sfxVolume;
        _musicVolumeSlider.value = musicVolume;
    }

    private void OnApplyButtonClicked()
    {
        int sfxVolume = _sfxVolumeSlider.value;
        int musicVolume = _musicVolumeSlider.value;

        PlayerPrefs.SetInt(SfxVolumeKey, sfxVolume);
        PlayerPrefs.SetInt(MusicVolumeKey, musicVolume);
        PlayerPrefs.Save();

        if (_audioPlayer != null)
        {
            _audioPlayer.SetSfxVolume(sfxVolume);
            _audioPlayer.SetMusicVolume(musicVolume);
        }

        Debug.Log($"[SettingScreen] Applied settings - SFX: {sfxVolume}%, Music: {musicVolume}%");
    }

    private void OnReturnButtonClicked()
    {
        _onReturnClicked?.Invoke();
    }
}
