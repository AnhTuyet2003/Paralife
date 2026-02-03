using System;
using UnityEngine;
using UnityEngine.UIElements;

[RequireComponent(typeof(UIDocument))]
public class PauseScreen : MonoBehaviour
{
    private UIDocument _uiDocument;
    private Button _homeButton;
    private Button _restartButton;
    private Button _resumeButton;

    void Awake()
    {
        _uiDocument = GetComponent<UIDocument>();

        _homeButton = _uiDocument.rootVisualElement.Q<Button>("HomeOption");
        _restartButton = _uiDocument.rootVisualElement.Q<Button>("RestartOption");
        _resumeButton = _uiDocument.rootVisualElement.Q<Button>("ResumeOption");
    }

    public void Initialize(
        Action onHomeButtonClicked,
        Action onRestartButtonClicked,
        Action onResumeButtonClicked
    )
    {
        _homeButton.clicked += onHomeButtonClicked;
        _restartButton.clicked += onRestartButtonClicked;
        _resumeButton.clicked += onResumeButtonClicked;
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
