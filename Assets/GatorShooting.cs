using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GatorShooting : MonoBehaviour
{
    public GameObject bullet;
    public Transform bulletSpawn;
    public float moveSpeed = 5f;
    public float chaseDistance = 8f;
    public float chaseDuration = 5f;
    public float shootInterval = 2.0f;
    public float fixedYPosition = 0f;
    
    private float timer;
    private GameObject player;
    private bool isChasing = false;
    private float chaseTimer = 0f;
    private Vector3 targetPosition;
    private Vector3 startPosition;
    
    void Start()
    {
        player = GameObject.FindGameObjectWithTag("Player");
        startPosition = transform.position;
    }

    void Update()
    {
        if (player == null) return;
        
        float distance = Vector2.Distance(player.transform.position, transform.position);
        
        if (isChasing)
        {
            chaseTimer += Time.deltaTime;
            
            // Chase the player
            targetPosition = new Vector3(player.transform.position.x - chaseDistance, fixedYPosition, transform.position.z);
            transform.position = Vector3.MoveTowards(transform.position, targetPosition, moveSpeed * Time.deltaTime);
            
            // Shoot at intervals
            timer += Time.deltaTime;

            if (timer >= shootInterval)
            {
                timer = 0.0f;
                shoot();
            }
            
            // Stop chasing after duration
            if (chaseTimer >= chaseDuration)
            {
                isChasing = false;
                chaseTimer = 0f;
            }
        }
        else
        {
            // Fly away to the left
            transform.position += Vector3.left * moveSpeed * Time.deltaTime;
            
            // Respawn from the left after going far enough
            if (transform.position.x < startPosition.x - 20f)
            {
                // Reset position to the left of the player at fixed Y
                transform.position = new Vector3(player.transform.position.x - 15f, fixedYPosition, transform.position.z);
                isChasing = true;
                timer = 0f;
            }
        }
    }

    void shoot()
    {
        Instantiate(bullet, bulletSpawn.position, Quaternion.identity);
    }    
}
