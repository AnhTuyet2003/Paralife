using UnityEngine;

public class DayNightController : MonoBehaviour
{
    [Header("Time Settings")]
    [Tooltip("Thời gian một ngày (tính bằng giây)")]
    [SerializeField] private float dayDuration = 60f; 
    
    [Header("References")]
    [SerializeField] private Transform celestialPivot; 
    [SerializeField] private Camera mainCam;

    [Header("Colors")]
    [Tooltip("Dải màu của bầu trời trong ngày")]
    [SerializeField] private Gradient skyColor;
    
    [Tooltip("Màu phủ lên nhân vật/địa hình (để tối đi vào ban đêm)")]
    [SerializeField] private Gradient ambientColor;

    [SerializeField] private SpriteRenderer overlayPanel; 

    private float timeOfDay = 0f; 

    void Update()
    {
        timeOfDay += Time.deltaTime / dayDuration;
        if (timeOfDay >= 1) timeOfDay = 0;

        if (celestialPivot != null)
        {
            float angle = timeOfDay * 360f;
            celestialPivot.localRotation = Quaternion.Euler(0, 0, angle);
        }

        if (mainCam != null)
        {
            mainCam.backgroundColor = skyColor.Evaluate(timeOfDay);
        }

        if (overlayPanel != null)
        {
            overlayPanel.color = ambientColor.Evaluate(timeOfDay);
        }
    }
}