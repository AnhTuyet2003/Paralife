using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ChunkObstacleController : MonoBehaviour
{
    [Header("Cấu hình Spwan")]
    [Tooltip("Kéo tất cả các vật cản con trong prefab này vào đây")]
    [SerializeField] private List<GameObject> potentialObstacles;

    [Tooltip("Tỷ lệ xuất hiện của MỖI vật cản (0 = không bao giờ, 1 = luôn luôn)")]
    [Range(0f, 1f)]
    [SerializeField] private float spawnChance = 0.3f; 

    void Start()
    {
        SpawnObstacles();
    }

    private void SpawnObstacles()
    {
        foreach (GameObject obstacle in potentialObstacles)
        {
            float randomValue = Random.value;

            if (randomValue < spawnChance)
            {
                obstacle.SetActive(true);
            }
            else
            {
                obstacle.SetActive(false);
            }
        }
    }
}