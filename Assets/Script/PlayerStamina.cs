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
            Debug.Log("PlayerStamina: REGEN +" + amount.ToString("F2") + " -> " + currentStamina.ToString("F1") + "/" + maxStamina);
        }
    }
    
    void DrainStamina(float amount)
    {
        float oldStamina = currentStamina;
        currentStamina = Mathf.Max(currentStamina - amount, 0f);
        
        if (currentStamina != oldStamina)
        {
            OnStaminaChanged?.Invoke(currentStamina, maxStamina);
            Debug.Log("PlayerStamina: DRAIN -" + amount.ToString("F2") + " -> " + currentStamina.ToString("F1") + "/" + maxStamina);
        }
        
        // Stop flying if stamina depleted
        if (currentStamina <= 0f && catMove.isFlying)
        {
            OnStaminaDepleted?.Invoke();
            Debug.LogWarning("PlayerStamina: DEPLETED - Stopping flight!");
        }
    }
    
    public bool CanFly()
    {
        bool canFly = currentStamina >= minStaminaToFly;
        if (!canFly)
        {
            Debug.LogWarning("PlayerStamina: Cannot fly - stamina too low (" + currentStamina + " < " + minStaminaToFly + ")");
        }
        return canFly;
    }
    
    // Debug method to manually test stamina
    void OnGUI()
    {
        if (Event.current.type == EventType.KeyDown)
        {
            if (Event.current.keyCode == KeyCode.Minus || Event.current.keyCode == KeyCode.KeypadMinus)
            {
                // Drain 10 stamina
                currentStamina = Mathf.Max(0, currentStamina - 10f);
                OnStaminaChanged?.Invoke(currentStamina, maxStamina);
                Debug.Log("PlayerStamina: DEBUG - Drained 10 stamina manually");
            }
            
            if (Event.current.keyCode == KeyCode.Plus || Event.current.keyCode == KeyCode.KeypadPlus || Event.current.keyCode == KeyCode.Equals)
            {
                // Add 10 stamina
                currentStamina = Mathf.Min(maxStamina, currentStamina + 10f);
                OnStaminaChanged?.Invoke(currentStamina, maxStamina);
                Debug.Log("PlayerStamina: DEBUG - Added 10 stamina manually");
            }
        }
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
