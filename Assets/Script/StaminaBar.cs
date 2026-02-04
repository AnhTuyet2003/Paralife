using UnityEngine;
using UnityEngine.UI;

public class StaminaBar : MonoBehaviour
{
    [Header("References")]
    [SerializeField]
    private Image[] staminaSegments;
    
    [Header("Stamina Colors")]
    [SerializeField]
    private Color fullColor = new Color(0.2f, 0.8f, 1f); // Cyan/Blue
    
    [SerializeField]
    private Color emptyColor = new Color(0.3f, 0.3f, 0.3f); // Dark gray
    
    [SerializeField]
    private int segmentCount = 4; // Number of stamina segments
    
    [SerializeField]
    private bool smoothTransition = true;
    
    [SerializeField]
    private float transitionSpeed = 5f;
    
    private float targetFillAmount = 1f;
    
    public void Initialize(float maxStamina)
    {
        // Initialize all segments as full
        UpdateStamina(maxStamina, maxStamina);
    }
    
    public void UpdateStamina(float currentStamina, float maxStamina)
    {
        if (staminaSegments == null || staminaSegments.Length == 0)
        {
            Debug.LogWarning("StaminaBar: No stamina segments assigned!");
            return;
        }
        
        float staminaPercentage = Mathf.Clamp01(currentStamina / maxStamina);
        targetFillAmount = staminaPercentage;
        
        if (!smoothTransition)
        {
            ApplyStaminaFill(staminaPercentage);
        }
        
        Debug.Log("StaminaBar: Updated to " + currentStamina + "/" + maxStamina + " (" + (staminaPercentage * 100f) + "%)");
    }
    
    void Update()
    {
        if (smoothTransition)
        {
            // Check if segments array is valid
            if (staminaSegments == null || staminaSegments.Length == 0 || staminaSegments[0] == null)
            {
                return;
            }
            
            // Get current fill from first segment
            float currentFill = staminaSegments[0].fillAmount;
            float newFill = Mathf.Lerp(currentFill, targetFillAmount, Time.deltaTime * transitionSpeed);
            ApplyStaminaFill(newFill);
        }
    }
    
    void ApplyStaminaFill(float totalPercentage)
    {
        int activeSegments = staminaSegments.Length;
        float percentagePerSegment = 1f / activeSegments;
        
        for (int i = 0; i < staminaSegments.Length; i++)
        {
            if (staminaSegments[i] == null) continue;
            
            // Calculate how much this segment should be filled
            float segmentStartPercentage = i * percentagePerSegment;
            float segmentEndPercentage = (i + 1) * percentagePerSegment;
            
            float segmentFill = 0f;
            
            if (totalPercentage >= segmentEndPercentage)
            {
                // Segment is fully filled
                segmentFill = 1f;
            }
            else if (totalPercentage > segmentStartPercentage)
            {
                // Segment is partially filled
                segmentFill = (totalPercentage - segmentStartPercentage) / percentagePerSegment;
            }
            else
            {
                // Segment is empty
                segmentFill = 0f;
            }
            
            staminaSegments[i].fillAmount = segmentFill;
            
            // Change color based on fill amount
            staminaSegments[i].color = segmentFill > 0.01f ? fullColor : emptyColor;
        }
    }
}
