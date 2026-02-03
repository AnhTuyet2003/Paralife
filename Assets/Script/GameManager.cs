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
    
    [SerializeField]
    private HealthBar healthBarPrefab;
    
    [Header("UI Canvas")]
    [SerializeField]
    [Tooltip("The Canvas that will contain the Health Bar UI")]
    private Canvas uiCanvas;

    [Header("Background Music")]
    [SerializeField]
    private AudioClip menuMusic;
    
    [SerializeField]
    private AudioClip gameplayMusic;
    
    [Range(0f, 1f)]
    [SerializeField]
    private float musicVolume = 0.5f;
    
    [SerializeField]
    private float musicFadeDuration = 1.0f;

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

    private GameOverScreen gameOverScreen;
    private GameState currentState = GameState.STARTING;
    private StartingScreen startingScreen;
    private GamerunScreen gamerunScreen;
    private PauseScreen pauseScreen;
    private HealthBar healthBar;
    private PlayerHealth playerHealth;
    
    private float initialCatMaxSpeed;
    private Vector3 spawnPositionOffset;
    private float currentDistance = 0f;
    private float currentScore = 0f;
    private float lastBroadcastedDistance = -1f;
    private float lastBroadcastedScore = -1f;
    
    private AudioSource musicAudioSource;
    private bool isFadingMusic = false;
    
    private float enemySpawnTimer = 0f;
    private bool firstEnemySpawned = false;
    private GameObject currentEnemy;

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

        // Setup background music
        SetupBackgroundMusic();
        
        // Setup player health
        SetupPlayerHealth();

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
        
        // Instantiate health bar and parent it to Canvas
        healthBar = Instantiate(healthBarPrefab);
        
        // Use assigned Canvas or find one in scene
        Canvas canvas = uiCanvas;
        if (canvas == null)
        {
            // Fallback: try to find Canvas in scene if not assigned
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
        if (healthBar != null && playerHealth != null)
        {
            healthBar.Initialize(playerHealth.GetMaxHealth());
        }

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
        healthBar.gameObject.SetActive(false);

        Debug.Log("GameManager: Initialized successfully");
    }

    void Start()
    {
        // Additional setup if needed
        currentState = GameState.STARTING;
        currentDistance = 0f;
        currentScore = 0f;
        
        // Start playing menu music
        PlayMenuMusic();
    }

    void Update()
    {
        if (currentState != GameState.RUNNING)
        {
            return;
        }

        UpdateDistance();
        UpdateScore();
        UpdateEnemySpawning();
    }

    void OnDestroy()
    {
        // Unsubscribe from cat collision events
        if (catPlayer != null)
        {
            catPlayer.OnObstacleHit -= OnCatCollided;
        }
        
        // Unsubscribe from player health events
        if (playerHealth != null)
        {
            playerHealth.OnHealthChanged -= OnPlayerHealthChanged;
            playerHealth.OnPlayerDied -= OnPlayerDied;
        }
        
        // Stop music
        if (musicAudioSource != null)
        {
            musicAudioSource.Stop();
        }
        
        // Destroy current enemy if exists
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
        // Add or get PlayerHealth component
        playerHealth = catPlayer.GetComponent<PlayerHealth>();
        if (playerHealth == null)
        {
            playerHealth = catPlayer.gameObject.AddComponent<PlayerHealth>();
        }
        
        // Subscribe to health events
        playerHealth.OnHealthChanged += OnPlayerHealthChanged;
        playerHealth.OnPlayerDied += OnPlayerDied;
        
        Debug.Log("GameManager: Player health system initialized");
    }

    void OnPlayerHealthChanged(int currentHealth, int maxHealth)
    {
        // Update health bar
        if (healthBar != null)
        {
            healthBar.UpdateHealth(currentHealth, maxHealth);
        }
        
        Debug.Log("GameManager: Player health changed to " + currentHealth + "/" + maxHealth);
    }

    void OnPlayerDied()
    {
        Debug.Log("GameManager: Player died from health loss!");
        
        if (currentState == GameState.DEAD)
        {
            return; // Already dead
        }
        
        // Mark as dead
        currentState = GameState.DEAD;
        
        // Stop cat
        catPlayer.maxSpeed = 0f;
        catPlayer.rb.velocity = Vector2.zero;
        catPlayer.rb.angularVelocity = 0f;
        
        // Hide active screens
        gamerunScreen.Hide();
        pauseScreen.Hide();
        
        // Wait and show game over
        WaitAndShowGameOver();
    }

    async void WaitAndShowGameOver()
    {
        await UniTask.Delay(1_000);
        ShowGameOver();
    }

    #endregion

    //---------------------------------------------------------------------------------------------

    #region Enemy Spawning Methods

    void UpdateEnemySpawning()
    {
        enemySpawnTimer += Time.deltaTime;
        
        // First enemy spawn
        if (!firstEnemySpawned && enemySpawnTimer >= firstEnemySpawnDelay)
        {
            SpawnRandomEnemy();
            firstEnemySpawned = true;
            enemySpawnTimer = 0f;
        }
        // Subsequent enemy spawns
        else if (firstEnemySpawned && enemySpawnTimer >= enemySpawnInterval)
        {
            SpawnRandomEnemy();
            enemySpawnTimer = 0f;
        }
    }

    void SpawnRandomEnemy()
    {
        // Destroy previous enemy if still exists
        if (currentEnemy != null)
        {
            Destroy(currentEnemy);
        }
        
        // Random chance to spawn Gator or Bird
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
        
        // Spawn position relative to player
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
        
        // Spawn position relative to player
        Vector3 spawnPosition = catPlayer.transform.position + birdSpawnOffset;
        currentEnemy = Instantiate(birdPrefab, spawnPosition, Quaternion.identity);
        
        Debug.Log("GameManager: Spawned Bird enemy at " + spawnPosition);
    }

    void ResetEnemySpawning()
    {
        enemySpawnTimer = 0f;
        firstEnemySpawned = false;
        
        // Destroy current enemy if exists
        if (currentEnemy != null)
        {
            Destroy(currentEnemy);
            currentEnemy = null;
        }
    }

    #endregion

    //---------------------------------------------------------------------------------------------

    #region Background Music Methods

    void SetupBackgroundMusic()
    {
        // Create a persistent AudioSource for background music
        musicAudioSource = gameObject.AddComponent<AudioSource>();
        musicAudioSource.playOnAwake = false;
        musicAudioSource.loop = true;
        musicAudioSource.volume = 0f; // Start at 0 for fade in
        
        Debug.Log("GameManager: Background music system initialized");
    }

    void PlayMenuMusic()
    {
        if (menuMusic != null && musicAudioSource != null)
        {
            if (musicAudioSource.clip != menuMusic)
            {
                CrossfadeToMusic(menuMusic);
            }
            else if (!musicAudioSource.isPlaying)
            {
                musicAudioSource.Play();
                StartCoroutine(FadeInMusic());
            }
            Debug.Log("GameManager: Playing menu music");
        }
        else if (menuMusic == null)
        {
            Debug.LogWarning("GameManager: Menu music not assigned!");
        }
    }

    void PlayGameplayMusic()
    {
        if (gameplayMusic != null && musicAudioSource != null)
        {
            if (musicAudioSource.clip != gameplayMusic)
            {
                CrossfadeToMusic(gameplayMusic);
            }
            Debug.Log("GameManager: Playing gameplay music");
        }
        else if (gameplayMusic == null)
        {
            Debug.LogWarning("GameManager: Gameplay music not assigned!");
        }
    }

    void CrossfadeToMusic(AudioClip newClip)
    {
        if (!isFadingMusic)
        {
            StartCoroutine(CrossfadeMusicCoroutine(newClip));
        }
    }

    System.Collections.IEnumerator CrossfadeMusicCoroutine(AudioClip newClip)
    {
        isFadingMusic = true;
        
        // Fade out current music
        if (musicAudioSource.isPlaying)
        {
            float startVolume = musicAudioSource.volume;
            float elapsed = 0f;
            
            while (elapsed < musicFadeDuration)
            {
                elapsed += Time.unscaledDeltaTime; // Use unscaled for pause compatibility
                musicAudioSource.volume = Mathf.Lerp(startVolume, 0f, elapsed / musicFadeDuration);
                yield return null;
            }
            
            musicAudioSource.Stop();
        }
        
        // Switch to new clip
        musicAudioSource.clip = newClip;
        musicAudioSource.Play();
        
        // Fade in new music
        float elapsed2 = 0f;
        while (elapsed2 < musicFadeDuration)
        {
            elapsed2 += Time.unscaledDeltaTime;
            musicAudioSource.volume = Mathf.Lerp(0f, musicVolume, elapsed2 / musicFadeDuration);
            yield return null;
        }
        
        musicAudioSource.volume = musicVolume;
        isFadingMusic = false;
    }

    System.Collections.IEnumerator FadeInMusic()
    {
        float elapsed = 0f;
        
        while (elapsed < musicFadeDuration)
        {
            elapsed += Time.unscaledDeltaTime;
            musicAudioSource.volume = Mathf.Lerp(0f, musicVolume, elapsed / musicFadeDuration);
            yield return null;
        }
        
        musicAudioSource.volume = musicVolume;
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
        healthBar.gameObject.SetActive(true);

        // Update state
        currentState = GameState.RUNNING;

        // Reset tracking
        currentDistance = 0f;
        currentScore = 0f;
        lastBroadcastedDistance = -1f;
        lastBroadcastedScore = -1f;

        // Reset enemy spawning
        ResetEnemySpawning();
        
        // Reset player health
        if (playerHealth != null)
        {
            playerHealth.ResetHealth();
        }

        // Switch to gameplay music
        PlayGameplayMusic();

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

        // Reduce health by 1 when hitting an obstacle
        if (playerHealth != null)
        {
            playerHealth.TakeDamage(1);
            Debug.Log("GameManager: Player took damage from " + collisionTag);
        }
        
        // Note: Death is now handled by OnPlayerDied event when health reaches 0
        // No need to manually set DEAD state or show game over here
    }

    void ShowGameOver()
    {
        // Cập nhật điểm số lên màn hình
        gameOverScreen.SetScore(Mathf.FloorToInt(currentDistance));

        // Hiện màn hình
        gameOverScreen.Show();
        
        // Hide health bar
        healthBar.gameObject.SetActive(false);
        
        // Switch back to menu music
        PlayMenuMusic();
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
        healthBar.gameObject.SetActive(false);

        // Reset cat position and state
        ResetCat();

        // Reset tracking
        currentDistance = 0f;
        currentScore = 0f;
        lastBroadcastedDistance = -1f;
        lastBroadcastedScore = -1f;

        // Disable cat movement
        catPlayer.maxSpeed = 0f;

        // Reset enemy spawning
        ResetEnemySpawning();
        
        // Reset player health
        if (playerHealth != null)
        {
            playerHealth.ResetHealth();
        }

        // Switch back to menu music
        PlayMenuMusic();

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
