# DARK RADAR — Prototype 0.3 (Tactical Power-Ups + Rare Hunter Mode)

A lightweight Godot 4 2D prototype for the DARK RADAR single-player vertical slice.

## New in Prototype 0.3

### Villain power-up pickups
- Three power-up pickup slots are placed at randomized outdoor spawn locations at match start.
- The available pickup types are RADAR PULSE, ADRENALINE, and DECOY.
- The villain can carry only one unused power-up at a time.
- Press **F** near a glowing pickup to collect it; collected pickups disappear.
- Each pickup respawns after a randomized 28–42 second cooldown at a new outdoor location.
- Press **Q** to activate the carried power-up.
- RADAR PULSE: reveals nearby rescuers and innocent people for 4 seconds, including characters concealed by grass or outside normal nighttime visibility within its radius.
- ADRENALINE: increases unladen villain movement speed for 6 seconds.
- DECOY: creates an 8-second sound lure that nearby unladen rescuers investigate.

### Rare rescuer HUNTER MODE
- After the match has been underway for a while, the game makes rare spawn rolls for a special rescuer cache.
- If it appears, the nearest active rescuer who is not carrying an innocent will attempt to collect it.
- On collection, that rescuer enters HUNTER MODE for exactly 20 seconds.
- The powered rescuer becomes substantially larger and bright magenta/pink, with an aura and HUNTER label.
- The powered rescuer stops rescuing and actively hunts the villain.
- If the empowered rescuer reaches the villain, the villain is caught and the rescuers win immediately. This is the new special elimination exception to the normal five-delivery match ending.
- The villain cannot attack during HUNTER MODE. The HUD shows a persistent survival warning and countdown. If the timer expires, the rescuer returns to normal search behaviour.
- The special cache has a low spawn probability, is temporary, and can activate only once per match.

## Controls
- WASD / Arrow keys: move villain
- E: pick up / drop an innocent
- F: collect a nearby villain power-up
- Q: activate carried power-up
- Space: attack a nearby normal rescuer (disabled during HUNTER MODE)
- R: restart match (also randomizes pickup positions)
- V: reveal both bases (debug / demonstration view)
- Esc: quit

## Existing features retained
- 1800 × 1200 open village with scrolling camera.
- Five innocent NPCs stay outdoors, hide/wander, and flee when dropped.
- Four rescuers search, rescue, return to base, and resume searching after each delivery.
- Two faction-exclusive bases, day/night cycle, flashlight visibility and 3-of-5 scoring.

## Run
1. Extract this folder.
2. Open Godot 4.7.2 Standard.
3. Import `project.godot` from this folder.
4. Press F5.

## Testing notes
This source build has not been executed in the user's Godot installation. Please test a separate extracted copy. Key balance variables are defined at the top of `scripts/main.gd` so they can be tuned after playtesting. The project uses the Compatibility renderer for older integrated graphics.
