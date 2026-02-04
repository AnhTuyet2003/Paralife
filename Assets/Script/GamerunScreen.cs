using System;
using UnityEngine;
using UnityEngine.UIElements;

[RequireComponent(typeof(UIDocument))]
public class GamerunScreen : MonoBehaviour
{
    private UIDocument _uiDocument;

    private Label _runningDistanceDisplayingLabel;
    private Label _scoreDisplayingLabel;
    private Button _pauseButton;

    void Awake()
    {
        _uiDocument = GetComponent<UIDocument>();

        _runningDistanceDisplayingLabel = _uiDocument.rootVisualElement.Q<Label>("RunningDistance");
        _scoreDisplayingLabel = _uiDocument.rootVisualElement.Q<Label>("Score");
        _pauseButton = _uiDocument.rootVisualElement.Q<Button>("PauseButton");

        // TODO: Show the score if the score system is implemented
        _scoreDisplayingLabel.style.display = DisplayStyle.None;
    }

    public void Initialize(Action onPauseButtonClicked)
    {
        _pauseButton.clicked += onPauseButtonClicked;
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
