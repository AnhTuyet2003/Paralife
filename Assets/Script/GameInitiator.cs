using Cysharp.Threading.Tasks;
using UnityEngine;
using UnityEngine.SceneManagement;

public class GameInitiator : MonoBehaviour
{
    [SerializeField]
    private GameObject loadingScreenPrefab;

    [SerializeField]
    private GameObject startingScreenPrefab;

    [SerializeField]
    private GameObject playerPrefab;

    private GameObject _player;
    private LoadingScreen _loadingScreen;
    private StartingScreen _startingScreen;

    private async void Start()
    {
        await BindObjects();
        _startingScreen.Hide();
        _loadingScreen.Show();
        await InitializeObjects();
        await CreateObjects();
        _loadingScreen.Hide();
        _startingScreen.Show();
        PrepareGame();
        await BeginGame();
    }

    private async UniTask BindObjects()
    {
        GameObject loadingScreenObj = Instantiate(loadingScreenPrefab);
        _loadingScreen = loadingScreenObj.GetComponent<LoadingScreen>();

        GameObject startingScreenObj = Instantiate(startingScreenPrefab);
        _startingScreen = startingScreenObj.GetComponent<StartingScreen>();
    }

    private async UniTask InitializeObjects()
    {
        DontDestroyOnLoad(_loadingScreen.gameObject);
        DontDestroyOnLoad(_startingScreen.gameObject);
    }

    private async UniTask CreateObjects()
    {
        _player = Instantiate(playerPrefab);

        await UniTask.Delay(3_000); // Simulate some loading time

        var loadingOperation = SceneManager.LoadSceneAsync("GameScene", LoadSceneMode.Additive);
        await loadingOperation;
    }

    private void PrepareGame()
    {
        // _gameStateMachine.Enter<GameLoopState>();
    }

    private async UniTask BeginGame()
    {
        // _enemySpawner.StartSpawning();
    }
}
