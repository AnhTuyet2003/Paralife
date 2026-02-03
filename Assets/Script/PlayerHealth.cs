using UnityEngine;
using System;

public class PlayerHealth : MonoBehaviour
{
    [Header("Health Settings")]
    public int maxHealth = 3;
    public float invincibilityDuration = 2f;
    
    [Header("Sound Effects")]
    public AudioClip damageSound;
    public AudioClip healSound;
    [Range(0f, 1f)]
    public float damageSoundVolume = 1.0f;
    [Range(0f, 1f)]
    public float healSoundVolume = 0.7f;
    
    public event Action<float, int> OnHealthChanged; // current (float), max (int)
    public event Action OnPlayerDied;
    
    private float currentHealth;
    private bool isInvincible = false;
    private float invincibilityTimer = 0f;
    private AudioSource audioSource;
    private SpriteRenderer spriteRenderer;
    
    void Start()
    {
        currentHealth = maxHealth;
        
        // Setup audio
        audioSource = GetComponent<AudioSource>();
        if (audioSource == null)
        {
            audioSource = gameObject.AddComponent<AudioSource>();
        }
        audioSource.playOnAwake = false;
        
        // Get sprite renderer for damage flash effect
        spriteRenderer = GetComponent<SpriteRenderer>();
        
        // Broadcast initial health
        OnHealthChanged?.Invoke(currentHealth, maxHealth);
        
        Debug.Log("PlayerHealth: Initialized with " + currentHealth + "/" + maxHealth + " HP");
    }
    
    void Update()
    {
        // Handle invincibility timer
        if (isInvincible)
        {
            invincibilityTimer -= Time.deltaTime;
            
            // Flash effect during invincibility
            if (spriteRenderer != null)
            {
                float alpha = Mathf.PingPong(Time.time * 10f, 1f);
                Color color = spriteRenderer.color;
                color.a = Mathf.Lerp(0.3f, 1f, alpha);
                spriteRenderer.color = color;
            }
            
            if (invincibilityTimer <= 0f)
            {
                isInvincible = false;
                
                // Reset sprite alpha
                if (spriteRenderer != null)
                {
                    Color color = spriteRenderer.color;
                    color.a = 1f;
                    spriteRenderer.color = color;
                }
            }
        }
    }
    
    public void TakeDamage(float damage)
    {
        if (isInvincible || currentHealth <= 0)
        {
            return;
        }
        
        currentHealth -= damage;
        currentHealth = Mathf.Max(0, currentHealth);
        
        Debug.Log("PlayerHealth: Took " + damage + " damage! Current HP: " + currentHealth + "/" + maxHealth);
        
        // Play damage sound
        PlayDamageSound();
        
        // Broadcast health change
        OnHealthChanged?.Invoke(currentHealth, maxHealth);
        
        // Activate invincibility
        if (currentHealth > 0)
        {
            isInvincible = true;
            invincibilityTimer = invincibilityDuration;
        }
        else
        {
            // Player died
            Die();
        }
    }
    
    public void Heal(float amount)
    {
        if (currentHealth >= maxHealth)
        {
            return;
        }
        
        float oldHealth = currentHealth;
        currentHealth += amount;
        currentHealth = Mathf.Min(currentHealth, maxHealth);
        
        float actualHealAmount = currentHealth - oldHealth;
        
        if (actualHealAmount > 0)
        {
            Debug.Log("PlayerHealth: Healed " + actualHealAmount + " HP! Current HP: " + currentHealth + "/" + maxHealth);
            
            // Play heal sound
            PlayHealSound();
            
            // Broadcast health change
            OnHealthChanged?.Invoke(currentHealth, maxHealth);
        }
    }
    
    void Die()
    {
        Debug.Log("PlayerHealth: Player died!");
        OnPlayerDied?.Invoke();
        
        // Reset sprite alpha
        if (spriteRenderer != null)
        {
            Color color = spriteRenderer.color;
            color.a = 1f;
            spriteRenderer.color = color;
        }
    }
    
    void PlayDamageSound()
    {
        if (damageSound != null && audioSource != null)
        {
            audioSource.PlayOneShot(damageSound, damageSoundVolume);
        }
    }
    
    void PlayHealSound()
    {
        if (healSound != null && audioSource != null)
        {
            audioSource.PlayOneShot(healSound, healSoundVolume);
        }
    }
    
    public void ResetHealth()
    {
        currentHealth = maxHealth;
        isInvincible = false;
        invincibilityTimer = 0f;
        
        // Reset sprite alpha
        if (spriteRenderer != null)
        {
            Color color = spriteRenderer.color;
            color.a = 1f;
            spriteRenderer.color = color;
        }
        
        OnHealthChanged?.Invoke(currentHealth, maxHealth);
        Debug.Log("PlayerHealth: Reset to full health");
    }
    
    public float GetCurrentHealth() => currentHealth;
    public int GetMaxHealth() => maxHealth;
    public bool IsInvincible() => isInvincible;
}
