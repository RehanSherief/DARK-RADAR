# DARK RADAR — Investor Demo Notes (Prototype 0.3)

## Demonstration goal

Show the core differentiator: one human-controlled villain competes with an AI rescue team over the same five neutral villagers in a larger, explorable village.

## Recommended demo sequence

1. Move through the expanded village while the camera follows the villain.
2. Find and collect one of the three villain power-up types using **F**.
3. Demonstrate the one-slot inventory rule: a second pickup cannot be collected until the carried power-up is used.
4. Activate a power-up with **Q**: RADAR PULSE reveals nearby characters, ADRENALINE increases movement speed, or DECOY distracts unladen rescuers.
5. Observe the pickup disappear and respawn at a new outdoor position after its cooldown.
6. Show the AI rescuers searching independently, carrying innocents, returning to the rescue base and searching again after delivery.
7. If the rare HUNTER MODE cache appears, let a rescuer collect it. Show its larger magenta appearance and the 20-second HUD countdown while the villain evades.
8. Demonstrate that the villain loses if caught, or survives until the 20-second effect expires.
9. Show the rescued / kidnapped counters and the normal majority result when all five innocents are secured.

## Prototype 0.3 systems

- World: 1800 × 1200 units; 960 × 600 scrolling viewport.
- Villain pickups: three active slots, randomized outdoor locations, randomized types, 28–42 second respawn cooldown, one carried power-up at a time.
- RADAR PULSE: 4-second nearby-character reveal.
- ADRENALINE: 6-second movement speed boost.
- DECOY: 8-second temporary lure for unladen rescuers.
- Rare rescuer cache: low-probability spawn checks, limited lifetime and at most one successful activation per match.
- HUNTER MODE: one rescuer becomes larger and magenta, hunts the villain for 20 seconds, and catches the villain on contact.

## Balance variables to tune

The key constants are at the top of `scripts/main.gd`: spawn chance, spawn intervals, pickup lifetime, hunting speed, kill radius, power-up durations and cooldowns. These are initial prototype values, not final balance decisions.

## Honest limitations

- Art and environment objects are placeholders drawn with simple shapes.
- The camera follows the player; this is not a multiplayer camera system.
- AI navigation is intentionally lightweight and may need refinement around obstacles.
- Match balance is not final. Record multiple match times and outcomes, including how often HUNTER MODE appears and how often it catches the villain.
- This build is an early proof of concept, not a production-ready commercial demo.
- This source build has not yet been run in the user's Godot installation; verify parser/runtime behaviour before sharing it externally.
