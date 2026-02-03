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
    
    [Header("Sound Effects")]
    public AudioClip shootSound;
    [Range(0f, 1f)]
    public float shootVolume = 1.0f;
    
    [Header("Background Music")]
    public AudioClip gatorMusic;
    [Range(0f, 1f)]
    public float musicVolume = 0.5f;
    public bool loopMusic = true;
    public float musicFadeInDuration = 1.0f;
    public float musicFadeOutDuration = 1.0f;
    
    private float timer;
    private GameObject player;
    private bool isChasing = false;
    private float chaseTimer = 0f;
    private Vector3 targetPosition;
    private Vector3 startPosition;
    private AudioSource audioSource;
    private AudioSource musicAudioSource;
    private bool musicPlaying = false;
    
    void Start()
    {
        player = GameObject.FindGameObjectWithTag("Player");
        startPosition = transform.position;
        startPosition.x = player.transform.position.x + 15f;
        
        // Add or get AudioSource component for shoot sound
        audioSource = GetComponent<AudioSource>();
        if (audioSource == null)
        {
            audioSource = gameObject.AddComponent<AudioSource>();
        }
        audioSource.playOnAwake = false;
        
        // Create separate AudioSource for background music
        musicAudioSource = gameObject.AddComponent<AudioSource>();
        musicAudioSource.playOnAwake = false;
        musicAudioSource.loop = loopMusic;
        musicAudioSource.volume = 0f; // Start at 0 for fade in
    }

    void Update()
    {
        if (player == null) return;
        
        float distance = Vector2.Distance(player.transform.position, transform.position);
        
        if (isChasing)
        {
            // Start music when chasing begins
            if (!musicPlaying)
            {
                StartGatorMusic();
            }
            
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
                StopGatorMusic();
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
        PlayShootSound();
    }
    
    void PlayShootSound()
    {
        if (shootSound != null && audioSource != null)
        {
            audioSource.PlayOneShot(shootSound, shootVolume);
            Debug.Log("Playing shoot sound");
        }
        else if (shootSound == null)
        {
            Debug.LogWarning("Shoot sound not assigned!");
        }
    }
    
    void StartGatorMusic()
    {
        if (gatorMusic != null && musicAudioSource != null && !musicPlaying)
        {
            musicAudioSource.clip = gatorMusic;
            musicAudioSource.Play();
            StartCoroutine(FadeInMusic());
            musicPlaying = true;
            Debug.Log("Starting Gator background music with fade in");
        }
        else if (gatorMusic == null)
        {
            Debug.LogWarning("Gator music not assigned!");
        }
    }
    
    void StopGatorMusic()
    {
        if (musicAudioSource != null && musicPlaying)
        {
            StartCoroutine(FadeOutMusic());
            Debug.Log("Stopping Gator background music with fade out");
        }
    }
    
    IEnumerator FadeInMusic()
    {
        float elapsed = 0f;
        
        while (elapsed < musicFadeInDuration)
        {
            elapsed += Time.deltaTime;
            musicAudioSource.volume = Mathf.Lerp(0f, musicVolume, elapsed / musicFadeInDuration);
            yield return null;
        }
        
        musicAudioSource.volume = musicVolume;
    }
    
    IEnumerator FadeOutMusic()
    {
        float startVolume = musicAudioSource.volume;
        float elapsed = 0f;
        
        while (elapsed < musicFadeOutDuration)
        {
            elapsed += Time.deltaTime;
            musicAudioSource.volume = Mathf.Lerp(startVolume, 0f, elapsed / musicFadeOutDuration);
            yield return null;
        }
        
        musicAudioSource.volume = 0f;
        musicAudioSource.Stop();
        musicPlaying = false;
    }
    
    void OnDestroy()
    {
        // Stop music when Gator is destroyed
        if (musicAudioSource != null && musicPlaying)
        {
            musicAudioSource.Stop();
        }
    }
}
