# Quick Stamina Bar Setup - Using Slider (EASIEST METHOD)

## Step-by-Step Guide

### 1. Create the Stamina Bar

1. **In Unity Hierarchy:**
   - Right-click in empty space
   - Go to: **UI > Slider**
   - It will create:
     - Canvas (if you don't have one)
     - EventSystem (if you don't have one)
     - Slider GameObject

2. **Rename it:**
   - Select the new "Slider" object
   - Rename it to: **"StaminaBar"**

### 2. Configure the Slider

1. **Select StaminaBar in Hierarchy**

2. **In Inspector, find "Slider" component:**
   - **Interactable**: ? **UNCHECK THIS** (very important!)
   - **Transition**: None
   - **Navigation**: None
   - **Min Value**: 0
   - **Max Value**: 100
   - **Whole Numbers**: ? **UNCHECK THIS**
   - **Value**: 100

### 3. Style the Slider

1. **Expand StaminaBar in Hierarchy** (click the arrow next to it)
   You'll see:
   ```
   StaminaBar
   ??? Background
   ??? Fill Area
   ?   ??? Fill
   ??? Handle Slide Area
       ??? Handle
   ```

2. **Delete the Handle:**
   - Right-click "Handle Slide Area" ? Delete
   - We don't need this for a stamina bar

3. **Style Background:**
   - Select "Background"
   - In Inspector, find "Image" component
   - Change "Color" to dark gray: 
     - R: 76, G: 76, B: 76, A: 255
     - Or (R: 0.3, G: 0.3, B: 0.3, A: 1)

4. **Style Fill:**
   - Expand "Fill Area"
   - Select "Fill"
   - In Inspector, find "Image" component
   - Change "Color" to cyan/blue:
     - R: 51, G: 204, B: 255, A: 255
     - Or (R: 0.2, G: 0.8, B: 1, A: 1)

### 4. Position and Size

1. **Select StaminaBar (the parent)**

2. **Set RectTransform:**
   - **Width**: 250
   - **Height**: 25
   
3. **Position** (choose one):
   
   **Option A - Top Left:**
   - Anchor: Top-Left
   - Pos X: 130
   - Pos Y: -60 (below health bar)
   
   **Option B - Bottom Left:**
   - Anchor: Bottom-Left
   - Pos X: 130
   - Pos Y: 50

### 5. Add StaminaBarSlider Script

1. **Select StaminaBar**

2. **Click "Add Component"**

3. **Search for:** "StaminaBarSlider"

4. **Click it to add**

5. **In the script component:**
   - **Stamina Slider**: This should auto-fill
     - If not, drag the StaminaBar object here
   - **Change Color Based On Stamina**: ? Check this
   - **Fill Image**: Auto-fills
     - If not, expand Fill Area > drag "Fill" here
   - **High Stamina Color**: Cyan (already set)
   - **Medium Stamina Color**: Yellow 
     - R: 1, G: 0.8, B: 0
   - **Low Stamina Color**: Red
     - R: 1, G: 0.2, B: 0.2

### 6. Optional: Add Segment Dividers

To make it look like 4 segments:

1. **Create Divider 1:**
   - Right-click StaminaBar > UI > Image
   - Rename to "Divider1"
   - Set RectTransform:
     - Width: 2
     - Height: 25 (same as stamina bar)
     - Anchor: Left (0, 0.5)
     - Pos X: 62.5 (25% of 250)
     - Pos Y: 0
   - Set Color: Black (R: 0, G: 0, B: 0, A: 1)

2. **Duplicate for other dividers:**
   - Select Divider1, press Ctrl+D (or Cmd+D)
   - Rename to "Divider2"
   - Set Pos X: 125 (50% of 250)
   
   - Duplicate again
   - Rename to "Divider3"
   - Set Pos X: 187.5 (75% of 250)

### 7. Save as Prefab

1. **Create Prefabs folder** (if you don't have one):
   - In Project window, right-click Assets
   - Create > Folder
   - Name it "Prefabs"

2. **Save StaminaBar as prefab:**
   - Drag "StaminaBar" from Hierarchy
   - Drop it into Prefabs folder

3. **Delete from Hierarchy:**
   - Right-click StaminaBar in Hierarchy
   - Delete

### 8. Assign to GameManager

1. **Find GameManager in Hierarchy**

2. **Select it**

3. **In Inspector, find GameManager script**

4. **Find field: "Stamina Bar Prefab"**

5. **Drag your StaminaBar prefab into this field**

6. **Make sure "UI Canvas" is also assigned**

### 9. Test It!

1. **Press Play**

2. **Click "Start" or "Play" button**

3. **You should see:**
   - Stamina bar appears (full and cyan/blue)
   - Bar is full at start

4. **Press G to fly:**
   - Stamina bar should decrease
   - Color changes: Blue ? Yellow ? Red

5. **Land and run on ground:**
   - Stamina bar should increase back to full

## Troubleshooting

**Bar not showing:**
- Check if StaminaBar prefab is assigned in GameManager
- Check if UI Canvas is assigned
- Make sure bar is positioned inside camera view

**Bar not filling/draining:**
- Check Console for errors
- Make sure PlayerStamina component is on Cat
- Check that StaminaBarSlider script is on StaminaBar

**Can't click anything after adding slider:**
- Make sure "Interactable" is UNCHECKED on Slider component
- This is very important!

**Bar looks weird:**
- Check that Handle Slide Area is deleted
- Check Fill Area's Fill has correct anchor (Left, Fill)

## Result

You should have:
- ? A working stamina bar
- ? Blue color when full
- ? Decreases when flying (press G)
- ? Increases when running on ground
- ? Optional segment dividers for visual style

That's it! Much easier than the filled image method!
