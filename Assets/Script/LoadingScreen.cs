using UnityEngine;
using UnityEngine.UIElements;

[RequireComponent(typeof(UIDocument))]
public class LoadingScreen : MonoBehaviour
{
    private UIDocument _uiDocument;

    void Awake()
    {
        _uiDocument = GetComponent<UIDocument>();
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
