using UnityEngine;
using Cinemachine;

public class CameraLimit : CinemachineExtension
{
    [SerializeField] private float minY = -4.5f; // Mức thấp nhất camera được phép xuống (chỉnh số này trong Inspector)

    protected override void PostPipelineStageCallback(
        CinemachineVirtualCameraBase vcam,
        CinemachineCore.Stage stage, ref CameraState state, float deltaTime)
    {
        // Chỉ can thiệp vào giai đoạn cuối cùng khi camera đã tính toán xong vị trí
        if (stage == CinemachineCore.Stage.Body)
        {
            Vector3 pos = state.RawPosition;
            // Nếu vị trí camera thấp hơn min Y, ép nó về min Y
            if (pos.y < minY)
            {
                pos.y = minY;
                state.RawPosition = pos;
            }
        }
    }
}