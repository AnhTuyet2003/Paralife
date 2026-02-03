using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Simple stamina bar that uses Unity's Slider component.
/// Much easier to set up than the segment-based version.
/// </summary>
public class StaminaBarSlider : MonoBehaviour
{
    [Header("References")]
    [SerializeField]
    private Slider staminaSlider;
    
    [Header("Colors (Optional)")]
    [SerializeField]
    private bool changeColorBasedOnStamina = true;
    
    [SerializeField]
    private Image fillImage;
    
    [SerializeField]
    private Color highStaminaColor = new Color(0.2f, 0.8f, 1f); // Cyan
    
    [SerializeField]
    private Color mediumStaminaColor = new Color(1f, 0.8f, 0f); // Yellow
    
    [SerializeField]
    private Color lowStaminaColor = new Color(1f, 0.2f, 0.2f); // Red
    
    [SerializeField]
    private float mediumThreshold = 0.5f;
    
    [SerializeField]
    private float lowThreshold = 0.25f;
    
    void Start()
    {
        // Auto-find slider if not assigned
        if (staminaSlider == null)
        {
            staminaSlider = GetComponent<Slider>();
            Debug.Log("StaminaBarSlider: Auto-found Slider component: " + (staminaSlider != null));
        }
        
        // Auto-find fill image if not assigned
        if (fillImage == null && staminaSlider != null)
        {
            fillImage = staminaSlider.fillRect?.GetComponent<Image>();
            Debug.Log("StaminaBarSlider: Auto-found Fill Image: " + (fillImage != null));
        }
        
        if (staminaSlider == null)
        {
            Debug.LogError("StaminaBarSlider: No Slider component found!");
        }
        else
        {
            Debug.Log("StaminaBarSlider: Initialized - Slider Min=" + staminaSlider.minValue + 
                      " Max=" + staminaSlider.maxValue + 
                      " Value=" + staminaSlider.value +
                      " Interactable=" + staminaSlider.interactable);
        }
    }
    
    public void Initialize(float maxStamina)
    {
        if (staminaSlider != null)
        {
            staminaSlider.minValue = 0f;
            staminaSlider.maxValue = maxStamina;
            staminaSlider.value = maxStamina;
            Debug.Log("StaminaBarSlider: Initialize called - Set to " + maxStamina + "/" + maxStamina);
        }
        else
        {
            Debug.LogError("StaminaBarSlider: Initialize called but slider is NULL!");
        }
        
        UpdateColor(1f);
        Debug.Log("StaminaBarSlider: Initialized with max stamina: " + maxStamina);
    }
    
    public void UpdateStamina(float currentStamina, float maxStamina)
    {
        if (staminaSlider == null)
        {
            Debug.LogError("StaminaBarSlider: Slider is NULL!");
            return;
        }
        
        float oldValue = staminaSlider.value;
        staminaSlider.maxValue = maxStamina;
        staminaSlider.value = currentStamina;
        
        float percentage = currentStamina / maxStamina;
        UpdateColor(percentage);
        
        Debug.Log("StaminaBarSlider: Updated " + currentStamina.ToString("F1") + "/" + maxStamina + 
                  " (" + (percentage * 100f).ToString("F1") + "%) | SliderValue=" + staminaSlider.value + 
                  " | OldValue=" + oldValue);
    }
    
    void UpdateColor(float percentage)
    {
        if (!changeColorBasedOnStamina || fillImage == null) return;
        
        Color targetColor;
        
        if (percentage <= lowThreshold)
        {
            targetColor = lowStaminaColor;
        }
        else if (percentage <= mediumThreshold)
        {
            targetColor = mediumStaminaColor;
        }
        else
        {
            targetColor = highStaminaColor;
        }
        
        fillImage.color = targetColor;
    }
}
