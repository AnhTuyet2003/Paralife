using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BirdFlyingScript : MonoBehaviour
{
    [Header("References")]
    public GameObject cloudBullet;
    public Transform bulletSpawnPoint;
    
    [Header("Movement Settings")]
    public float fixedXOffset = 15f;
    public float fixedYPosition = 5f;
    public float smoothSpeed = 5f;
    
    [Header("Cloud Spawning Settings")]
    public bool spawnStationaryClouds = true;
    public int cloudsPerSpawn = 5;
    public float minCloudHeight = 2f;
    public float maxCloudHeight = 8f;
    public float minCloudSpacing = 2f;
    public float maxCloudSpacing = 5f;
    public float shootInterval = 2.5f;
    
    [Header("Moving Bullet Settings (if not stationary)")]
    public float minSpreadAngle = 30f;
    public float maxSpreadAngle = 90f;
    
    private float timer;
    private GameObject player;
    
    void Start()
    {
        player = GameObject.FindGameObjectWithTag("Player");
        
        if (player != null)
        {
            // Start at the fixed position
            transform.position = new Vector3(
                player.transform.position.x + fixedXOffset, 
                fixedYPosition, 
                transform.position.z
            );
        }
    }

    void Update()
    {
        if (player == null) return;
        
        // Always stay 15 units to the right of the player
        Vector3 targetPosition = new Vector3(
            player.transform.position.x + fixedXOffset, 
            fixedYPosition, 
            transform.position.z
        );
        
        // Smoothly move to maintain position
        transform.position = Vector3.Lerp(transform.position, targetPosition, smoothSpeed * Time.deltaTime);
        
        // Spawn clouds at intervals
        timer += Time.deltaTime;

        if (timer >= shootInterval)
        {
            timer = 0.0f;
            if (spawnStationaryClouds)
            {
                SpawnStationaryClouds();
            }
            else
            {
                ShootMultipleBullets();
            }
        }
    }

    void SpawnStationaryClouds()
    {
        if (cloudBullet == null)
        {
            Debug.LogWarning("Cloud bullet prefab not assigned!");
            return;
        }

        // Start position ahead of the player
        float currentX = player.transform.position.x + 15f;
        
        for (int i = 0; i < cloudsPerSpawn; i++)
        {
            // Random height for each cloud
            float randomY = Random.Range(minCloudHeight, maxCloudHeight);
            
            // Random spacing for X position
            float randomSpacing = Random.Range(minCloudSpacing, maxCloudSpacing);
            
            // Position with random spacing between clouds
            Vector3 cloudPosition = new Vector3(
                currentX, 
                randomY, 
                0
            );
            
            // Update X for next cloud
            currentX += randomSpacing;
            
            // Spawn the cloud
            GameObject cloud = Instantiate(cloudBullet, cloudPosition, Quaternion.identity);
            
            // Make sure it's stationary
            CloudBullet cloudScript = cloud.GetComponent<CloudBullet>();
            if (cloudScript != null)
            {
                cloudScript.isStationary = true;
            }
        }
        
        Debug.Log("Bird spawned " + cloudsPerSpawn + " stationary clouds at random heights and spacing!");
    }

    void ShootMultipleBullets()
    {
        if (cloudBullet == null || bulletSpawnPoint == null)
        {
            Debug.LogWarning("Cloud bullet or spawn point not assigned!");
            return;
        }

        // Random spread angle for this burst
        float spreadAngle = Random.Range(minSpreadAngle, maxSpreadAngle);
        
        // Calculate the starting angle
        float startAngle = -spreadAngle / 2f;
        float angleStep = spreadAngle / (cloudsPerSpawn - 1);
        
        // Shoot multiple bullets in a spread pattern
        for (int i = 0; i < cloudsPerSpawn; i++)
        {
            float currentAngle = startAngle + (angleStep * i);
            
            // Calculate direction towards player with spread
            Vector3 directionToPlayer = (player.transform.position - bulletSpawnPoint.position).normalized;
            
            // Apply the spread angle
            float angleInRadians = currentAngle * Mathf.Deg2Rad;
            Vector3 spread = new Vector3(
                directionToPlayer.x * Mathf.Cos(angleInRadians) - directionToPlayer.y * Mathf.Sin(angleInRadians),
                directionToPlayer.x * Mathf.Sin(angleInRadians) + directionToPlayer.y * Mathf.Cos(angleInRadians),
                0
            );
            
            // Instantiate the cloud bullet
            GameObject bullet = Instantiate(cloudBullet, bulletSpawnPoint.position, Quaternion.identity);
            
            // Set the bullet's direction and make it moving
            CloudBullet cloudScript = bullet.GetComponent<CloudBullet>();
            if (cloudScript != null)
            {
                cloudScript.isStationary = false;
                cloudScript.SetDirection(spread);
            }
        }
        
        Debug.Log("Bird fired " + cloudsPerSpawn + " moving cloud bullets with " + spreadAngle + " degree spread!");
    }
}
