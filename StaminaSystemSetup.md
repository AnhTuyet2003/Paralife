# Stamina System Setup Guide

## Overview
The stamina system has been implemented with the following features:
- Stamina regenerates when the player is running on the ground
- Stamina drains when the player is flying (pressing G)
- Flying is disabled when stamina is too low
- Multi-segment stamina bar UI (similar to the health bar style)

## Components Added

### 1. PlayerStamina.cs
- Manages stamina regeneration and drainage
- Default settings:
  - Max Stamina: 100
  - Regen Rate: 10 per second (when running on ground)
  - Drain Rate: 20 per second (when flying)
  - Min Stamina to Fly: 10

### 2. StaminaBar.cs
- Visual UI component with multiple segments
- Supports 4 segments by default (configurable)
- Smooth fill animation
- Color customization (cyan/blue for full, dark gray for empty)

### 3. Updated Scripts
- **CatMove.cs**: Now checks stamina before flying and stops flying when depleted
- **GameManager.cs**: Integrated stamina system with game lifecycle

## Unity Setup Instructions

### Method 1: Using UI Slider (EASIEST - RECOMMENDED)

This is the simplest method that works perfectly for a stamina bar!

1. **Create Stamina Bar with Slider:**
   - Right-click in Hierarchy > **UI > Slider**
   - Rename it to "StaminaBar"
   
2. **Configure the Slider:**
   - Select the StaminaBar (Slider) in Hierarchy
   - In Inspector, find the **Slider component**:
     - **Interactable**: UNCHECK (we don't want players to drag it)
     - **Min Value**: 0
     - **Max Value**: 100
     - **Value**: 100
     - **Whole Numbers**: UNCHECK

3. **Style the Slider:**
   - Expand "StaminaBar" in Hierarchy to see its children:
     - Background
     - Fill Area > Fill
     - Handle Slide Area (you can delete this - we don't need it)
   
   - Select **Background**:
     - Change color to dark gray (R: 0.3, G: 0.3, B: 0.3, A: 1)
   
   - Expand **Fill Area**, then select **Fill**:
     - Change color to cyan/blue (R: 0.2, G: 0.8, B: 1, A: 1)

4. **Position the Slider:**
   - Select StaminaBar (the main Slider object)
   - Set RectTransform:
     - Width: 200-300
     - Height: 20-30
     - Position where you want (e.g., below health bar)

5. **Create Segments Look (Optional):**
   - Create 3 vertical divider lines between segments:
     - Right-click StaminaBar > **UI > Image** (create 3 times)
     - Name them: "Divider1", "Divider2", "Divider3"
     - For each divider:
       - Set Width: 2-3 pixels
       - Set Height: Same as slider height
       - Set Color: Black or dark color
       - Position at 25%, 50%, and 75% of the slider width
   - This creates the visual appearance of 4 segments!

6. **Add StaminaBar Component:**
   - Select the StaminaBar (main Slider)
   - Click **Add Component** > **Stamina Bar** script
   - In the StaminaBar script inspector:
     - Ignore the "Stamina Segments" array (we'll modify the script)

7. **Save as Prefab:**
   - Drag StaminaBar to your Prefabs folder
   - Delete from Hierarchy

---

### Method 2: Using Filled Images (Original Method)

**Only use this if Method 1 doesn't work for you**

1. **Create UI Structure:**
   - Right-click in Hierarchy > UI > Image (NOT Panel)
   - Rename it to "StaminaBarContainer"
   - Add another Image as child: Right-click StaminaBarContainer > UI > Image
   - Rename the child to "Segment1"

2. **Configure Each Segment:**
   - Select "Segment1"
   - Look at the **Inspector panel on the right**
   - Scroll down until you see the **Image** component
   - Click the small arrow/triangle next to "Image" text to expand it
   - You should now see:
     - **Image Type**: Click the dropdown, select "Filled"
     - **Fill Method**: Select "Horizontal"  
     - **Fill Origin**: Select "Left"
     - **Fill Amount**: Set to 1
   
3. **Create More Segments:**
   - Duplicate Segment1 three times (Ctrl+D or Cmd+D)
   - Rename to: Segment2, Segment3, Segment4
   - Arrange them horizontally next to each other

4. **Add StaminaBar Script:**
   - Select StaminaBarContainer
   - Add Component > StaminaBar script
   - Drag all 4 segments into the array

5. **Save as Prefab**

---

## Alternative: Modify Script to Use Slider

I can also create a simpler version that works directly with Unity's Slider component. Would you like me to create that?

### Step 2: Assign to GameManager

1. Select the GameManager GameObject in the scene
2. In the Inspector, find the GameManager component
3. Assign the StaminaBar prefab to the "Stamina Bar Prefab" field
4. Make sure "UI Canvas" is assigned (same canvas as health bar)

### Step 3: Configure Stamina Settings

1. Start the game once to generate the PlayerStamina component on the cat
2. Stop the game
3. Select the Cat prefab and adjust PlayerStamina settings if needed:
   - Max Stamina: 100 (default)
   - Stamina Regen Rate: 10 per second
   - Stamina Drain Rate: 20 per second
   - Min Stamina To Fly: 10

### Step 4: Position the UI

Position the stamina bar on screen:
- **Option 1**: Below the health bar
- **Option 2**: Above the health bar
- **Option 3**: Bottom-left corner of screen

Recommended layout:
```
Top-Left:
- Health Bar (hearts)
- Stamina Bar (segments)

Or Bottom-Left:
- Distance/Score (top)
- Stamina Bar (middle)
- Health Bar (bottom)
```

## Testing

1. **Test Stamina Regeneration:**
   - Start the game
   - Let the player run on the ground
   - Watch stamina fill up (if it was drained)

2. **Test Stamina Drainage:**
   - Press G to start flying
   - Watch stamina drain
   - Player should stop flying when stamina hits 0

3. **Test Cannot Fly:**
   - Let stamina drain completely
   - Try pressing G
   - Player should not be able to fly until stamina regenerates to at least 10

## Customization

### Change Stamina Colors
Edit in StaminaBar Inspector:
- Full Color: Change to match your game's theme
- Empty Color: Darker version of full color or gray

### Change Segment Count
Edit in StaminaBar Inspector:
- Segment Count: 3, 4, 5, or more
- Create matching number of segment Images in Unity

### Adjust Regen/Drain Rates
Edit PlayerStamina on Cat GameObject:
- Increase Regen Rate: Faster stamina recovery
- Increase Drain Rate: Flying costs more stamina
- Adjust Min Stamina To Fly: Minimum threshold

### Change Flying Duration
Edit CatMove on Cat GameObject:
- Flying Duration: Maximum time flying (independent of stamina)
- Note: Stamina can now end flight early

## Troubleshooting

**Stamina bar not showing:**
- Check if StaminaBar prefab is assigned in GameManager
- Check if UI Canvas is assigned in GameManager
- Check if stamina bar is being hidden by other UI elements

**Stamina not regenerating:**
- Player must be running on the ground (not jumping or flying)
- Check if isRunning flag is true in CatMove

**Can't fly:**
- Check if stamina is above Min Stamina To Fly (default: 10)
- Check console for "Not enough stamina to fly!" message

**Stamina bar segments not filling:**
- Ensure all segments are assigned in StaminaBar component
- Check that Image Type is set to "Filled" for all segments
- Check Fill Method is "Horizontal"
