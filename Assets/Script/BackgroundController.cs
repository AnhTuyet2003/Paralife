using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BackgroundController : MonoBehaviour
{
    private float startPos, length;
    [SerializeField] private GameObject cam;
    [SerializeField] private float parallaxEffect; // Adjust this value to change the parallax effect intensity relative to camera movement

    // Start is called before the first frame update
    void Start()
    {
        startPos = transform.position.x;
        length = GetComponent<SpriteRenderer>().bounds.size.x; // Get the width of the background sprite
    }

    // Update is called once per frame
    void FixedUpdate()
    {
        // Calculate the new position based on camera's x position and parallax effect
        float distance = cam.transform.position.x * parallaxEffect; //0 = background doesn't move, 1 = background moves with camera
        float movement = cam.transform.position.x * (1 - parallaxEffect);

        transform.position = new Vector3(startPos + distance, transform.position.y, transform.position.z);

        // Loop the background when it goes out of view
        if(movement > startPos + length)
        {
            startPos += length;
        }
        else if(movement < startPos - length)
        {
            startPos -= length;
        }
    }
}
