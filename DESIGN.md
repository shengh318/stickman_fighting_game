# Stickman Fighting Game — Design Document

> A 1v1 LAN multiplayer fighting game where two stickmen duel with melee, ranged,
> and spell-casting mechanics. Fast hands and game knowledge win.

---

## 1. Tech Stack

| Layer | Choice |
|---|---|
| Engine | **Godot 4** (v4.3+) |
| Language | **GDScript** — one script per scene/node |
| Networking | **ENet** (built into Godot via `ENetMultiplayerPeer` + RPCs) |
| Animation | **Skeleton2D + Bone2D** — native bone rigging |
| UI | **Control nodes** — HealthBar, Button, Label, TextureProgressBar |
| Build | Export as native `.exe` from within Godot |

**Why Godot 4:**

- **Built-in bone animation** — rig a stickman with `Bone2D` nodes in minutes.
  Rotate bones for smooth attacks, dodges, spell casting. No animation engine
  to write.
- **Networking is ~50 lines** — `multiplayer.peer` + `@rpc` annotations handle
  sync automatically. Built-in ENet runs over LAN with no extra libraries.
- **Instant iteration** — GDScript is interpreted; edit → F5 → test. No
  compile step.
- **Zero toolchain setup** — no CMake, no MSVC, no build system. Just download
  the editor and run.
- **Exports as .exe** — native Windows build in one click. Players don't need
  Godot installed.
- **Free** — MIT license, no royalties, no store cut.

---

## 2. Network Model (LAN)

```
 Host (Player 1)               Client (Player 2)
      │                              │
      ├── ENet (UDP) ───────────────┤  auto-connect via IP
      │   built into Godot           │
      │   ENetMultiplayerPeer        │
      │                              │
      ├── @rpc("unreliable") ───────┤  positions, health, state
      │   broadcast 20x/sec          │  loss-tolerant
      │                              │
      ├── @rpc("reliable",           │
      │    "any_peer") ──────────────┤  inputs from client
      │                              │
      └── @rpc("reliable") ─────────┤  spell sequences, match
          (spells, match result)     │  events (must arrive)
```

- **Host-authoritative**: host runs the simulation. Client sends inputs,
  host processes them, broadcasts the result.
- **Client prediction**: client runs a local copy so inputs feel instant.
  Position/state snaps to authoritative data each tick — discrepancy is
  usually <1 frame on LAN.
- **No dedicated server**: one player hosts, the other joins. Works on the
  same network via local IP.

---

## 3. Core Game Loop

Godot does this internally via `_physics_process(delta)` at 60 Hz.

```
_physics_process(delta):
    read_inputs()
    update_network()          # send/receive RPCs
    update_state_machine(delta)
    update_projectiles(delta)
    check_collisions()

_process(delta):
    update_animation_blending(delta)
    update_ui()
```

**Game State Machine** (handled by a global `GameManager`):

```
MainMenu → Lobby → Countdown(3..2..1) → Fighting → Result → MainMenu
```

---

## 4. Player System

### 4.1 Stick Figure Rig (Skeleton2D)

```
Stickman (CharacterBody2D)
├── Skeleton2D
│   ├── Bone2D: hip
│   │   ├── Bone2D: spine
│   │   │   ├── Bone2D: neck
│   │   │   │   └── Sprite2D: head          ← filled circle, highlight
│   │   │   ├── Bone2D: upper_arm_L
│   │   │   │   └── Bone2D: forearm_L       ← each limb is a colored
│   │   │   │       └── Bone2D: hand_L      ← capsule/line sprite
│   │   │   └── Bone2D: upper_arm_R
│   │   │       └── Bone2D: forearm_R
│   │   │           └── Bone2D: hand_R
│   │   ├── Bone2D: thigh_L
│   │   │   └── Bone2D: shin_L
│   │   │       └── Bone2D: foot_L
│   │   └── Bone2D: thigh_R
│   │       └── Bone2D: shin_R
│   │           └── Bone2D: foot_R
│   └── Polygon2D: torso_fill    ← subtle filled shape between bones
└── AnimationPlayer
    ├── idle
    ├── walk
    ├── melee_attack
    ├── dodge
    ├── parry
    ├── cast_start
    └── hitstun
```

Bones are rotated via `AnimationPlayer` with smooth cubic interpolation.
Limb sprites are simple **capsules** (rounded rectangles) instead of thin
lines, giving a polished look. Head is a filled circle with a small highlight
dot.

### 4.2 State Machine

```gdscript
enum State { IDLE, WALK, MELEE, MELEE_ENHANCED, DODGE, PARRY,
             CASTING, HITSTUN, DEAD }
```

| State | Behavior |
|---|---|
| `IDLE` | Standing, minor breathing animation |
| `WALK` | Moving left/right, legs cycle |
| `MELEE` | 100ms windup → 50ms active → 100ms recovery |
| `MELEE_ENHANCED` | Same but with glow + 1.5x damage |
| `DODGE` | 200ms dash, invincible for 150ms |
| `PARRY` | 150ms arms-crossed pose, reflects melee |
| `CASTING` | Hands raised, spell HUD visible |
| `HITSTUN` | 300ms knockback, no actions |
| `DEAD` | Ragdoll fall → respawn or match end |

### 4.3 Input Mapping

| Action | Player 1 | Player 2 |
|---|---|---|
| Move Left / Right / Jump / Down | A / D / W / S | ← / → / ↑ / ↓ |
| Melee Attack | R | \ (Backslash) |
| Dodge | Q | [ |
| Parry | E | ] |
| Ranged Attack | C | ' (Apostrophe) |
| Cast Spell | F | ; (Semicolon) |
| Enhance Melee | Space | Enter |
| Spell Slot 1-4 | 1,2,3,4 | 7,8,9,0 (numpad) |

**Spell sequence input always uses Arrow Keys** (same for both players).
The arrow keys are directional inputs for spell sequences.

---

## 5. Combat System

### 5.1 Melee

- Press Melee → enter `MELEE` state
- 3-frame windup → 1 active frame (hitbox extends from hand bone)
- On hit: deal damage + knockback + enter `HITSTUN`
- **Enhanced**: press Enhance → glows for 5s. Next melee in that window
  deals 1.5x damage, more knockback, larger hitbox.

### 5.2 Parry

- Press Parry → enter `PARRY` for 5 frames
- If opponent's melee active frame hits during this → parry succeeds:
  - Attacker staggered (longer recovery)
  - Defender can counter-attack immediately
- If no attack comes, small recovery penalty

### 5.3 Dodge

- Press Dodge → dash 150px in movement direction
- Invincible during dash
- 300ms cooldown before next dodge

### 5.4 Ranged Attack

- Press Ranged → spawn projectile from hand
- Moves in facing direction at fixed speed
- Disappears on contact with opponent, obstacle, or after 2s
- 500ms cooldown

---

## 6. Spell System (Core Mechanic)

### 6.1 Casting Flow

```
Step 1: Press Cast button
    → Enter CASTING state
    → Spell wheel / slots appear near character
    → Timer bar starts (3.0 seconds)

Step 2: Select spell (press 1-4)
    → Selected spell's sequence(s) appear on HUD
    → Example: Fireball = ↓↓↑→

Step 3: Input sequence with Arrow Keys
    ↑ ↓ ← →
    → Each correct press advances to next input
    → Visual feedback: filled dots / highlight
    → Wrong input does NOT reset (forgiving) — just ignored

Step 4: Outcome
    Success (all inputs entered before timer expires):
        → Spell fires (projectile or instant effect)
        → Spell enters cooldown (5-12s)
    Failure (timer expires):
        → Spell fizzles with small particle puff
        → Penalty cooldown (2s)
    Interrupted (hit during casting):
        → Spell fizzles immediately
        → Enter HITSTUN, penalty cooldown (3s)
```

### 6.2 Spell Book

| Spell | Sequence | Effect | Cooldown |
|---|---|---|---|
| Fireball | `↓ ↓ ↑ →` | Fast projectile, 15 dmg | 5s |
| Ice Shard | `↓ ↑ ← →` | Slower homing, slows on hit | 7s |
| Lightning | `↑ ↑ ↓ ↓ ← → ← →` | Instant hit-scan, 20 dmg | 10s |
| Shield | `→ ← → ←` | Absorbs one hit, breaks | 12s |

Longer sequences = more powerful effects. Sequences are displayed on screen
during casting.

### 6.3 Interruption

- Any damage during casting → spell cancelled
- Risk-reward: casting a Lightning bolt requires 8 inputs over 3 seconds,
  leaving you wide open
- Skilled players predict when opponent is about to cast and punish

---

## 7. Arena & Obstacles

### 7.1 Layout

- Single-screen arena (1920×1080 logical)
- Floor, left/right walls
- Background with subtle parallax

### 7.2 Obstacles

| Type | Visual | Behavior |
|---|---|---|
| **Crate** | Wooden box | 40 HP, breaks after ~2 hits, blocks projectiles |
| **Pillar** | Stone column | Indestructible, full cover, can circle around |
| **Low Wall** | Half-height wall | Covers lower body, projectiles pass over head |

Obstacles are critical for dodging spells. A pillar between you and a fireball
means the fireball hits the pillar instead.

---

## 8. Graphical Style (Polished Stick Figures)

### Character Visuals

- **Bones as capsules**: each limb segment is a rounded rectangle with width
  (e.g., 6px for arms, 8px for legs, 12px for torso)
- **Head**: filled circle (radius 14px) with a small highlight circle
- **Colors**: Player 1 = Red (#e74c3c → #ff6b6b gradient), Player 2 = Blue
  (#3498db → #5dade2 gradient)
- **Eyes**: two small white dots on head in the direction the player faces
- **Weapon**: short sword/glow stick appears in hand during melee (extends
  from forearm bone)

### Effects

- **Hit sparks**: burst of 6-8 small particles on contact (#ffffff → fade)
- **Attack trails**: arc line following weapon swing (fades over 200ms)
- **Dodge trail**: afterimage ghost during dodge (semi-transparent copy)
- **Spell glow**: subtle pulsing radial gradient from hands during casting
- **Hit flash**: character tints white for 50ms on taking damage
- **Screen shake**: 3px shake on heavy hits, 6px on Lightning bolt
- **Health bar**: smooth lerped bar above head, red → green gradient

### Arena Visuals

- **Background**: dark gradient (#1a1a2e → #16213e)
- **Floor**: slightly lighter platform with subtle grid lines
- **Parallax**: distant city silhouette (simple rectangles) scroll slowly
- **Obstacles**: crates = brown with cross planks, pillars = grey stone

---

## 9. Project Structure

```
stickman_fighting_game/
├── project.godot                 # Godot project file
├── icon.svg                      # Window icon
├── DESIGN.md
│
├── Scenes/
│   ├── MainMenu.tscn             # Title screen with Host / Join buttons
│   ├── Lobby.tscn                # LAN lobby (IP entry, ready-up)
│   ├── Arena.tscn                # Root scene for the fight
│   └── ResultScreen.tscn         # Win/lose screen
│
├── Characters/
│   ├── Stickman.tscn             # Skeleton2D-rigged stickman scene
│   ├── Stickman.gd               # State machine, movement, combat methods
│   └── StickmanAnimator.gd       # Bone rotation helpers, tween wrappers
│
├── Combat/
│   ├── MeleeSystem.gd            # Hitbox active frames, parry windows
│   ├── SpellSystem.gd            # Sequence matching, spell book, cooldowns
│   ├── Projectile.tscn           # Ranged / spell projectile
│   └── Projectile.gd             # Movement, collision, lifetime
│
├── Arena/
│   ├── Obstacle.tscn             # Generic obstacle scene (crate/pillar/wall)
│   └── Obstacle.gd               # HP (crate breaks), collision shape
│
├── Network/
│   ├── NetworkManager.gd         # ENet setup, host/join logic
│   └── GameSync.gd               # RPC definitions, state broadcasting
│
├── UI/
│   ├── HealthBar.tscn            # Health bar scene
│   ├── HealthBar.gd
│   ├── SpellHUD.tscn             # Spell sequence + timer + spell slots
│   ├── SpellHUD.gd
│   └── Util/
│       └── ParticleUtils.gd      # Reusable particle effect helpers
│
└── Globals/
    ├── Constants.gd              # All tuning values (damage, cooldowns, speeds)
    ├── SpellBook.gd              # Spell definitions (name, sequence, effect)
    └── InputMapping.gd           # Player 1 and Player 2 input assignments
```

---

## 10. Implementation Order (Phases)

| Phase | What | Deliverable |
|---|---|---|
| **P1** | Project scaffold + main menu scene | `project.godot`, `MainMenu.tscn`, scene switching |
| **P2** | Stickman rig (Skeleton2D) + movement | Character moves, bone animation plays |
| **P3** | Melee + parry + dodge (local 2P) | Two stickmen can fight locally |
| **P4** | Ranged attacks + projectiles | Projectile spawning, collision |
| **P5** | Spell system (HUD, sequence input, casting) | Full casting flow works locally |
| **P6** | Arena + obstacles | Map layout, collision, blocking |
| **P7** | LAN networking | Host/join, state sync, remote play |
| **P8** | Polish | Health bars, particles, screen shake, sounds, menus |

---

## 11. Installation & Setup (For You)

### Step 1: Download Godot 4

Go to: **https://godotengine.org/download/windows/**

Download the **Godot Engine - .NET** version (64-bit) — actually, the standard
**Godot Engine** (not .NET) is fine since we're using GDScript.

Get the **Godot_v4.3-stable_win64.exe.zip** (or whatever the latest 4.x stable
is). It's ~60MB.

### Step 2: Extract

Unzip the archive anywhere — `C:\Godot\` or `D:\Games\Godot\` or even your
desktop. There's no installer. The `.exe` is the editor.

### Step 3: Open Project

1. Launch `Godot_v4.3-stable_win64.exe`
2. Click **Import** button
3. Navigate to `D:\test_codes\stickman_fighting_game\`
4. Select `project.godot` (once I create it)
5. Click **Open**

### Step 4: Run

- Press **F5** (or click the Play button) to run the game
- Godot auto-detects `MainMenu.tscn` as the default scene (we'll set this up)

### Step 5 (for multiplayer):

1. Export a build: **Project → Export** → add Windows → **Export Project**
2. Run one instance of the exported `.exe` (host)
3. Run the editor or another exported copy (client)
4. Host clicks **Host** → client enters host IP → **Join** → fight

---

## 12. Design Philosophy

- **Speed over flash** — responsive controls and tight netcode matter more
  than visual complexity. The polished stick figure style gives a clean look
  without heavy assets.
- **Skill determines outcome** — all moves are symmetric. The only difference
  between players is hand speed, timing, and spell sequence knowledge.
- **Risk-reward on spells** — longer sequences = stronger effects, but
  vulnerability during casting.
- **LAN-first** — low latency means simple host-authoritative sync works
  without complex rollback netcode.

---

## Appendix: Key Script Skeleton (Stickman.gd)

```gdscript
extends CharacterBody2D
class_name Stickman

@export var player_id: int = 1

enum State { IDLE, WALK, MELEE, MELEE_ENHANCED, DODGE, PARRY,
             CASTING, HITSTUN, DEAD }

var state: State = State.IDLE
var health: float = 100.0
var enhance_timer: float = 0.0

func _ready() -> void:
    InputMapping.assign_actions(player_id)

func _physics_process(delta: float) -> void:
    # Only process locally controlled stickmen
    if not is_multiplayer_authority():
        return

    match state:
        State.IDLE:
            handle_idle(delta)
        State.WALK:
            handle_walk(delta)
        State.MELEE:
            handle_melee(delta)
        # ... etc

func take_damage(amount: float) -> void:
    health -= amount
    if health <= 0.0:
        change_state(State.DEAD)
    else:
        change_state(State.HITSTUN)
    # Sync to other peers
    sync_state.rpc(position, velocity, health, state)

@rpc("unreliable")
func sync_state(pos: Vector2, vel: Vector2,
                hp: float, st: int) -> void:
    position = pos
    velocity = vel
    health = hp
    state = st as State
```
