using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LevelGenerator : MonoBehaviour
{
    [Header("References")]
    [SerializeField] private GameManager gameManager;
    [SerializeField] private Transform environmentContainer; // Kéo cái LevelContainer vào đây

    [Header("Settings")]
    [SerializeField] private Transform player;
    [SerializeField] private float spawnDistance = 50f; 
    [SerializeField] private int initialChunks = 7;

    [Header("Probability")]
    [Range(0f, 1f)] 
    [SerializeField] private float jumpChance = 0.3f; 

    [Header("Level Pieces")]
    [SerializeField] private Transform levelStartPoint;
    
    [SerializeField] private List<Transform> safeLevelParts; 
    [SerializeField] private List<Transform> jumpLevelParts; 
    
    private Vector3 lastEndPosition;
    private bool lastPartWasJump = false; 

    void Start()
    {
        if (gameManager == null) gameManager = FindObjectOfType<GameManager>();

        // Đăng ký sự kiện Reset
        if (gameManager != null)
        {
            gameManager.OnGameReset += ResetLevel;
        }

        ResetLevel();
    }

    private void OnDestroy()
    {
        if (gameManager != null)
        {
            gameManager.OnGameReset -= ResetLevel;
        }
    }

    void Update()
    {
        // Chỉ chạy khi game đang RUNNING hoặc STARTING
        if (gameManager.GetCurrentState() != GameManager.GameState.RUNNING && 
            gameManager.GetCurrentState() != GameManager.GameState.STARTING) return;

        if (lastEndPosition.x - player.position.x < spawnDistance)
        {
            SpawnLevelPart();
        }
    }

    public void ResetLevel()
    {
        Debug.Log("LevelGenerator: Đang dọn dẹp địa hình cũ...");

        // 1. DỌN DẸP: Duyệt qua tất cả con của Container và xóa sổ
        foreach (Transform child in environmentContainer)
        {
            Destroy(child.gameObject);
        }

        // 2. RESET VỊ TRÍ
        lastEndPosition = levelStartPoint.position;
        lastPartWasJump = false;

        // 3. SINH LẠI TỪ ĐẦU
        for (int i = 0; i < initialChunks; i++)
        {
            SpawnChunk(false); 
        }
    }

    private void SpawnLevelPart()
    {
        if (lastPartWasJump)
        {
            SpawnChunk(false); 
        }
        else
        {
            // Random xem có ra vực không
            if (Random.value < jumpChance) 
                SpawnChunk(true); 
            else
                SpawnChunk(false); 
        }
    }

    private void SpawnChunk(bool isJump)
    {
        Transform chosenLevelPart;

        if (isJump)
        {
            chosenLevelPart = jumpLevelParts[Random.Range(0, jumpLevelParts.Count)];
            lastPartWasJump = true; 
        }
        else
        {
            chosenLevelPart = safeLevelParts[Random.Range(0, safeLevelParts.Count)];
            lastPartWasJump = false; 
        }

        // QUAN TRỌNG: Spawn làm con của environmentContainer
        Transform lastLevelPartTransform = Instantiate(chosenLevelPart, lastEndPosition, Quaternion.identity, environmentContainer);

        lastEndPosition = lastLevelPartTransform.Find("EndPosition").position;
    }
}