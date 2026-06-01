# Stickman Fighting Game — Agent Summary

## Goal
- Build a 2D fighting game in Godot 4 with LAN multiplayer, using the LPC spritesheet generator for character art.

## Constraints & Preferences
- Godot 4 (v4.6+), GDScript, OpenGL 3 (`gl_compatibility`) to avoid Vulkan surface errors.
- Input: A/D move, Space jump, J melee, K ranged, L spell, H dodge.
- Character faces left/right via horizontal flip (not front-facing).
- Single-player focus for now (P2 removed).
- Animations should be slower and feel less snappy than before.
- Free/commercial-use sprite assets required (LPC: CC-BY-SA / GPL / OGA-BY with attribution).

## Progress
### Done
- Generated two LPC character spritesheets (`LPC_Player1.png`, `LPC_Player2.png`) via the Universal LPC Spritesheet Generator with 8+ animation types.
- Downloaded `credits.txt` from the generator for per-asset attribution.
- Removed old NightBorne sprites and temp analysis folders.
- Rewrote `Stickman.gd` to load individual split animation PNGs (from LPC generator's "split" export), using row 1 (left-facing profile) for multi-row files.
- Added action-locked state machine supporting: idle, run, jump, attack (slash), ranged (shoot), spell, hurt, dodge (climb), death.
- Fixed `Input.is_key_pressed()` parse error → replaced with manual edge detection using `last_*` booleans.
- Updated `Arena.tscn` to single player instance at center (960, 1000).
- Updated collision shape (20×44) and sprite scale (3×) for 64×64 LPC frame size.
- Created project-level `CREDITS.txt` for LPC attribution.
- Split PNGs imported into Godot (`.ctex` files in `.godot/imported/`).
- Character now properly faces left (native row 1) or right (`flip_h = true`) — no front-forward pose.

### In Progress
- None — animations are loading and character faces correct directions.

### Blocked
- None currently.

## Key Decisions
- LPC generator's **split export** used for individual animation PNGs (each has 4 direction rows, we use row 1 = left-facing profile).
- `anim.flip_h = facing_right` — no flip when facing left (row 1 is already left-facing), flip when facing right.
- Single character for now to simplify iteration; P2 code stripped from all files.
- Animation speeds slowed based on user feedback (was too fast/snappy).

## Next Steps
1. Add combat logic (hitboxes for melee/ranged/spell, damage, knockback).
2. Add death/respawn flow when falling past the kill floor.
3. Re-add P2 support with a differently-colored character (using second spritesheet).
4. Add health bars and round-reset flow.
5. Add LAN networking via ENet multiplayer peer.

## Critical Context
- Vulkan error avoided by using `gl_compatibility` renderer.
- Split animation PNGs are in `res://Sprites/LPC/split/standard/`.
- Row 1 (index 1, left-facing profile) is used from each 4-row animation PNG; single-row files (hurt, climb) use their only row.
- Animation row offsets: idle y=71 (h=56, 2f), run y=71 (h=56, 8f), jump y=69 (h=58, 5f), slash y=72 (h=56, 6f), shoot y=72 (h=56, 13f), spellcast y=72 (h=56, 7f), hurt y=12 (h=52, 6f), climb y=8 (h=54, 6f).
- `is_key_just_pressed()` does not exist in Godot 4 — track key state manually with last-frame booleans.
- Must open project in Godot editor (or use `--editor --quit`) to trigger asset import of new PNGs before `load()` works.

## Relevant Files
- `Characters/Stickman.gd`: main script — LPC sprite loading (split PNGs per animation), animation state machine, input handling, action lock.
- `Characters/Stickman.tscn`: CharacterBody2D with CollisionShape2D (20×44, offset y=-2) and AnimatedSprite2D (scale 3, offset y=-8).
- `Scenes/Arena.tscn`: single-player arena with floor, walls, camera, pause menu, one Stickman at (960, 1000).
- `Scenes/Arena.gd`: pause menu toggle and button signals.
- `Scenes/MainMenu.tscn` / `MainMenu.gd`: title screen with Host/Join/Quit.
- `Sprites/LPC/split/standard/*.png`: individual animation PNGs (split export from LPC generator).
- `Sprites/LPC/split/credits/`: detailed per-asset LPC attribution.
- `CREDITS.txt`: project-level license summary for LPC assets.
