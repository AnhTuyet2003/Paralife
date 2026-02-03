using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FireBallScript : MonoBehaviour
{
    private GameObject player;
    private Rigidbody2D rb;
    public float force;
    private float timer;
    public int damage = 1;
    
    [Header("Explosion Settings")]
    public GameObject explosionEffect;
    public float explosionDuration = 1.0f;
    public float explosionScale = 10.0f;
    
    [Header("Sound Effects")]
    public AudioClip explosionSound;
    [Range(0f, 1f)]
    public float explosionVolume = 1.0f;
    
    void Start()
    {
        rb = GetComponent<Rigidbody2D>();
        player = GameObject.FindGameObjectWithTag("Player");

        Vector3 direction = player.transform.position - transform.position;
        rb.velocity = new Vector2(direction.x, direction.y).normalized * force;

        float rot = Mathf.Atan2(-direction.y, -direction.x) * Mathf.Rad2Deg;
        transform.rotation = Quaternion.Euler(0, 0, rot + 180);
    }

    void Update()
    {
        timer += Time.deltaTime;
        if (timer >= 10.0f)
        {
            Destroy(gameObject);
        }
    }

    private void OnTriggerEnter2D(Collider2D collision)
    {
        Debug.Log("FireBall collided with: " + collision.gameObject.name + ", Tag: " + collision.gameObject.tag);
        
        if (collision.gameObject.CompareTag("Player"))
        {
            Debug.Log("Hit Player! Spawning explosion...");
            SpawnExplosion();
            PlayExplosionSound();
            
            // Damage player
            PlayerHealth playerHealth = collision.gameObject.GetComponent<PlayerHealth>();
            if (playerHealth != null)
            {
                playerHealth.TakeDamage(damage);
                Debug.Log("FireBall dealt " + damage + " damage to player");
            }
            
            Destroy(gameObject);
        }
        else if (collision.gameObject.CompareTag("Ground"))
        {
            Debug.Log("Hit Ground! Spawning explosion...");
            SpawnExplosion();
            PlayExplosionSound();
            Destroy(gameObject);
        }
    }
    
    private void PlayExplosionSound()
    {
        if (explosionSound != null)
        {
            AudioSource.PlayClipAtPoint(explosionSound, transform.position, explosionVolume);
            Debug.Log("Playing explosion sound at position: " + transform.position);
        }
        else
        {
            Debug.LogWarning("Explosion sound not assigned!");
        }
    }
    
    private void SpawnExplosion()
    {
        if (explosionEffect != null)
        {
            Debug.Log("Spawning explosion at position: " + transform.position + " with scale: " + explosionScale);
            GameObject explosion = Instantiate(explosionEffect, transform.position, Quaternion.identity);
            
            // Scale up the explosion significantly for Sunny Land sprites
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
                Debug.Log("Playing particle system with scale: " + explosionScale);
            }
            
            // If it has an animator, trigger it
            Animator animator = explosion.GetComponent<Animator>();
            if (animator != null)
            {
                animator.enabled = true;
                Debug.Log("Animator enabled");
            }
            
            // If it has a sprite renderer, ensure it's on the right sorting layer
            SpriteRenderer spriteRenderer = explosion.GetComponent<SpriteRenderer>();
            if (spriteRenderer != null)
            {
                spriteRenderer.sortingOrder = 100;
                Debug.Log("Set sprite sorting order to 100");
            }
            
            Destroy(explosion, explosionDuration);
        }
        else
        {
            Debug.LogWarning("Explosion Effect is NULL! Please assign an explosion prefab in the Inspector.");
        }
    }
}
