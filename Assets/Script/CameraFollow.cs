using UnityEngine;

public class CameraFollow : MonoBehaviour
{
    [Header("Target Settings")]
    public Transform target;
    
    [Header("Follow Settings")]
    public Vector3 offset = new Vector3(3f, 1f, -10f);
    public bool followX = true;
    public bool followY = true;
    
    [Header("Dead Zone Settings")]
    public float deadZoneWidth = 2f;
    public float deadZoneHeight = 1f;
    
    [Header("Damping/Smoothing")]
    public float dampingX = 3f;
    public float dampingY = 5f;
    
    [Header("Bounds (Optional)")]
    public bool useBounds = false;
    public float minX = -100f;
    public float maxX = 100f;
    public float minY = -100f;
    public float maxY = 100f;
    
    private Vector3 velocity = Vector3.zero;
    private Vector3 targetPosition;
    
    void LateUpdate()
    {
        if (target == null)
            return;
        
        targetPosition = transform.position;
        
        // Calculate target position with offset
        Vector3 desiredPosition = target.position + offset;
        
        // Dead Zone logic for X axis
        if (followX)
        {
            float deltaX = desiredPosition.x - transform.position.x;
            if (Mathf.Abs(deltaX) > deadZoneWidth / 2f)
            {
                float targetX = desiredPosition.x;
                if (deltaX > 0)
                    targetX = transform.position.x + deadZoneWidth / 2f + (deltaX - deadZoneWidth / 2f);
                else
                    targetX = transform.position.x - deadZoneWidth / 2f + (deltaX + deadZoneWidth / 2f);
                
                targetPosition.x = Mathf.Lerp(transform.position.x, targetX, dampingX * Time.deltaTime);
            }
        }
        
        // Dead Zone logic for Y axis
        if (followY)
        {
            float deltaY = desiredPosition.y - transform.position.y;
            if (Mathf.Abs(deltaY) > deadZoneHeight / 2f)
            {
                float targetY = desiredPosition.y;
                if (deltaY > 0)
                    targetY = transform.position.y + deadZoneHeight / 2f + (deltaY - deadZoneHeight / 2f);
                else
                    targetY = transform.position.y - deadZoneHeight / 2f + (deltaY + deadZoneHeight / 2f);
                
                targetPosition.y = Mathf.Lerp(transform.position.y, targetY, dampingY * Time.deltaTime);
            }
        }
        
        // Apply bounds if enabled
        if (useBounds)
        {
            targetPosition.x = Mathf.Clamp(targetPosition.x, minX, maxX);
            targetPosition.y = Mathf.Clamp(targetPosition.y, minY, maxY);
        }
        
        // Keep the Z position fixed
        targetPosition.z = offset.z;
        
        transform.position = targetPosition;
        
        // Force camera rotation to stay fixed (never rotate with target)
        transform.rotation = Quaternion.identity;
    }
    
    // Draw Dead Zone in Scene view for debugging
    void OnDrawGizmosSelected()
    {
        if (target != null)
        {
            Gizmos.color = Color.yellow;
            Vector3 center = transform.position;
            center.z = target.position.z;
            Gizmos.DrawWireCube(center, new Vector3(deadZoneWidth, deadZoneHeight, 0f));
        }
    }
}
