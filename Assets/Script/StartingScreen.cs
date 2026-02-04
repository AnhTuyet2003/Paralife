using System;
using UnityEngine;
using UnityEngine.UIElements;

[RequireComponent(typeof(UIDocument))]
public class StartingScreen : MonoBehaviour
{
    private UIDocument _uiDocument;

    private Button _startButton;

    private Action _onStartButtonClicked;

    private void Awake()
    {
        _uiDocument = GetComponent<UIDocument>();

        _startButton = _uiDocument.rootVisualElement.Q<Button>("TapToPlayArea");
        _startButton.RegisterCallback<ClickEvent>(ev => OnStartButtonClicked());
    }

    public void Initialize(Action onStartButtonClicked)
    {
        _onStartButtonClicked = onStartButtonClicked;
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
