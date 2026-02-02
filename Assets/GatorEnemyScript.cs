using UnityEngine;
using System;

public class GatorEnemyScript : MonoBehaviour
{
    // Event dispatched when cat collides with obstacle/hole
    public event Action<string> OnObstacleHit;
    public float rightwardForce = 50f;
    public float maxSpeed = 15f;
    public float jumpForce = 12f;
    public float backflipThreshold = 0.5f;
    public float backflipRotationSpeed = 720f;
    public float maxHoldTime = 2f;
    public float minRotations = 1f;
    public float maxRotations = 3f;
    public float failedAngleTolerance = 45f;
    public float speedBoostMultiplier = 1.5f;
    public float speedBoostDuration = 2f;
    public float gravity = 3f;
    public float slopeSpeedMultiplier = 1.3f;
    public float airDrag = 0.98f;
    public bool isRunning = false;
    public bool isJumping = false;
    public bool isBackflipping = false;
    public bool isBackflipFailed = false;
    public bool isSpeedBoosted = false;
    public Animator animator;
    public Rigidbody2D rb;

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
        Application.targetFrameRate = 30;
        animator = GetComponent<Animator>();
        rb = GetComponent<Rigidbody2D>();

        if (rb == null)
        {
            Debug.LogError("No Rigidbody2D found! Adding one...");
            rb = gameObject.AddComponent<Rigidbody2D>();
        }

        rb.bodyType = RigidbodyType2D.Dynamic;
        rb.mass = 1f;
        rb.drag = 0f;
        rb.angularDrag = 0.05f;
        rb.constraints = RigidbodyConstraints2D.None;
        rb.gravityScale = gravity;
        rb.freezeRotation = false;
        rb.collisionDetectionMode = CollisionDetectionMode2D.Continuous;
        rb.interpolation = RigidbodyInterpolation2D.Interpolate;

        originalRightwardForce = rightwardForce;

        Debug.Log("=== CatMove Initialized ===");
        Debug.Log("Rigidbody2D BodyType: " + rb.bodyType);
        Debug.Log("Mass: " + rb.mass);
        Debug.Log("Drag: " + rb.drag);
        Debug.Log("Gravity Scale: " + rb.gravityScale);
        Debug.Log("Rightward Force: " + rightwardForce);
    }

    void Update()
    {
        if (isBackflipFailed)
        {
            return;
        }

        HandleSpeedBoost();
        HandleTouchInput();
        UpdateAnimations();
    }

    void FixedUpdate()
    {
        if (isBackflipFailed)
        {
            return;
        }

        float currentSpeed = isSpeedBoosted ? originalRightwardForce * speedBoostMultiplier : rightwardForce;

        if (rb.velocity.x < maxSpeed)
        {
            rb.AddForce(Vector2.right * currentSpeed, ForceMode2D.Force);
        }

        if (rb.velocity.x > maxSpeed)
        {
            rb.velocity = new Vector2(maxSpeed, rb.velocity.y);
        }

        if (!isGrounded)
        {
            rb.velocity = new Vector2(rb.velocity.x * airDrag, rb.velocity.y);
        }

        if (isBackflipping)
        {
            float rotationStep = backflipRotationSpeed * Time.fixedDeltaTime;
            rb.MoveRotation(rb.rotation + rotationStep);
            currentRotation += rotationStep;

            if (currentRotation >= targetRotationAmount)
            {
                isBackflipping = false;
                isJumping = false;
                currentRotation = 0f;
            }
        }
        else if (isGrounded && !isBackflipFailed)
        {
            float targetAngle = 0f;
            float currentAngle = rb.rotation;
            if (currentAngle > 180f) currentAngle -= 360f;
            if (currentAngle < -180f) currentAngle += 360f;

            float smoothRotation = Mathf.LerpAngle(currentAngle, targetAngle, 10f * Time.fixedDeltaTime);
            rb.MoveRotation(smoothRotation);
        }

        isRunning = rb.velocity.magnitude > 0.1f;

        if (Time.frameCount % 30 == 0)
        {
            Debug.Log("=== Cat Physics Status ===");
            Debug.Log("Velocity: " + rb.velocity);
            Debug.Log("Position: " + transform.position);
            Debug.Log("Grounded: " + isGrounded);
            Debug.Log("Mass: " + rb.mass + ", Drag: " + rb.drag);
            Debug.Log("Force Applied: " + currentSpeed);
        }
    }

    void UpdateAnimations()
    {
        if (animator != null)
        {
            animator.SetFloat("yVelocity", rb.velocity.y);
            animator.SetBool("Grounded", isGrounded);
            animator.SetBool("IsJumping", isJumping);
            animator.SetBool("IsRunning", isRunning);
            animator.SetBool("IsBackflipping", isBackflipping);
            animator.SetBool("IsBackflipFailed", isBackflipFailed);
            animator.SetBool("IsSpeedBoosted", isSpeedBoosted);
        }
    }

    void HandleSpeedBoost()
    {
        if (isSpeedBoosted && Time.time >= speedBoostEndTime)
        {
            isSpeedBoosted = false;
            Debug.Log("Speed boost ended - back to normal speed");
        }
    }

    void ActivateSpeedBoost()
    {
        isSpeedBoosted = true;
        speedBoostEndTime = Time.time + speedBoostDuration;
        Debug.Log("Speed boost activated!");
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
        Debug.Log("Jump! New velocity: " + rb.velocity);
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

        float jumpMultiplier = 1.2f + (normalizedHold * 0.5f);
        rb.velocity = new Vector2(rb.velocity.x, jumpForce * jumpMultiplier);

        Debug.Log("Backflip - Hold Duration: " + holdDuration + "s, Rotations: " + rotations + ", Target Rotation: " + targetRotationAmount);
    }

    bool CheckBackflipSuccess()
    {
        float currentAngle = rb.rotation;

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
        rb.rotation = 0f;
        rb.velocity = Vector2.zero;
        rb.angularVelocity = 0f;
        rightwardForce = originalRightwardForce;
        Debug.Log("Character Reset!");
    }

    void OnCollisionEnter2D(Collision2D collision)
    {
        Debug.Log("Collision detected with: " + collision.gameObject.name + ", Tag: " + collision.gameObject.tag + ", Layer: " + LayerMask.LayerToName(collision.gameObject.layer));

        // Check for obstacle or hole collision first
        if (collision.gameObject.CompareTag("Obstacle") || collision.gameObject.CompareTag("Hole"))
        {
            Debug.Log("Cat collided with " + collision.gameObject.tag);
            OnObstacleHit?.Invoke(collision.gameObject.tag);
            return;
        }

        if (collision.gameObject.CompareTag("Ground") || collision.gameObject.layer == LayerMask.NameToLayer("Ground"))
        {
            isGrounded = true;
            Debug.Log("Cat is now grounded!");

            if (isBackflipping)
            {
                bool success = CheckBackflipSuccess();

                if (success)
                {
                    Debug.Log("Backflip Success!");
                    isBackflipping = false;
                    isJumping = false;
                    currentRotation = 0f;
                    rb.rotation = 0f;
                    rb.angularVelocity = 0f;
                    if (animator != null) animator.SetBool("IsBackflipFailed", false);

                    ActivateSpeedBoost();
                }
                else
                {
                    Debug.Log("Backflip Failed!");
                    isBackflipFailed = true;
                    isBackflipping = false;
                    isJumping = false;
                    rb.velocity = Vector2.zero;
                    rb.angularVelocity = 0f;
                    if (animator != null) animator.SetBool("IsBackflipFailed", true);
                }
            }
            else if (!isBackflipFailed)
            {
                isJumping = false;
                rb.rotation = 0f;
                rb.angularVelocity = 0f;
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

    void OnCollisionExit2D(Collision2D collision)
    {
        if (collision.gameObject.CompareTag("Ground") || collision.gameObject.layer == LayerMask.NameToLayer("Ground"))
        {
            isGrounded = false;
            Debug.Log("Cat left the ground!");
        }
    }
}
