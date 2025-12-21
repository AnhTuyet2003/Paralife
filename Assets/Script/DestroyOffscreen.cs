using UnityEngine;

public class DestroyOffscreen : MonoBehaviour
{
    private Transform player;
    private float destroyDistance = 150f; 

    void Start()
    {
        player = GameObject.FindGameObjectWithTag("Player").transform;
    }

    void Update()
    {
        if (transform.position.x < player.position.x - destroyDistance)
        {
            Destroy(gameObject);
        }
    }
}