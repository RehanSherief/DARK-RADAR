# DARK RADAR Prototype 0.3 — Change Log

## Villain tactical pickups
- Three pickups spawn at randomized outdoor positions each match.
- Pickup types are RADAR PULSE, ADRENALINE, and DECOY.
- The villain has one power-up inventory slot and collects with F.
- Pickups disappear when collected and respawn at a new location after a randomized 28–42 seconds.
- Q activates the stored power-up.

## Rare rescuer counter-power
- Added a very rare special cache that AI rescuers can seek out.
- Collection activates HUNTER MODE for 20 seconds on one rescuer.
- The powered rescuer is larger and bright magenta/pink so the threat is visually unmistakable.
- The empowered rescuer hunts the villain and catches them on contact.
- The villain cannot attack while HUNTER MODE is active; a persistent HUD countdown warns the player to survive.
- If the villain is caught, rescuers win immediately. If the 20-second timer expires, the rescuer returns to its regular AI search.
- Only one successful HUNTER MODE activation can occur per match.

## Testing note
This project source has been reviewed and packaged, but not run in the user's Godot editor. Validate parser/runtime behaviour and balance on the target laptop before distributing it to testers.
