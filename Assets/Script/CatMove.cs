using UnityEngine;

public class CatMove : MonoBehaviour
{
    public float moveSpeed = 5f;
    public float rightwardForce = 2f;
    public float jumpForce = 5f;
    public float backflipThreshold = 0.5f;
    public float backflipRotationSpeed = 720f;
    public float maxHoldTime = 2f;
    public float minRotations = 1f;
    public float maxRotations = 3f;
    public float failedAngleTolerance = 45f;
    public float speedBoostMultiplier = 1.5f;
    public float speedBoostDuration = 2f;
    public bool isRunning = false;
    public bool isJumping = false;
    public bool isBackflipping = false;
    public bool isBackflipFailed = false;
    public bool isSpeedBoosted = false;
    public Animator animator;
    
    private Rigidbody2D rb;
    private bool isGrounded = true;
    private float touchStartTime;
    private bool isTouching = false;
    private float targetRotation = 0f;
    private float currentRotation = 0f;
    private float targetRotationAmount = 0f;
    private bool isHoldingF = false;
    private float fKeyPressStartTime;
    private float originalRightwardForce;
    private float speedBoostEndTime;
    
    void Start()
    {
        QualitySettings.vSyncCount = 0;
        Application.targetFrameRate = 16;
        animator = GetComponent<Animator>();
        rb = GetComponent<Rigidbody2D>();
        
        if (rb == null)
        {
            rb = gameObject.AddComponent<Rigidbody2D>();
            rb.constraints = RigidbodyConstraints2D.FreezeRotation;
        }
        
        originalRightwardForce = rightwardForce;
    }
    
    // Update is called once per frame
    void Update()
    {
        if (isBackflipFailed)
        {
            return;
        }
        
        HandleSpeedBoost();
        
        float horizontal = Input.GetAxis("Horizontal");
        float vertical = Input.GetAxis("Vertical");

        Vector3 movement = new Vector3(horizontal, vertical, 0f);
        Vector3 autoMove = new Vector3(rightwardForce * Time.deltaTime, 0f, 0f);
        
        transform.Translate(movement * moveSpeed * Time.deltaTime + autoMove);
        
        HandleTouchInput();
        
        if (isBackflipping)
        {
            float rotationStep = backflipRotationSpeed * Time.deltaTime;
            transform.Rotate(0f, 0f, rotationStep);
            currentRotation += rotationStep;
            
            if (currentRotation >= targetRotationAmount)
            {
                isBackflipping = false;
                isJumping = false;
                currentRotation = 0f;
                transform.rotation = Quaternion.Euler(0f, 0f, 0f);
            }
        }
        
        if (movement != Vector3.zero || autoMove != Vector3.zero)
        {
            isRunning = true;
        }
        else
        {
            isRunning = false;
        }
        
        animator.SetBool("IsJumping", isJumping);
        animator.SetBool("IsRunning", isRunning);
        animator.SetBool("IsBackflipping", isBackflipping);
        animator.SetBool("IsBackflipFailed", isBackflipFailed);
        animator.SetBool("IsSpeedBoosted", isSpeedBoosted);
        
        Debug.Log("IsRunning: " + isRunning + ", IsJumping: " + isJumping + ", IsBackflipping: " + isBackflipping + ", Failed: " + isBackflipFailed + ", SpeedBoosted: " + isSpeedBoosted);
        Debug.Log("IsGrounded: " + isGrounded + ", CurrentRotation: " + currentRotation + ", Target: " + targetRotationAmount + ", Speed: " + rightwardForce);
    }
    
    void HandleSpeedBoost()
    {
        if (isSpeedBoosted && Time.time >= speedBoostEndTime)
        {
            float smoothSpeed = 5f;
            rightwardForce = Mathf.Lerp(rightwardForce, originalRightwardForce, smoothSpeed * Time.deltaTime);
            
            if (Mathf.Abs(rightwardForce - originalRightwardForce) < 0.01f)
            {
                rightwardForce = originalRightwardForce;
                isSpeedBoosted = false;
                Debug.Log("Speed boost ended - back to normal speed");
            }
        }
    }
    
    void ActivateSpeedBoost()
    {
        isSpeedBoosted = true;
        rightwardForce = originalRightwardForce * speedBoostMultiplier;
        speedBoostEndTime = Time.time + speedBoostDuration;
        Debug.Log("Speed boost activated! New speed: " + rightwardForce);
    }
    
    void HandleTouchInput()
    {
        if (Input.GetMouseButtonDown(0) || (Input.touchCount > 0 && Input.GetTouch(0).phase == TouchPhase.Began))
        {
            touchStartTime = Time.time;
            isTouching = true;
        }
        
        if (Input.GetMouseButtonUp(0) || (Input.touchCount > 0 && Input.GetTouch(0).phase == TouchPhase.Ended))
        {
            float touchDuration = Time.time - touchStartTime;
            isTouching = false;
            
            if (isGrounded && !isBackflipFailed)
            {
                if (touchDuration < backflipThreshold)
                {
                    PerformJump();
                }
                else
                {
                    float holdDuration = touchDuration - backflipThreshold;
                    PerformBackflip(holdDuration);
                }
            }
        }
        
        if (Input.GetKeyDown(KeyCode.Space))
        {
            if (isGrounded && !isBackflipFailed)
            {
                PerformJump();
            }
        }
        
        if (Input.GetKeyDown(KeyCode.F))
        {
            if (isGrounded && !isBackflipFailed)
            {
                isHoldingF = true;
                fKeyPressStartTime = Time.time;
            }
        }
        
        if (Input.GetKeyUp(KeyCode.F))
        {
            if (isHoldingF && isGrounded && !isBackflipFailed)
            {
                float holdDuration = Time.time - fKeyPressStartTime;
                PerformBackflip(holdDuration);
                isHoldingF = false;
            }
        }
        
        if (Input.GetKeyDown(KeyCode.R))
        {
            ResetCharacter();
        }
    }
    
    void PerformJump()
    {
        isJumping = true;
        isGrounded = false;
        rb.velocity = new Vector2(rb.velocity.x, jumpForce);
        Invoke("ResetJump", 0.1f);
    }
    
    void PerformBackflip(float holdDuration)
    {
        isBackflipping = true;
        isJumping = true;
        isGrounded = false;
        currentRotation = 0f;
        
        float normalizedHold = Mathf.Clamp01(holdDuration / maxHoldTime);
        float rotations = Mathf.Lerp(minRotations, maxRotations, normalizedHold);
        targetRotationAmount = rotations * 360f;
        
        float jumpMultiplier = 1.2f + (normalizedHold * 0.3f);
        rb.velocity = new Vector2(rb.velocity.x, jumpForce * jumpMultiplier);
        
        Debug.Log("Backflip - Hold Duration: " + holdDuration + "s, Rotations: " + rotations + ", Target Rotation: " + targetRotationAmount);
    }
    
    void ResetJump()
    {
        isJumping = false;
    }
    
    bool CheckBackflipSuccess()
    {
        float currentAngle = transform.eulerAngles.z;
        
        if (currentAngle > 180f)
            currentAngle -= 360f;
        
        float angleFromUpright = Mathf.Abs(currentAngle);
        
        Debug.Log("Landing Angle: " + currentAngle + ", Angle from upright: " + angleFromUpright);
        
        return angleFromUpright <= failedAngleTolerance;
    }
    
    void ResetCharacter()
    {
        isBackflipFailed = false;
        isBackflipping = false;
        isJumping = false;
        isSpeedBoosted = false;
        currentRotation = 0f;
        transform.rotation = Quaternion.Euler(0f, 0f, 0f);
        rb.velocity = Vector2.zero;
        rightwardForce = originalRightwardForce;
        Debug.Log("Character Reset!");
    }
    
    void OnCollisionEnter2D(Collision2D collision)
    {
        if (collision.gameObject.CompareTag("Ground") || collision.gameObject.layer == LayerMask.NameToLayer("Ground"))
        {
            isGrounded = true;
            
            if (isBackflipping)
            {
                bool success = CheckBackflipSuccess();
                
                if (success)
                {
                    Debug.Log("Backflip Success!");
                    isBackflipping = false;
                    isJumping = false;
                    currentRotation = 0f;
                    transform.rotation = Quaternion.Euler(0f, 0f, 0f);
                    animator.SetBool("IsBackflipFailed", false);
                    
                    ActivateSpeedBoost();
                }
                else
                {
                    Debug.Log("Backflip Failed!");
                    isBackflipFailed = true;
                    isBackflipping = false;
                    isJumping = false;
                    rightwardForce = 0f;
                    animator.SetBool("IsBackflipFailed", true);
                }
            }
            else if (!isBackflipFailed)
            {
                isJumping = false;
                transform.rotation = Quaternion.Euler(0f, 0f, 0f);
            }
        }
    }
    
    void OnCollisionStay2D(Collision2D collision)
    {
        if (collision.gameObject.CompareTag("Ground") || collision.gameObject.layer == LayerMask.NameToLayer("Ground"))
        {
            isGrounded = true;
        }
    }
}
