using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CloudBullet : MonoBehaviour
{
    [Header("Bullet Settings")]
    public bool isStationary = true;
    public float force = 8f;
    public int damage = 1;
    public float lifetime = 10.0f;
    
    [Header("Random Size Settings")]
    public float minScale = 0.5f;
    public float maxScale = 2.0f;
    
    [Header("Explosion Settings")]
    public GameObject explosionEffect;
    public float explosionDuration = 1.0f;
    public float explosionScale = 10.0f;
    
    private Rigidbody2D rb;
    private Vector3 direction;
    private float timer;
    
    void Start()
    {
        // Set random size
        float randomScale = Random.Range(minScale, maxScale);
        transform.localScale = Vector3.one * randomScale;
        
        rb = GetComponent<Rigidbody2D>();
        
        if (rb == null)
        {
            rb = gameObject.AddComponent<Rigidbody2D>();
        }
        
        // Configure rigidbody for stationary or moving clouds
        if (isStationary)
        {
            // Stationary cloud - no movement, no gravity
            rb.bodyType = RigidbodyType2D.Kinematic;
            rb.gravityScale = 0f;
            rb.velocity = Vector2.zero;
            
            Debug.Log("Cloud created as stationary obstacle at: " + transform.position + " with scale: " + randomScale);
        }
        else
        {
            // Moving cloud (original behavior)
            rb.bodyType = RigidbodyType2D.Dynamic;
            rb.gravityScale = 0f;
            
            // If no direction was set, aim at player
            if (direction == Vector3.zero)
            {
                GameObject player = GameObject.FindGameObjectWithTag("Player");
                if (player != null)
                {
                    direction = (player.transform.position - transform.position).normalized;
                }
                else
                {
                    direction = Vector3.left;
                }
            }
            
            // Apply velocity
            rb.velocity = new Vector2(direction.x, direction.y) * force;
            
            // Rotate to face direction
            float rot = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg;
            transform.rotation = Quaternion.Euler(0, 0, rot);
        }
    }
    
    void Update()
    {
        timer += Time.deltaTime;
        if (timer >= lifetime)
        {
            Destroy(gameObject);
        }
    }
    
    public void SetDirection(Vector3 dir)
    {
        direction = dir.normalized;
    }
    
    private void OnTriggerEnter2D(Collider2D collision)
    {
        Debug.Log("Cloud bullet collided with: " + collision.gameObject.name + ", Tag: " + collision.gameObject.tag);
        
        if (collision.gameObject.CompareTag("Player"))
        {
            Debug.Log("Hit Player! Dealing " + damage + " damage");
            SpawnExplosion();
            
            // Damage player
            PlayerHealth playerHealth = collision.gameObject.GetComponent<PlayerHealth>();
            if (playerHealth != null)
            {
                playerHealth.TakeDamage(damage);
                Debug.Log("Cloud dealt " + damage + " damage to player");
            }
            
            Destroy(gameObject);
        }
        else if (collision.gameObject.CompareTag("Ground"))
        {
            Debug.Log("Hit Ground!");
            SpawnExplosion();
            Destroy(gameObject);
        }
    }
    
    private void SpawnExplosion()
    {
        if (explosionEffect != null)
        {
            Debug.Log("Spawning cloud explosion at position: " + transform.position);
            GameObject explosion = Instantiate(explosionEffect, transform.position, Quaternion.identity);
            
            // Scale up the explosion
            explosion.transform.localScale = Vector3.one * explosionScale;
            
            // Ensure proper Z position for 2D visibility
            Vector3 pos = explosion.transform.position;
            pos.z = 0;
            explosion.transform.position = pos;
            
            // If it has a particle system, adjust its scale
            ParticleSystem particles = explosion.GetComponent<ParticleSystem>();
            if (particles != null)
            {
                var main = particles.main;
                main.startSizeMultiplier *= explosionScale;
                particles.Play();
            }
            
            // If it has an animator, trigger it
            Animator animator = explosion.GetComponent<Animator>();
            if (animator != null)
            {
                animator.enabled = true;
            }
            
            // If it has a sprite renderer, ensure it's on the right sorting layer
            SpriteRenderer spriteRenderer = explosion.GetComponent<SpriteRenderer>();
            if (spriteRenderer != null)
            {
                spriteRenderer.sortingOrder = 100;
            }
            
            Destroy(explosion, explosionDuration);
        }
    }
}
