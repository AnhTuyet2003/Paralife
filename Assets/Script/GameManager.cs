using Cysharp.Threading.Tasks;
using UnityEngine;
using UnityEngine.EventSystems;

public class GameManager : MonoBehaviour
{
    public enum GameState
    {
        STARTING,
        RUNNING,
        PAUSED,
        DEAD,
    }

    #region Public API

    /// <summary>Event fired when game needs to reset (scene reload).</summary>
    public event System.Action OnGameReset;

    /// <summary>Gets the current game state.</summary>
    public GameState GetCurrentState() => currentState;

    /// <summary>Gets the current distance traveled.</summary>
    public float GetCurrentDistance() => currentDistance;

    /// <summary>Gets the current score.</summary>
    public float GetCurrentScore() => currentScore;

    /// <summary>Adds points to the score and broadcasts the change.</summary>
    public void AddScore(float points)
    {
        currentScore += points;
        if (Mathf.Abs(currentScore - lastBroadcastedScore) > 0.01f)
        {
            lastBroadcastedScore = currentScore;
            gamerunScreen.SetScoreValue(Mathf.FloorToInt(currentScore));
        }
    }

    #endregion

    //---------------------------------------------------------------------------------------------

    #region Private Fields

    [SerializeField]
    private CatMove catPlayer;

    [SerializeField]
    private Transform catSpawnPoint;

    [SerializeField]
    private StartingScreen startingScreenPrefab;

    [SerializeField]
    private GamerunScreen gamerunScreenPrefab;

    [SerializeField]
    private PauseScreen pauseScreenPrefab;

    [SerializeField]
    private GameOverScreen gameOverScreenPrefab; 

    private GameOverScreen gameOverScreen; 

    private GameState currentState = GameState.STARTING;

    private StartingScreen startingScreen;
    private GamerunScreen gamerunScreen;
    private PauseScreen pauseScreen;

    private float initialCatMaxSpeed;
    private Vector3 spawnPositionOffset;
    private float currentDistance = 0f;
    private float currentScore = 0f;
    private float lastBroadcastedDistance = -1f;
    private float lastBroadcastedScore = -1f;

    #endregion

    //---------------------------------------------------------------------------------------------

    #region Lifecycle

    void Awake()
    {
        // Validate all inspector fields
        if (catPlayer == null)
        {
            Debug.LogError("GameManager: CatMove reference is not assigned!");
            return;
        }

        if (catSpawnPoint == null)
        {
            Debug.LogError("GameManager: Cat spawn point is not assigned!");
            return;
        }

        if (
            startingScreenPrefab == null
            || gamerunScreenPrefab == null
            || pauseScreenPrefab == null
        )
        {
            Debug.LogError("GameManager: One or more screen prefabs are not assigned!");
            return;
        }

        // Store initial cat max speed
        initialCatMaxSpeed = catPlayer.maxSpeed;

        // Set cat to spawn point and disable movement
        catPlayer.transform.SetPositionAndRotation(catSpawnPoint.position, catSpawnPoint.rotation);
        catPlayer.maxSpeed = 0f;

        // Store spawn position for distance calculation
        spawnPositionOffset = catPlayer.transform.position;

        // Instantiate screen prefabs
        startingScreen = Instantiate(startingScreenPrefab);
        gamerunScreen = Instantiate(gamerunScreenPrefab);
        pauseScreen = Instantiate(pauseScreenPrefab);
        gameOverScreen = Instantiate(gameOverScreenPrefab);

        // Initialize screens with callbacks
        startingScreen.Initialize(OnStartButtonClicked);
        gamerunScreen.Initialize(OnPauseButtonClicked);
        pauseScreen.Initialize(OnHomeButtonClicked, OnRestartButtonClicked, OnResumeButtonClicked);
        gameOverScreen.Initialize(OnRestartButtonClicked, OnHomeButtonClicked);

        // Subscribe to cat collision events
        catPlayer.OnObstacleHit += OnCatCollided;

        // Show only starting screen
        startingScreen.Show();
        gamerunScreen.Hide();
        pauseScreen.Hide();
        gameOverScreen.Hide();

        Debug.Log("GameManager: Initialized successfully");
    }

    void Start()
    {
        // Additional setup if needed
        currentState = GameState.STARTING;
        currentDistance = 0f;
        currentScore = 0f;
    }

    void Update()
    {
        if (currentState != GameState.RUNNING)
        {
            return;
        }

        UpdateDistance();
        UpdateScore();
    }

    void OnDestroy()
    {
        // Unsubscribe from cat collision events
        if (catPlayer != null)
        {
            catPlayer.OnObstacleHit -= OnCatCollided;
        }
    }

    #endregion

    //---------------------------------------------------------------------------------------------

    #region Private Methods

    void UpdateDistance()
    {
        float newDistance = Mathf.Max(0f, catPlayer.transform.position.x - spawnPositionOffset.x);
        int flooredDistance = Mathf.FloorToInt(newDistance);

        if (flooredDistance != Mathf.FloorToInt(lastBroadcastedDistance))
        {
            currentDistance = flooredDistance;
            lastBroadcastedDistance = flooredDistance;

            // Update the screen display
            gamerunScreen.SetDistanceValue(Mathf.FloorToInt(currentDistance));
        }
    }

    void UpdateScore()
    {
        // Score update logic placeholder - can be expanded later
        // For now, score is updated via events (obstacles passed, etc.)
    }

    void OnStartButtonClicked()
    {
        Debug.Log("GameManager: Start button clicked");

        // Enable cat movement
        catPlayer.maxSpeed = initialCatMaxSpeed;

        // Switch screens
        startingScreen.Hide();
        gamerunScreen.Show();

        // Update state
        currentState = GameState.RUNNING;

        // Reset tracking
        currentDistance = 0f;
        currentScore = 0f;
        lastBroadcastedDistance = -1f;
        lastBroadcastedScore = -1f;

        EventSystem.current.SetSelectedGameObject(null);

        Debug.Log("GameManager: Game started");
    }

    void OnPauseButtonClicked()
    {
        Debug.Log("GameManager: Pause button clicked");

        // Freeze game
        Time.timeScale = 0f;

        // Switch screens
        gamerunScreen.Hide();
        pauseScreen.Show();

        // Update state
        currentState = GameState.PAUSED;

        EventSystem.current.SetSelectedGameObject(null);

        Debug.Log("GameManager: Game paused");
    }

    void OnResumeButtonClicked()
    {
        Debug.Log("GameManager: Resume button clicked");

        // Unfreeze game
        Time.timeScale = 1f;

        // Switch screens
        pauseScreen.Hide();
        gamerunScreen.Show();

        // Update state
        currentState = GameState.RUNNING;

        EventSystem.current.SetSelectedGameObject(null);

        Debug.Log("GameManager: Game resumed");
    }

    void OnRestartButtonClicked()
    {
        Debug.Log("GameManager: Restart button clicked");

        EventSystem.current.SetSelectedGameObject(null);

        // Reset game state
        ResetGame();

        Debug.Log("GameManager: Game restarted - triggering scene reload");
    }

    void OnHomeButtonClicked()
    {
        Debug.Log("GameManager: Home button clicked");

        EventSystem.current.SetSelectedGameObject(null);

        // Reset game state
        ResetGame();

        Debug.Log("GameManager: Returned to home screen");
    }

    // Method called when cat collides with obstacle/hole
    private async void OnCatCollided(string collisionTag)
    {
        if (currentState == GameState.DEAD)
        {
            return; // Already dead
        }

        Debug.Log("GameManager: Cat collided with " + collisionTag);

        // Mark as dead
        currentState = GameState.DEAD;

        // Stop cat
        catPlayer.maxSpeed = 0f;
        catPlayer.rb.velocity = Vector2.zero;
        catPlayer.rb.angularVelocity = 0f;

        // Hide active screens
        gamerunScreen.Hide();
        pauseScreen.Hide();

        await UniTask.Delay(1_000); // Wait for 3 seconds before resetting

        ShowGameOver();

        Debug.Log("GameManager: Cat died, returning to start screen");
    }

    void ShowGameOver()
    {
        // Cập nhật điểm số lên màn hình
        gameOverScreen.SetScore(currentScore);
        
        // Hiện màn hình
        gameOverScreen.Show();
    }

    void ResetGame()
    {
        Debug.Log("GameManager: Resetting game - firing OnGameReset event");

        // Unfreeze game if paused
        Time.timeScale = 1f;

        // Hide all screens
        startingScreen.Hide();
        gamerunScreen.Hide();
        pauseScreen.Hide();
        gameOverScreen.Hide();

        // Reset cat position and state
        ResetCat();

        // Reset tracking
        currentDistance = 0f;
        currentScore = 0f;
        lastBroadcastedDistance = -1f;
        lastBroadcastedScore = -1f;

        // Disable cat movement
        catPlayer.maxSpeed = 0f;

        // Trigger scene reload through GameInitiator
        OnGameReset?.Invoke();
    }

    void ResetCat()
    {
        // Position cat at spawn point
        catPlayer.transform.SetPositionAndRotation(catSpawnPoint.position, catSpawnPoint.rotation);

        // Reset physics
        catPlayer.rb.velocity = Vector2.zero;
        catPlayer.rb.angularVelocity = 0f;

        // Reset movement flags
        catPlayer.isRunning = false;
        catPlayer.isJumping = false;
        catPlayer.isBackflipping = false;
        catPlayer.isBackflipFailed = false;
        catPlayer.isSpeedBoosted = false;

        // Show cat
        catPlayer.gameObject.SetActive(true);

        Debug.Log("GameManager: Cat reset to spawn point");
    }

    #endregion
}
