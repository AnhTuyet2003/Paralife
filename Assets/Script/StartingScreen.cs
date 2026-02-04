using System;
using UnityEngine;
using UnityEngine.UIElements;

[RequireComponent(typeof(UIDocument))]
public class StartingScreen : MonoBehaviour
{
    private UIDocument _uiDocument;

    private Button _startButton;
    private Button _settingsButton;

    private Action _onStartButtonClicked;
    private Action _onSettingsButtonClicked;

    private void Awake()
    {
        _uiDocument = GetComponent<UIDocument>();

        _startButton = _uiDocument.rootVisualElement.Q<Button>("TapToPlayArea");
        _settingsButton = _uiDocument.rootVisualElement.Q<Button>("PauseButton");

        _startButton.RegisterCallback<ClickEvent>(ev => OnStartButtonClicked());
        _settingsButton.clicked += () => _onSettingsButtonClicked?.Invoke();
    }

    public void Initialize(Action onStartButtonClicked, Action onSettingsButtonClicked)
    {
        _onStartButtonClicked = onStartButtonClicked;
        _onSettingsButtonClicked = onSettingsButtonClicked;
    }

    public void Show()
    {
        _uiDocument.rootVisualElement.style.display = DisplayStyle.Flex;
    }

    public void Hide()
    {
        _uiDocument.rootVisualElement.style.display = DisplayStyle.None;
    }

    private void OnStartButtonClicked()
    {
        _onStartButtonClicked?.Invoke();
    }
}
