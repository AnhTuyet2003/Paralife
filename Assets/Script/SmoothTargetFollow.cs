using UnityEngine;

public class SmoothTargetFollow : MonoBehaviour
{
    [Header("References")]
    [SerializeField] private Transform player; // Kéo con Mèo vào đây

    [Header("Smoothing Settings")]
    [SerializeField] private float smoothSpeed = 0.125f; // Tốc độ mượt (càng nhỏ càng mượt)
    [SerializeField] private bool lockY = true; // Khóa trục Y để khử rung khi vấp đất
    [SerializeField] private float fixedYPosition = 0f; // Độ cao cố định của Camera

    void FixedUpdate()
    {
        if (player == null) return;

        // Tính toán vị trí mục tiêu
        float targetX = player.position.x;
        float targetY = lockY ? fixedYPosition : player.position.y;

        Vector3 desiredPosition = new Vector3(targetX, targetY, 0);

        // Sử dụng Lerp hoặc SmoothDamp để di chuyển Target một cách mượt mà
        // Điều này giúp loại bỏ hoàn toàn các cú vấp nhỏ (micro-stutter) của mèo
        transform.position = Vector3.Lerp(transform.position, desiredPosition, smoothSpeed);
    }
}