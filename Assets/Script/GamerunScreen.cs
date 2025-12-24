using System;
using UnityEngine;
using UnityEngine.UIElements;

[RequireComponent(typeof(UIDocument))]
public class GamerunScreen : MonoBehaviour
{
    private UIDocument _uiDocument;

    private TextField _runningDistanceDisplayingTextField;
    private TextField _scoreDisplayingTextField;
    private Button _pauseButton;

    void Awake()
    {
        _uiDocument = GetComponent<UIDocument>();

        _runningDistanceDisplayingTextField = _uiDocument.rootVisualElement.Q<TextField>(
            "RunningDistance"
        );
        _scoreDisplayingTextField = _uiDocument.rootVisualElement.Q<TextField>("Score");
        _pauseButton = _uiDocument.rootVisualElement.Q<Button>("PauseButton");
    }

    public void Initialize(
        EventCallback<ChangeEvent<string>> onRunningDistanceChanged,
        EventCallback<ChangeEvent<string>> onScoreChanged,
        Action onPauseButtonClicked
    )
    {
        _runningDistanceDisplayingTextField.RegisterValueChangedCallback(onRunningDistanceChanged);
        _scoreDisplayingTextField.RegisterValueChangedCallback(onScoreChanged);
        _pauseButton.clicked += onPauseButtonClicked;
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
