using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BackgroundManager : MonoBehaviour
{
    [System.Serializable]
    public class BackgroundTheme
    {
        public GameObject backgroundPrefab;
        public AudioClip backgroundMusic;
    } 

    [SerializeField] private List<GameObject> backgroundSets; // Kéo Background_1, 4, 5 vào đây
    [SerializeField] private GameManager gameManager;
    private AudioSource audioSource;
    [SerializeField] private List<BackgroundTheme> themes;

    void Awake()
    {
        audioSource = GetComponent<AudioSource>();
    }

    void Start()
    {
        if (gameManager != null)
            gameManager.OnGameReset += RandomizeBackground;
            
        RandomizeBackground();
    }

    public void RandomizeBackground()
    {
        foreach (var set in backgroundSets)
        {
            set.SetActive(false);
        }

        int randomIndex = Random.Range(0, backgroundSets.Count);

        backgroundSets[randomIndex].SetActive(true);

        if(randomIndex == 0)
        {
            Vector3 spawnPosition = new Vector3(-11.66066f, 11.45961f, 0f);
            backgroundSets[randomIndex].transform.position = spawnPosition;
        } else if(randomIndex == 1)
        {
            Vector3 spawnPosition = new Vector3(788.8578f, -8.98f, 0f);
            backgroundSets[randomIndex].transform.position = spawnPosition;
        } 
        else if(randomIndex == 2)
        {
            Vector3 spawnPosition = new Vector3(788.8578f, -9.270987f, 0f);
            backgroundSets[randomIndex].transform.position = spawnPosition;
        }

        audioSource.clip = themes[randomIndex].backgroundMusic;
        audioSource.Play();
        Debug.Log("Khởi tạo môi trường ngẫu nhiên: " + backgroundSets[randomIndex].name);
    }
}