using System;
using UnityEngine;
using UnityEngine.UIElements;

[RequireComponent(typeof(UIDocument))]
public class GameResultScreen : MonoBehaviour
{
    private const string BestScoreKey = "BestScore";
    private const string BestDistanceKey = "BestDistance";

    private UIDocument _uiDocument;

    private Label _scoreLabel;
    private Label _bestScoreLabel;
    private Label _distanceLabel;
    private Label _bestDistanceLabel;
    private Button _homeButton;
    private Button _restartButton;

    void Awake()
    {
        _uiDocument = GetComponent<UIDocument>();

        _scoreLabel = _uiDocument.rootVisualElement.Q<Label>("Score");
        _bestScoreLabel = _uiDocument.rootVisualElement.Q<Label>("BestScore");
        _distanceLabel = _uiDocument.rootVisualElement.Q<Label>("Distance");
        _bestDistanceLabel = _uiDocument.rootVisualElement.Q<Label>("BestDistance");
        _homeButton = _uiDocument.rootVisualElement.Q<Button>("HomeOption");
        _restartButton = _uiDocument.rootVisualElement.Q<Button>("RestartOption");
    }

    public void Initialize(Action onRestartClicked, Action onHomeClicked)
    {
        _restartButton.clicked += () => onRestartClicked?.Invoke();
        _homeButton.clicked += () => onHomeClicked?.Invoke();
    }

    public void SetResults(int score, int distance)
    {
        // Display current results
        _scoreLabel.text = score.ToString();
        _distanceLabel.text = distance.ToString();

        // Get and update best scores
        int bestScore = PlayerPrefs.GetInt(BestScoreKey, 0);
        int bestDistance = PlayerPrefs.GetInt(BestDistanceKey, 0);

        bool newBestScore = score > bestScore;
        bool newBestDistance = distance > bestDistance;

        if (newBestScore)
        {
            bestScore = score;
            PlayerPrefs.SetInt(BestScoreKey, bestScore);
        }

        if (newBestDistance)
        {
            bestDistance = distance;
            PlayerPrefs.SetInt(BestDistanceKey, bestDistance);
        }

        if (newBestScore || newBestDistance)
        {
            PlayerPrefs.Save();
        }

        // Display best scores
        _bestScoreLabel.text = bestScore.ToString();
        _bestDistanceLabel.text = bestDistance.ToString();
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
