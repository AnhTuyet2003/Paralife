using Audio;
using Collectibles.Coins;
using Cysharp.Threading.Tasks;
using Gameplay;
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

    /// <summary>Auto-starts the game after restart (called by GameInitiator).</summary>
    public void AutoStartGame()
    {
        Debug.Log("GameManager: Auto-starting game after restart");
        OnStartButtonClicked();
    }

    /// <summary>Shows the settings screen (can be called from UI).</summary>
    public void ShowSettings()
    {
        if (settingScreen == null)
            return;

        // Hide current screen
        if (currentState == GameState.STARTING)
        {
            startingScreen.Hide();
        }
        else if (currentState == GameState.PAUSED)
        {
            pauseScreen.Hide();
        }

        settingScreen.Show();
    }

    #endregion

    //---------------------------------------------------------------------------------------------

    #region Private Fields

    [SerializeField]
    private CatMove catPlayer;

    [SerializeField]
    private PlayerLoseConditionObserver loseConditionObserver;

    [SerializeField]
    private RunProgressTracker runProgressTracker;

    [SerializeField]
    private CoinCollector coinCollector;

    [SerializeField]
    private Transform catSpawnPoint;

    [SerializeField]
    private StartingScreen startingScreenPrefab;

    [SerializeField]
    private GamerunScreen gamerunScreenPrefab;

    [SerializeField]
    private PauseScreen pauseScreenPrefab;

    [SerializeField]
    private GameResultScreen gameResultScreenPrefab;

    [SerializeField]
    private SettingScreen settingScreenPrefab;

    [SerializeField]
    private AudioPlayer audioPlayer;

    private GameResultScreen gameResultScreen;
    private SettingScreen settingScreen;

    private GameState currentState = GameState.STARTING;

    private StartingScreen startingScreen;
    private GamerunScreen gamerunScreen;
    private PauseScreen pauseScreen;

    private float initialCatMaxSpeed;

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

        // Instantiate screen prefabs
        startingScreen = Instantiate(startingScreenPrefab);
        gamerunScreen = Instantiate(gamerunScreenPrefab);
        pauseScreen = Instantiate(pauseScreenPrefab);
        gameResultScreen = Instantiate(gameResultScreenPrefab);
        if (settingScreenPrefab != null)
        {
            settingScreen = Instantiate(settingScreenPrefab);
        }

        // Initialize screens with callbacks
        startingScreen.Initialize(OnStartButtonClicked, ShowSettings);
        gamerunScreen.Initialize(OnPauseButtonClicked, runProgressTracker, coinCollector);
        pauseScreen.Initialize(OnHomeButtonClicked, OnRestartButtonClicked, OnResumeButtonClicked);
        gameResultScreen.Initialize(OnRestartButtonClicked, OnHomeButtonClicked);
        if (settingScreen != null)
        {
            settingScreen.Initialize(OnSettingReturnClicked, audioPlayer);
        }

        // Subscribe to lose condition events
        if (loseConditionObserver != null)
        {
            loseConditionObserver.OnObstacleHit += OnLoseCondition;
            loseConditionObserver.OnHoleFall += OnHoleFall;
        }

        // Show only starting screen
        startingScreen.Show();
        gamerunScreen.Hide();
        pauseScreen.Hide();
        gameResultScreen.Hide();
        settingScreen?.Hide();

        // Play menu music
        if (audioPlayer != null)
        {
            audioPlayer.PlayMenuMusic();
        }

        Debug.Log("GameManager: Initialized successfully");
    }

    void Start()
    {
        currentState = GameState.STARTING;
    }

    void OnDestroy()
    {
        if (loseConditionObserver != null)
        {
            loseConditionObserver.OnObstacleHit -= OnLoseCondition;
            loseConditionObserver.OnHoleFall -= OnHoleFall;
        }
    }

    #endregion

    //---------------------------------------------------------------------------------------------

    #region Private Methods

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

        // Start tracking progress
        if (runProgressTracker != null)
        {
            runProgressTracker.StartTracking(catSpawnPoint.position);
        }

        // Play gameplay music
        if (audioPlayer != null)
        {
            audioPlayer.PlayGameplayMusic();
        }

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

    void OnSettingReturnClicked()
    {
        Debug.Log("GameManager: Setting return clicked");

        if (settingScreen != null)
        {
            settingScreen.Hide();
        }

        // Return to appropriate screen based on state
        if (currentState == GameState.STARTING)
        {
            startingScreen.Show();
        }
        else if (currentState == GameState.PAUSED)
        {
            pauseScreen.Show();
        }

        EventSystem.current.SetSelectedGameObject(null);
    }

    private void OnLoseCondition(string collisionTag)
    {
        HandlePlayerDeath($"obstacle ({collisionTag})");
    }

    private void OnHoleFall()
    {
        HandlePlayerDeath("hole");
    }

    private async void HandlePlayerDeath(string cause)
    {
        if (currentState == GameState.DEAD)
            return;

        Debug.Log($"GameManager: Player died from {cause}");

        currentState = GameState.DEAD;

        // Stop cat
        catPlayer.maxSpeed = 0f;
        catPlayer.rb.velocity = Vector2.zero;
        catPlayer.rb.angularVelocity = 0f;

        // Stop tracking
        if (runProgressTracker != null)
        {
            runProgressTracker.StopTracking();
        }

        // Hide active screens
        gamerunScreen.Hide();
        pauseScreen.Hide();

        await UniTask.Delay(1_000);

        ShowGameOver();
    }

    void ShowGameOver()
    {
        int finalScore = runProgressTracker != null ? runProgressTracker.CurrentScore : 0;
        int finalDistance = runProgressTracker != null ? runProgressTracker.CurrentDistance : 0;
        gameResultScreen.SetResults(finalScore, finalDistance);
        gameResultScreen.Show();
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
        gameResultScreen.Hide();
        if (settingScreen != null)
        {
            settingScreen.Hide();
        }

        // Stop music during reset/loading
        if (audioPlayer != null)
        {
            audioPlayer.StopMusic();
        }

        // Reset cat position and state
        ResetCat();

        // Reset progress tracker
        if (runProgressTracker != null)
        {
            runProgressTracker.Reset();
        }

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
