using System.Collections;
using UnityEngine;

public class WeatherRandomizer : MonoBehaviour
{
    [Header("References")]
    // Kéo các Particle System từ dưới Camera vào đây
    public ParticleSystem rainEffect;
    public ParticleSystem fogEffect;

    [Header("Logic")]
    public float checkInterval = 20f;
    [Range(0, 1)] public float chance = 0.4f;
    public float duration = 40f;

    void Start()
    {
        // Đảm bảo lúc đầu game không có hiệu ứng nào chạy
        if(rainEffect) rainEffect.Stop();
        if(fogEffect) fogEffect.Stop();

        StartCoroutine(WeatherRoutine());
    }

    IEnumerator WeatherRoutine()
    {
        while (true)
        {
            yield return new WaitForSeconds(checkInterval);

            if (Random.value < chance)
            {
                // Chọn ngẫu nhiên giữa mưa hoặc sương mù
                ParticleSystem selected = Random.value > 0.5f ? rainEffect : fogEffect;
                if (selected != null) StartCoroutine(RunEffect(selected));
            }
        }
    }

    IEnumerator RunEffect(ParticleSystem effect)
    {
        Debug.Log("Bắt đầu hiệu ứng: " + effect.gameObject.name);
        effect.Play(); // Chạy hiệu ứng

        yield return new WaitForSeconds(duration);

        effect.Stop(); // Dừng sinh hạt mới, các hạt cũ sẽ tự mờ dần rồi biến mất
        Debug.Log("Kết thúc hiệu ứng.");
    }
}