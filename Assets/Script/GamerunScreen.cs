using System;
using Gameplay;
using UnityEngine;
using UnityEngine.UIElements;

[RequireComponent(typeof(UIDocument))]
public class GamerunScreen : MonoBehaviour
{
    private UIDocument _uiDocument;

    private Label _runningDistanceDisplayingLabel;
    private Label _scoreDisplayingLabel;
    private Button _pauseButton;

    private RunProgressTracker _progressTracker;

    void Awake()
    {
        _uiDocument = GetComponent<UIDocument>();

        _runningDistanceDisplayingLabel = _uiDocument.rootVisualElement.Q<Label>("RunningDistance");
        _scoreDisplayingLabel = _uiDocument.rootVisualElement.Q<Label>("Score");
        _pauseButton = _uiDocument.rootVisualElement.Q<Button>("PauseButton");
    }

    public void Initialize(Action onPauseButtonClicked, RunProgressTracker progressTracker)
    {
        _pauseButton.clicked += onPauseButtonClicked;

        _progressTracker = progressTracker;
        if (_progressTracker != null)
        {
            _progressTracker.OnDistanceChanged += SetDistanceValue;
            _progressTracker.OnScoreChanged += SetScoreValue;
        }
    }

    private void OnDestroy()
    {
        if (_progressTracker != null)
        {
            _progressTracker.OnDistanceChanged -= SetDistanceValue;
            _progressTracker.OnScoreChanged -= SetScoreValue;
        }
    }

    /// <summary>Sets the distance display value without triggering callbacks.</summary>
    public void SetDistanceValue(int value)
    {
        _runningDistanceDisplayingLabel.text = $"{value}m";
    }

    /// <summary>Sets the score display value without triggering callbacks.</summary>
    public void SetScoreValue(int value)
    {
        _scoreDisplayingLabel.text = value.ToString();
    }

    public void Show()
    {
        _uiDocument.rootVisualElement.style.display = DisplayStyle.Flex;
    }

    public void Hide()
    {
        _uiDocument.rootVisualElement.style.display = DisplayStyle.None;
    }
}
