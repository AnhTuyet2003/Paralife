using UnityEngine;
using UnityEngine.UI;

public class HealthBar : MonoBehaviour
{
    [Header("References")]
    public Image[] heartImages;
    
    [Header("Heart Sprites")]
    public Sprite fullHeart;
    public Sprite emptyHeart;
    
    public void UpdateHealth(int currentHealth, int maxHealth)
    {
        // Update each heart image
        for (int i = 0; i < heartImages.Length; i++)
        {
            if (i < maxHealth)
            {
                // Show this heart
                heartImages[i].enabled = true;
                
                // Full or empty?
                if (i < currentHealth)
                {
                    heartImages[i].sprite = fullHeart;
                }
                else
                {
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
