using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class YetiScript : MonoBehaviour
{
    [Header("Movement")]
    public float moveSpeed = 8f;
    public float jumpSpeed = 15f;
    public float chaseDistance = 10f;
    public float retreatDistance = 3f;
    public float jumpTowardsPlayerDistance = 8f;
    public float jumpInterval = 3f;
    
    [Header("Attack Settings")]
    public float groundPoundForce = 20f;
    public float groundPoundInterval = 4f;
    public float snowballThrowInterval = 2.5f;
    public GameObject snowballPrefab;
    public Transform throwPoint;
    
    [Header("Behavior Timing")]
    public float chaseDuration = 5f;
    public float respawnDistanceLeft = 15f;
    public float activeDuration = 8f;
    public float retreatDuration = 3f;
    public float respawnDistance = 20f;
    
    [Header("Ground Pound Effect")]
    public float shockwaveRadius = 5f;
    public LayerMask playerLayer;
    
    private GameObject player;
    private Rigidbody2D rb;
    private bool isChasing = false;
    private bool isActive = false;
    private bool isGroundPounding = false;
    private float chaseTimer = 0f;
    private bool isRetreating = false;
    private float activeTimer = 0f;
    private float groundPoundTimer = 0f;
    private float snowballTimer = 0f;
    private float jumpTimer = 0f;
    private Vector3 startPosition;
    private bool isGrounded = true;
    
    void Start()
    {
        player = GameObject.FindGameObjectWithTag("Player");
        rb = GetComponent<Rigidbody2D>();
        
        if (rb == null)
        {
            rb = gameObject.AddComponent<Rigidbody2D>();
            rb.gravityScale = 3f;
            rb.freezeRotation = true;
            rb.mass = 1f;
            rb.drag = 0f;
            rb.collisionDetectionMode = CollisionDetectionMode2D.Continuous;
        }
        
        startPosition = transform.position;
    }

    void Update()
    {
        if (player == null) return;
        
        if (isChasing)
        {
            chaseTimer += Time.deltaTime;
            jumpTimer += Time.deltaTime;
            
            // Chase the player - calculate direction
            float distanceToPlayer = player.transform.position.x - transform.position.x;
            float direction = 0f;
            
            if (Mathf.Abs(distanceToPlayer) > retreatDistance)
            {
                direction = Mathf.Sign(distanceToPlayer);
            }
            
            // Jump towards player if far enough and grounded
            if (Mathf.Abs(distanceToPlayer) > jumpTowardsPlayerDistance && isGrounded && !isGroundPounding && jumpTimer >= jumpInterval)
            {
                JumpTowardsPlayer();
                jumpTimer = 0f;
            }
            
            // Move horizontally using velocity
            rb.velocity = new Vector2(direction * moveSpeed, rb.velocity.y);
            
            // Flip sprite to face player
            if (direction > 0)
                transform.localScale = new Vector3(Mathf.Abs(transform.localScale.x), transform.localScale.y, transform.localScale.z);
            else if (direction < 0)
                transform.localScale = new Vector3(-Mathf.Abs(transform.localScale.x), transform.localScale.y, transform.localScale.z);
            
            // Handle attacks
            HandleAttacks();
            
            // Stop chasing after duration
            if (chaseTimer >= chaseDuration)
            {
                isChasing = false;
                chaseTimer = 0f;
            }
        }
        else
        {
            // Move away to the left using velocity
            rb.velocity = new Vector2(-moveSpeed, rb.velocity.y);
            
            // Respawn from the left after going far enough
            if (transform.position.x < startPosition.x - respawnDistanceLeft)
            {
                // Reset position to the left of the player
                transform.position = new Vector3(player.transform.position.x - respawnDistanceLeft, transform.position.y, transform.position.z);
                rb.velocity = Vector2.zero;
                isChasing = true;
                groundPoundTimer = 0f;
                snowballTimer = 0f;
                jumpTimer = 0f;
            }
        }
    }
    
    void JumpTowardsPlayer()
    {
        // Jump with forward momentum towards player
        float horizontalJumpForce = Mathf.Sign(player.transform.position.x - transform.position.x) * moveSpeed * 1.5f;
        rb.velocity = new Vector2(horizontalJumpForce, jumpSpeed * 0.8f);
        isGrounded = false;
        Debug.Log("Yeti jumps towards player to close distance!");
    }
    
    void HandleAttacks()
    {
        if (isGroundPounding) return;
        
        groundPoundTimer += Time.deltaTime;
        snowballTimer += Time.deltaTime;
        
        // Ground Pound Attack
        if (groundPoundTimer >= groundPoundInterval && isGrounded)
        {
            PerformGroundPound();
            groundPoundTimer = 0f;
        }
        
        // Snowball Throw
        if (snowballTimer >= snowballThrowInterval && snowballPrefab != null && throwPoint != null)
        {
            ThrowSnowball();
            snowballTimer = 0f;
        }
    }
    
    void PerformGroundPound()
    {
        StartCoroutine(GroundPoundSequence());
    }
    
    IEnumerator GroundPoundSequence()
    {
        isGroundPounding = true;
        
        // Jump up
        rb.velocity = new Vector2(rb.velocity.x, jumpSpeed);
        isGrounded = false;
        
        Debug.Log("Yeti jumps for ground pound!");
        
        // Wait until Yeti hits the ground
        yield return new WaitUntil(() => isGrounded);
        
        // Create shockwave effect on landing
        CreateShockwave();
        
        Debug.Log("GROUND POUND! Shockwave created!");
        
        yield return new WaitForSeconds(0.5f);
        
        isGroundPounding = false;
    }
    
    void CreateShockwave()
    {
        if (player == null) return;
        
        // Check if player is within shockwave radius
        float distanceToPlayer = Vector2.Distance(transform.position, player.transform.position);
        
        if (distanceToPlayer <= shockwaveRadius)
        {
            Debug.Log("Player caught in Yeti's shockwave!");
            // You can add damage or knockback to the player here
        }
    }
    
    void ThrowSnowball()
    {
        if (player == null || throwPoint == null) return;
        
        GameObject snowball = Instantiate(snowballPrefab, throwPoint.position, Quaternion.identity);
        
        // Calculate direction to player
        Vector2 direction = (player.transform.position - throwPoint.position).normalized;
        
        Rigidbody2D snowballRb = snowball.GetComponent<Rigidbody2D>();
        if (snowballRb != null)
        {
            snowballRb.velocity = direction * 12f; // Throw speed
        }
        
        Debug.Log("Yeti throws snowball!");
    }
    
    void OnCollisionEnter2D(Collision2D collision)
    {
        if (collision.gameObject.CompareTag("Ground") || collision.gameObject.layer == LayerMask.NameToLayer("Ground"))
        {
            isGrounded = true;
        }
        
        if (collision.gameObject.CompareTag("Player"))
        {
            Debug.Log("Yeti collided with player!");
            // Handle player collision damage here
        }
    }
    
    void OnCollisionExit2D(Collision2D collision)
    {
        if (collision.gameObject.CompareTag("Ground") || collision.gameObject.layer == LayerMask.NameToLayer("Ground"))
        {
            isGrounded = false;
        }
    }
    
    void OnDrawGizmosSelected()
    {
        // Visualize shockwave radius in editor
        Gizmos.color = Color.cyan;
        Gizmos.DrawWireSphere(transform.position, shockwaveRadius);
        
        // Visualize chase distance
        Gizmos.color = Color.yellow;
        Gizmos.DrawWireSphere(transform.position, chaseDistance);
        
        // Visualize jump distance
        Gizmos.color = Color.green;
        Gizmos.DrawWireSphere(transform.position, jumpTowardsPlayerDistance);
    }
}
