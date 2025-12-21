using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RandomCompositeBackground : MonoBehaviour
{
    [Header("Settings")]
    [SerializeField] private Transform cameraTransform;
    [Tooltip("Chiều rộng CHÍNH XÁC của một background prefab để nối liền mạch.")]
    [SerializeField] private float backgroundWidth = 20f; 
    [Tooltip("Khoảng cách phía sau camera để hủy background cũ.")]
    [SerializeField] private float destroyDistance = 40f; 

    [Header("Background Prefabs")]
    [Tooltip("Kéo các prefab background hoàn chỉnh (Forest, Desert,...) vào đây.")]
    [SerializeField] private List<GameObject> backgroundPrefabs;

    private List<GameObject> spawnedBackgrounds = new List<GameObject>();
    private float nextSpawnX;

    void Start()
    {
        if (cameraTransform == null) cameraTransform = Camera.main.transform;

        // Bắt đầu spawn từ vị trí camera lùi lại một chút để lấp đầy màn hình
        nextSpawnX = cameraTransform.position.x - backgroundWidth;

        // Sinh ra 2 background ban đầu
        SpawnBackground();
        SpawnBackground();
    }

    void Update()
    {
        ManageBackgrounds();
    }

    void ManageBackgrounds()
    {
        // 1. Sinh background mới khi camera tiến gần đến điểm cuối của background hiện tại
        // Sử dụng ngưỡng (ví dụ: backgroundWidth) để đảm bảo sinh trước khi thấy khoảng trống
        if (cameraTransform.position.x > nextSpawnX - backgroundWidth * 1.5f)
        {
            SpawnBackground();
        }

        // 2. Hủy background cũ đã đi quá xa
        if (spawnedBackgrounds.Count > 0)
        {
            GameObject firstBg = spawnedBackgrounds[0];
            if (firstBg != null && firstBg.transform.position.x < cameraTransform.position.x - destroyDistance)
            {
                spawnedBackgrounds.RemoveAt(0);
                Destroy(firstBg);
            }
            else if (firstBg == null) // Xử lý trường hợp bg bị hủy vì lý do khác
            {
                spawnedBackgrounds.RemoveAt(0);
            }
        }
    }

    void SpawnBackground()
    {
        if (backgroundPrefabs.Count == 0) return;

        // Chọn ngẫu nhiên một prefab từ danh sách
        GameObject prefabToSpawn = backgroundPrefabs[Random.Range(0, backgroundPrefabs.Count)];
        
        // Sinh ra prefab tại vị trí spawn tiếp theo (nextSpawnX)
        // Giữ nguyên độ cao Y và Z của object quản lý này
        GameObject newBg = Instantiate(prefabToSpawn, new Vector3(nextSpawnX, transform.position.y, transform.position.z), Quaternion.identity);
        
        // Thêm vào danh sách quản lý
        spawnedBackgrounds.Add(newBg);
        
        // Cập nhật vị trí cho lần spawn tiếp theo
        nextSpawnX += backgroundWidth;
    }
}