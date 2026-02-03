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
    [SerializeField] private List<Transform> transitionLevelParts; 
    [SerializeField] private List<Transform> noObstacleLevelParts;
    
    private Vector3 lastEndPosition;
    private bool lastPartWasJump = false; 
    // Thêm vào trong class LevelGenerator
    [Header("Transition Settings")]
    [SerializeField] private float transitionDistance = 50f;
    private int chunksSpawned = 0;

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

    private void SpawnLevelPart()
    {
        if (chunksSpawned < 3)
        {
            SpawnChunk(false); 
        }
        else
        {
            if (lastPartWasJump)
                SpawnChunk(false);
            else
                SpawnChunk(Random.value < jumpChance);
        }
    }

    public void ResetLevel()
    {
        chunksSpawned = 0;

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

        if(chunksSpawned == 0)
        {
            chosenLevelPart = transitionLevelParts[Random.Range(0, transitionLevelParts.Count)];
            lastPartWasJump = false; 
        } else if(chunksSpawned < 3 && chunksSpawned > 0)
        {
            chosenLevelPart = noObstacleLevelParts[Random.Range(0, noObstacleLevelParts.Count)];
            lastPartWasJump = false;
        }
         else if (isJump)
        {
            chosenLevelPart = jumpLevelParts[Random.Range(0, jumpLevelParts.Count)];
            lastPartWasJump = true; 
        }
        else
        {
            chosenLevelPart = safeLevelParts[Random.Range(0, safeLevelParts.Count)];
            lastPartWasJump = false; 
        }

        chunksSpawned++;

        Transform lastLevelPartTransform = Instantiate(chosenLevelPart, lastEndPosition, Quaternion.identity, environmentContainer);

        lastEndPosition = lastLevelPartTransform.Find("EndPosition").position;
    }
}