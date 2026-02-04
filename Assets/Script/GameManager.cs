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
    
    [SerializeField]
    private HealthBar healthBarPrefab;
    
    [SerializeField]
    private GameObject staminaBarPrefab;
    
    [Header("UI Canvas")]
    [SerializeField]
    [Tooltip("The Canvas that will contain the Health Bar UI")]
    private Canvas uiCanvas;

    [Header("Enemy Spawning")]
    [SerializeField]
    private GameObject gatorPrefab;
    
    [SerializeField]
    private GameObject birdPrefab;
    
    [SerializeField]
    private float enemySpawnInterval = 30f;
    
    [SerializeField]
    private float firstEnemySpawnDelay = 15f;
    
    [Range(0f, 1f)]
    [SerializeField]
    private float gatorSpawnChance = 0.5f;
    
    [SerializeField]
    private Vector3 gatorSpawnOffset = new Vector3(-15f, 3f, 0f);
    
    [SerializeField]
    private Vector3 birdSpawnOffset = new Vector3(15f, 5f, 0f);

    [Header("Health Regeneration")]
    [SerializeField]
    private float healDistanceInterval = 250f;
    
    [SerializeField]
    private float healAmount = 0.25f;

    private GameResultScreen gameResultScreen;
    private SettingScreen settingScreen;

    private GameState currentState = GameState.STARTING;

    private StartingScreen startingScreen;
    private GamerunScreen gamerunScreen;
    private PauseScreen pauseScreen;
    private HealthBar healthBar;
    private PlayerHealth playerHealth;
    private GameObject staminaBarObject;
    private StaminaBar staminaBar;
    private StaminaBarSlider staminaBarSlider;
    private PlayerStamina playerStamina;

    private float initialCatMaxSpeed;
    
    private float enemySpawnTimer = 0f;
    private bool firstEnemySpawned = false;
    private GameObject currentEnemy;
    
    private float lastHealDistance = 0f;

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

        // Setup player health
        SetupPlayerHealth();
        
        // Setup player stamina
        SetupPlayerStamina();

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
        
        // Instantiate health bar and parent it to Canvas
        if (healthBarPrefab != null)
        {
            healthBar = Instantiate(healthBarPrefab);
            
            // Use assigned Canvas or find one in scene
            Canvas canvas = uiCanvas;
            if (canvas == null)
            {
                canvas = FindObjectOfType<Canvas>();
                Debug.LogWarning("GameManager: UI Canvas not assigned! Using FindObjectOfType as fallback.");
            }
            
            if (canvas != null)
            {
                healthBar.transform.SetParent(canvas.transform, false);
                Debug.Log("GameManager: HealthBar parented to Canvas: " + canvas.name);
            }
            else
            {
                Debug.LogError("GameManager: No Canvas found in scene! HealthBar will not be visible.");
            }
            
            // Initialize health bar with player's max health
            if (playerHealth != null)
            {
                healthBar.Initialize(playerHealth.GetMaxHealth());
            }
        }
        
        // Instantiate stamina bar and parent it to Canvas
        if (staminaBarPrefab != null)
        {
            staminaBarObject = Instantiate(staminaBarPrefab);
            staminaBar = staminaBarObject.GetComponent<StaminaBar>();
            staminaBarSlider = staminaBarObject.GetComponent<StaminaBarSlider>();
            
            // Use assigned Canvas or find one in scene
            Canvas canvas = uiCanvas;
            if (canvas == null)
            {
                canvas = FindObjectOfType<Canvas>();
            }
            
            if (canvas != null && staminaBarObject != null)
            {
                staminaBarObject.transform.SetParent(canvas.transform, false);
                Debug.Log("GameManager: StaminaBar parented to Canvas: " + canvas.name);
            }
            
            // Initialize stamina bar with player's max stamina
            if (playerStamina != null)
            {
                if (staminaBar != null)
                {
                    staminaBar.Initialize(playerStamina.GetMaxStamina());
                }
                
                if (staminaBarSlider != null)
                {
                    staminaBarSlider.Initialize(playerStamina.GetMaxStamina());
                }
            }
        }

        // Initialize screens with callbacks
        startingScreen.Initialize(OnStartButtonClicked);
        gamerunScreen.Initialize(OnPauseButtonClicked);
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
        if (healthBar != null)
        {
            healthBar.gameObject.SetActive(false);
        }
        if (staminaBarObject != null)
        {
            staminaBarObject.SetActive(false);
        }

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

    void Update()
    {
        if (currentState != GameState.RUNNING)
        {
            return;
        }

        UpdateEnemySpawning();
        UpdateHealthRegeneration();
    }

    void OnDestroy()
    {
        if (loseConditionObserver != null)
        {
            loseConditionObserver.OnObstacleHit -= OnLoseCondition;
            loseConditionObserver.OnHoleFall -= OnHoleFall;
        }
        
        if (playerHealth != null)
        {
            playerHealth.OnHealthChanged -= OnPlayerHealthChanged;
            playerHealth.OnPlayerDied -= OnPlayerDied;
        }
        
        if (playerStamina != null)
        {
            playerStamina.OnStaminaChanged -= OnPlayerStaminaChanged;
        }
        
        if (currentEnemy != null)
        {
            Destroy(currentEnemy);
        }
    }

    #endregion

    //---------------------------------------------------------------------------------------------

    #region Player Health Methods

    void SetupPlayerHealth()
    {
        playerHealth = catPlayer.GetComponent<PlayerHealth>();
        if (playerHealth == null)
        {
            playerHealth = catPlayer.gameObject.AddComponent<PlayerHealth>();
        }
        
        playerHealth.OnHealthChanged += OnPlayerHealthChanged;
        playerHealth.OnPlayerDied += OnPlayerDied;
        
        Debug.Log("GameManager: Player health system initialized");
    }

    void OnPlayerHealthChanged(float currentHealth, int maxHealth)
    {
        if (healthBar != null)
        {
            healthBar.UpdateHealth(currentHealth, maxHealth);
        }
        
        Debug.Log("GameManager: Player health changed to " + currentHealth + "/" + maxHealth);
    }

    void OnPlayerDied()
    {
        Debug.Log("GameManager: Player died from health loss!");
        HandlePlayerDeath("health depletion");
    }

    #endregion

    //---------------------------------------------------------------------------------------------

    #region Player Stamina Methods

    void SetupPlayerStamina()
    {
        playerStamina = catPlayer.GetComponent<PlayerStamina>();
        if (playerStamina == null)
        {
            playerStamina = catPlayer.gameObject.AddComponent<PlayerStamina>();
            Debug.Log("GameManager: Created new PlayerStamina component");
        }
        else
        {
            Debug.Log("GameManager: Found existing PlayerStamina component");
        }
        
        playerStamina.OnStaminaChanged += OnPlayerStaminaChanged;
        
        Debug.Log("GameManager: Player stamina system initialized - Max=" + playerStamina.GetMaxStamina() + 
                  " Current=" + playerStamina.GetCurrentStamina());
    }

    void OnPlayerStaminaChanged(float currentStamina, float maxStamina)
    {
        Debug.Log("GameManager: OnPlayerStaminaChanged called - " + currentStamina + "/" + maxStamina + 
                  " | staminaBar=" + (staminaBar != null) + 
                  " | staminaBarSlider=" + (staminaBarSlider != null));
        
        if (staminaBar != null && staminaBarSlider == null)
        {
            staminaBar.UpdateStamina(currentStamina, maxStamina);
        }
        
        if (staminaBarSlider != null)
        {
            staminaBarSlider.UpdateStamina(currentStamina, maxStamina);
        }
        
        Debug.Log("GameManager: Player stamina changed to " + currentStamina + "/" + maxStamina);
    }

    #endregion

    //---------------------------------------------------------------------------------------------

    #region Enemy Spawning Methods

    void UpdateEnemySpawning()
    {
        enemySpawnTimer += Time.deltaTime;
        
        if (!firstEnemySpawned && enemySpawnTimer >= firstEnemySpawnDelay)
        {
            SpawnRandomEnemy();
            firstEnemySpawned = true;
            enemySpawnTimer = 0f;
        }
        else if (firstEnemySpawned && enemySpawnTimer >= enemySpawnInterval)
        {
            SpawnRandomEnemy();
            enemySpawnTimer = 0f;
        }
    }

    void SpawnRandomEnemy()
    {
        if (currentEnemy != null)
        {
            Destroy(currentEnemy);
        }
        
        float randomValue = Random.value;
        
        if (randomValue < gatorSpawnChance)
        {
            SpawnGator();
        }
        else
        {
            SpawnBird();
        }
    }

    void SpawnGator()
    {
        if (gatorPrefab == null)
        {
            Debug.LogWarning("GameManager: Gator prefab not assigned!");
            return;
        }
        
        Vector3 spawnPosition = catPlayer.transform.position + gatorSpawnOffset;
        currentEnemy = Instantiate(gatorPrefab, spawnPosition, Quaternion.identity);
        
        Debug.Log("GameManager: Spawned Gator enemy at " + spawnPosition);
    }

    void SpawnBird()
    {
        if (birdPrefab == null)
        {
            Debug.LogWarning("GameManager: Bird prefab not assigned!");
            return;
        }
        
        Vector3 spawnPosition = catPlayer.transform.position + birdSpawnOffset;
        currentEnemy = Instantiate(birdPrefab, spawnPosition, Quaternion.identity);
        
        Debug.Log("GameManager: Spawned Bird enemy at " + spawnPosition);
    }

    void ResetEnemySpawning()
    {
        enemySpawnTimer = 0f;
        firstEnemySpawned = false;
        
        if (currentEnemy != null)
        {
            Destroy(currentEnemy);
            currentEnemy = null;
        }
    }

    #endregion

    //---------------------------------------------------------------------------------------------

    #region Health Regeneration Methods

    void UpdateHealthRegeneration()
    {
        if (runProgressTracker == null)
            return;
            
        float currentDist = runProgressTracker.CurrentDistance;
        
        if (currentDist >= lastHealDistance + healDistanceInterval)
        {
            if (playerHealth != null)
            {
                playerHealth.Heal(healAmount);
                Debug.Log("GameManager: Healing player " + healAmount + " HP at " + Mathf.FloorToInt(currentDist) + "m distance");
            }
            
            lastHealDistance += healDistanceInterval;
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
        if (healthBar != null)
        {
            healthBar.gameObject.SetActive(true);
        }
        if (staminaBarObject != null)
        {
            staminaBarObject.SetActive(true);
        }

        // Update state
        currentState = GameState.RUNNING;

        // Start tracking progress
        if (runProgressTracker != null)
        {
            runProgressTracker.StartTracking(catSpawnPoint.position);
        }

        // Reset health regeneration
        lastHealDistance = 0f;

        // Reset enemy spawning
        ResetEnemySpawning();
        
        // Reset player health
        if (playerHealth != null)
        {
            playerHealth.ResetHealth();
        }
        
        // Reset player stamina
        if (playerStamina != null)
        {
            playerStamina.ResetStamina();
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
        if (playerHealth != null)
        {
            playerHealth.TakeDamage(1);
            Debug.Log("GameManager: Player took damage from obstacle: " + collisionTag);
        }
        else
        {
            HandlePlayerDeath($"obstacle ({collisionTag})");
        }
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
        
        if (healthBar != null)
        {
            healthBar.gameObject.SetActive(false);
        }
        
        if (staminaBarObject != null)
        {
            staminaBarObject.SetActive(false);
        }
        
        if (audioPlayer != null)
        {
            audioPlayer.PlayMenuMusic();
        }
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
        if (healthBar != null)
        {
            healthBar.gameObject.SetActive(false);
        }
        if (staminaBarObject != null)
        {
            staminaBarObject.SetActive(false);
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

        // Reset health regeneration
        lastHealDistance = 0f;

        // Reset enemy spawning
        ResetEnemySpawning();
        
        // Reset player health
        if (playerHealth != null)
        {
            playerHealth.ResetHealth();
        }
        
        // Reset player stamina
        if (playerStamina != null)
        {
            playerStamina.ResetStamina();
        }

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
