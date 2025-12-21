using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LevelGenerator : MonoBehaviour
{
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
        lastEndPosition = levelStartPoint.position;
        
        for (int i = 0; i < initialChunks; i++)
        {
            SpawnChunk(false); 
        }
    }

    void Update()
    {
        if (lastEndPosition.x - player.position.x < spawnDistance)
        {
            SpawnLevelPart();
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
            float randomValue = Random.Range(0f, 1f);
            
            if (randomValue < jumpChance) 
            {
                SpawnChunk(true); 
            }
            else
            {
                SpawnChunk(false); 
            }
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

        Transform lastLevelPartTransform = Instantiate(chosenLevelPart, lastEndPosition, Quaternion.identity);

        lastEndPosition = lastLevelPartTransform.Find("EndPosition").position;
    }
}