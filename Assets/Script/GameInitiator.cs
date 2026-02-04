using Cysharp.Threading.Tasks;
using Persistent;
using UnityEngine;
using UnityEngine.SceneManagement;

public class GameInitiator : MonoBehaviour
{
    [SerializeField]
    private GameObject loadingScreenPrefab;

    [SerializeField]
    private PlayerDataManager? playerDataManagerPrefab;

    [SerializeField]
    private string gameSceneName = "GameScene";

    public static PlayerDataManager? PlayerData { get; private set; }

    private LoadingScreen _loadingScreen;
    private GameManager _gameManager;

    private async void Start()
    {
        await BindObjects();
        _loadingScreen.Show();
        await InitializeObjects();
        await CreateObjects();
        _loadingScreen.Hide();
        PrepareGame();
        await BeginGame();
    }

    private async UniTask BindObjects()
    {
        GameObject loadingScreenObj = Instantiate(loadingScreenPrefab);
        _loadingScreen = loadingScreenObj.GetComponent<LoadingScreen>();

        if (playerDataManagerPrefab != null)
            PlayerData = Instantiate(playerDataManagerPrefab);
    }

    private async UniTask InitializeObjects()
    {
        DontDestroyOnLoad(_loadingScreen.gameObject);

        if (PlayerData != null)
            DontDestroyOnLoad(PlayerData.gameObject);
    }

    private async UniTask CreateObjects()
    {
        await UniTask.Delay(2_000); // Simulate some loading time

        var loadingOperation = SceneManager.LoadSceneAsync(gameSceneName, LoadSceneMode.Additive);
        await loadingOperation;
    }

    private void PrepareGame()
    {
        // Find GameManager in the loaded scene
        _gameManager = FindObjectOfType<GameManager>();

        if (_gameManager != null)
        {
            _gameManager.OnGameReset += OnGameManagerReset;
            Debug.Log("GameInitiator: Subscribed to GameManager.OnGameReset event");
        }
        else
        {
            Debug.LogWarning("GameInitiator: GameManager not found in scene!");
        }
    }

    /// <summary>Handles game reset event from GameManager - reloads the scene with loading screen.</summary>
    private async void OnGameManagerReset()
    {
        Debug.Log("GameInitiator: OnGameReset event received - reloading scene");

        _loadingScreen.Show();
        await UniTask.Delay(500); // Brief loading screen

        // Unsubscribe to prevent memory leaks
        if (_gameManager != null)
        {
            _gameManager.OnGameReset -= OnGameManagerReset;
        }

        // Unload and reload the game scene
        await SceneManager.UnloadSceneAsync(gameSceneName);

        var loadingOperation = SceneManager.LoadSceneAsync(gameSceneName, LoadSceneMode.Additive);
        await loadingOperation;

        // Wait a frame to ensure all Awake() methods complete
        await UniTask.Yield();

        // Find GameManager in the loaded scene
        _gameManager = FindObjectOfType<GameManager>();

        if (_gameManager != null)
        {
            _gameManager.OnGameReset += OnGameManagerReset;
            Debug.Log("GameInitiator: Subscribed to GameManager.OnGameReset event");
        }
        else
        {
            Debug.LogWarning("GameInitiator: GameManager not found in scene!");
        }

        _loadingScreen.Hide();
        Debug.Log("GameInitiator: Scene reloaded successfully");
    }

    private void OnDestroy()
    {
        // Unsubscribe to prevent memory leaks
        if (_gameManager != null)
        {
            _gameManager.OnGameReset -= OnGameManagerReset;
        }
    }

    private async UniTask BeginGame()
    {
        // _enemySpawner.StartSpawning();
    }
}
