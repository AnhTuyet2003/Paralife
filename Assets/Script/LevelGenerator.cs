using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

public class LevelGenerator : MonoBehaviour
{
    [Header("References")]
    [SerializeField] private GameManager gameManager;
    [SerializeField] private Transform environmentContainer; // Kéo cái LevelContainer vào đây

    [Header("Settings")]
    [SerializeField] private Transform player;
    [SerializeField] private float spawnDistance = 100f; 
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
    // Thêm vào trong class LevelGenerator
    [Header("Transition Settings")]
    [SerializeField] private float transitionDistance = 50f;

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
        if (gameManager.GetCurrentState() != GameManager.GameState.RUNNING && 
            gameManager.GetCurrentState() != GameManager.GameState.STARTING) return;

        // Chỉ giữ lại logic sinh địa hình cơ bản
        if (lastEndPosition.x - player.position.x < spawnDistance)
        {
            SpawnLevelPart();
        }
    }

    // Hàm SpawnLevelPart quay về trạng thái gốc của bạn
    private void SpawnLevelPart()
    {
        if (lastPartWasJump)
        {
            SpawnChunk(false); 
        }
        else
        {
            if (Random.value < jumpChance) 
                SpawnChunk(true); 
            else
                SpawnChunk(false); 
        }
    }

    public void ResetLevel()
    {
        Debug.Log("LevelGenerator: Đang dọn dẹp địa hình cũ...");

        foreach (Transform child in environmentContainer)
        {
            Destroy(child.gameObject);
        }

        lastEndPosition = levelStartPoint.position;
        lastPartWasJump = false;

        for (int i = 0; i < initialChunks; i++)
        {
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