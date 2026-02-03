using UnityEngine;
using System;

public class PlayerStamina : MonoBehaviour
{
    [Header("Stamina Settings")]
    [SerializeField]
    private float maxStamina = 100f;
    
    [SerializeField]
    private float currentStamina = 100f;
    
    [SerializeField]
    private float staminaRegenRate = 10f; // Per second when running on ground
    
    [SerializeField]
    private float staminaDrainRate = 20f; // Per second when flying
    
    [SerializeField]
    private float minStaminaToFly = 10f;
    
    public event Action<float, float> OnStaminaChanged; // current, max
    public event Action OnStaminaDepleted;
    
    private CatMove catMove;
    private bool isRegenerating = false;
    
    void Start()
    {
        catMove = GetComponent<CatMove>();
        currentStamina = maxStamina;
        
        // Broadcast initial stamina
        OnStaminaChanged?.Invoke(currentStamina, maxStamina);
        
        Debug.Log("PlayerStamina: Initialized with " + currentStamina + "/" + maxStamina + " stamina");
    }
    
    void Update()
    {
        if (catMove == null) return;
        
        // Regenerate stamina when running on ground
        if (catMove.isRunning && !catMove.isFlying && !catMove.isJumping)
        {
            RegenerateStamina(staminaRegenRate * Time.deltaTime);
        }
        
        // Drain stamina when flying
        if (catMove.isFlying)
        {
            DrainStamina(staminaDrainRate * Time.deltaTime);
        }
        
        // Debug log every second
        if (Time.frameCount % 30 == 0)
        {
            Debug.Log("PlayerStamina: Current=" + currentStamina + "/" + maxStamina + 
                      " | Running=" + catMove.isRunning + 
                      " | Flying=" + catMove.isFlying + 
                      " | Jumping=" + catMove.isJumping +
                      " | Percentage=" + (currentStamina/maxStamina*100f).ToString("F1") + "%");
        }
    }
    
    void RegenerateStamina(float amount)
    {
        if (currentStamina >= maxStamina)
        {
            return;
        }
        
        float oldStamina = currentStamina;
        currentStamina = Mathf.Min(currentStamina + amount, maxStamina);
        
        if (currentStamina != oldStamina)
        {
            OnStaminaChanged?.Invoke(currentStamina, maxStamina);
        }
    }
    
    void DrainStamina(float amount)
    {
        float oldStamina = currentStamina;
        currentStamina = Mathf.Max(currentStamina - amount, 0f);
        
        if (currentStamina != oldStamina)
        {
            OnStaminaChanged?.Invoke(currentStamina, maxStamina);
        }
        
        // Stop flying if stamina depleted
        if (currentStamina <= 0f && catMove.isFlying)
        {
            OnStaminaDepleted?.Invoke();
            Debug.Log("PlayerStamina: Stamina depleted - stopping flight");
        }
    }
    
    public bool CanFly()
    {
        return currentStamina >= minStaminaToFly;
    }
    
    public void ResetStamina()
    {
        currentStamina = maxStamina;
        OnStaminaChanged?.Invoke(currentStamina, maxStamina);
        Debug.Log("PlayerStamina: Reset to full stamina");
    }
    
    public float GetCurrentStamina() => currentStamina;
    public float GetMaxStamina() => maxStamina;
    public float GetStaminaPercentage() => currentStamina / maxStamina;
}
