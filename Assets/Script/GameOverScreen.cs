using UnityEngine;
using UnityEngine.UI;
using TMPro; // Dùng cái này nếu bạn dùng TextMeshPro, nếu dùng Text thường thì xóa dòng này

public class GameOverScreen : MonoBehaviour
{
    [Header("UI Components")]
    [SerializeField] private TextMeshProUGUI scoreText; // Hoặc dùng Text nếu không dùng TMP
    [SerializeField] private TextMeshProUGUI highScoreText; 
    [SerializeField] private Button restartButton;
    [SerializeField] private Button homeButton;

    // Hàm khởi tạo, gán chức năng cho nút bấm
    public void Initialize(System.Action onRestartClicked, System.Action onHomeClicked)
    {
        restartButton.onClick.AddListener(() => onRestartClicked?.Invoke());
        homeButton.onClick.AddListener(() => onHomeClicked?.Invoke());
    }

    public void SetScore(float currentScore)
    {
        // Hiển thị điểm hiện tại
        scoreText.text = "Score: " + Mathf.FloorToInt(currentScore).ToString();

        // Xử lý lưu điểm cao nhất (High Score)
        float bestScore = PlayerPrefs.GetFloat("HighScore", 0);
        
        if (currentScore > bestScore)
        {
            bestScore = currentScore;
            PlayerPrefs.SetFloat("HighScore", bestScore);
            PlayerPrefs.Save(); // Lưu xuống ổ cứng
        }

        if (highScoreText != null)
        {
            highScoreText.text = "Best: " + Mathf.FloorToInt(bestScore).ToString();
        }
    }

    public void Show() => gameObject.SetActive(true);
    public void Hide() => gameObject.SetActive(false);
}