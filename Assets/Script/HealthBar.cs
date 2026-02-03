using UnityEngine;
using UnityEngine.UI;

public class HealthBar : MonoBehaviour
{
    [Header("References")]
    public Image[] heartImages;
    
    [Header("Heart Sprites")]
    public Sprite fullHeart;
    public Sprite threeQuarterHeart;
    public Sprite halfHeart;
    public Sprite quarterHeart;
    public Sprite emptyHeart;
    
    public void UpdateHealth(float currentHealth, int maxHealth)
    {
        // Update each heart image
        for (int i = 0; i < heartImages.Length; i++)
        {
            if (i < maxHealth)
            {
                // Show this heart
                heartImages[i].enabled = true;
                
                // Calculate how much of this heart should be filled
                float heartValue = currentHealth - i;
                
                if (heartValue >= 1f)
                {
                    // Full heart
                    heartImages[i].sprite = fullHeart;
                }
                else if (heartValue >= 0.75f)
                {
                    // Three-quarter heart
                    heartImages[i].sprite = threeQuarterHeart != null ? threeQuarterHeart : fullHeart;
                }
                else if (heartValue >= 0.5f)
                {
                    // Half heart
                    heartImages[i].sprite = halfHeart != null ? halfHeart : fullHeart;
                }
                else if (heartValue >= 0.25f)
                {
                    // Quarter heart
                    heartImages[i].sprite = quarterHeart != null ? quarterHeart : emptyHeart;
                }
                else
                {
                    // Empty heart
                    heartImages[i].sprite = emptyHeart;
                }
            }
            else
            {
                // Hide extra hearts
                heartImages[i].enabled = false;
            }
        }
        
        Debug.Log("HealthBar: Updated to show " + currentHealth + "/" + maxHealth + " hearts");
    }
    
    public void Initialize(int maxHealth)
    {
        // Initialize all hearts as full
        UpdateHealth(maxHealth, maxHealth);
    }
}
