using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GatorShooting : MonoBehaviour
{
    public GameObject bullet;
    public Transform bulletSpawn;
    private float timer;
    private GameObject player;
    // Start is called before the first frame update
    void Start()
    {
        player = GameObject.FindGameObjectWithTag("Player");
    }

    // Update is called once per frame
    void Update()
    {
        timer += Time.deltaTime;
        float distance = Vector2.Distance(player.transform.position, transform.position);
        //if (distance < 10.0f)
        {
            timer += Time.deltaTime;

            if (timer >= 2.0f)
            {
                timer = 0.0f;
                shoot();
            }       
        }
    }

    void shoot()
    {
        Instantiate(bullet, bulletSpawn.position, Quaternion.identity);

    }    
}
