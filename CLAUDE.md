# Project Fox

Third-person action-shooter prototype (Godot 4.7, typed GDScript). Magical-steampunk
animal/fantasy creatures. Priorities: game feel, weapon variety, enemy attack-pattern
variety, weapon levelling. Art is coloured primitives until real assets exist.

## Where things live

Almost everything is built in code; scenes are thin. Every playable scene has a `LevelRoot`
root script (`scripts/world/level_root.gd`) that builds the player, HUD, pause menu and lighting
at runtime. `scenes/main.tscn` (the main scene, the wave arena, `Arena extends LevelRoot`) holds
level `Block`s, `Crate`s, `Hazards`, the `PlayerSpawn` marker and the `WaveManager` with its spawn
markers. Levels live in `scenes/levels/*.tscn` (placed enemies, checkpoints, gadget gates).

| Path | What |
|---|---|
| `scripts/autoload/` | `InputSetup` (all bindings), `DebugSettings` (F1 outlines, `flash_sphere`), `GameFeel` (time scale, shake, damage numbers, `impact()` puffs) |
| `scripts/core/layers.gd` | Physics layer bits: WORLD, PLAYER, ENEMY, PLAYER_HURTBOX, ENEMY_HURTBOX, REFLECTOR, CONDUCTOR (staff-strikeable sockets) |
| `scripts/combat/` | `HitBox`, `HurtBox`, `Health`, `DamageInfo`, `Explosion`, `AimAssist`, `NoiseEvent` |
| `scripts/player/` | `Player` (movement, wheel, damage reactions in `_on_hurt`, `spawn_point`/`spawn_yaw`), `Gadgets` (registry: `player.has_gadget(id)`), `PlayerTuning`, `CameraRig`, `StaffMelee`, `FoxModel` (rigged GLB in `imported_models/Ember_the_Foxling/`; bakes Idle/Walk, picks clip by speed), `input/` (providers + `PlayerInputState`) |
| `scripts/gadgets/` | Gadget behaviour: `GrappleTail` (player component: ring targeting, reel, rope), `GrappleRing` (anchor, highlight), `LeafCloak` (player component: glide, wings), `SteamVent` (@tool updraft column), `BurrowClaws` (player component: dive, underground move, tunnel, dirt mound), `SoilPatch` (@tool soil disc, optional tunnel `exit`), `ConduitGauntlet` (player component: charge, socket strikes, chain lightning, staff glow), `ConduitSocket` (CONDUCTOR area forwarding staff strikes), `ConduitTerminal` (@tool copper post powering a `target`) |
| `scripts/enemies/` | `Enemy` base (statuses, flight, targeting), one script per enemy, `LobProjectile`. Scenes in `scenes/enemies/` |
| `scripts/weapons/` | `Weapon` base, `WeaponData`/`WeaponLevelStats`, one script per weapon, plus the things weapons leave behind (`Projectile`, `PufferMine`, `Sentry`, `Bulwark`, `VenomGlob`, `MothLanternDecoy`, `Tracer`) |
| `scripts/hazards/` | `Hazard` base + `FireTrap`, `LightningBarrier`, `Lava`, `ClockworkSweeper`, `SteamHammer` |
| `scripts/world/` | `LevelRoot` (runtime setup, placed-enemy reset, level select), `Arena`, `Block` (@tool coloured box with collision), `GadgetGate` (Block per gadget id; conduit = copper door that sinks on `power()`), `Checkpoint`, `GravityRift` (stub), `Crate`, `WaveManager` (wave table + `ENEMY_SCENES`) |
| `scenes/levels/` | Level scenes (`slice_01.tscn`; `anim_showcase.tscn` = fox animation gallery built by `AnimShowcase`: every FoxModel clip at 1× and ¼×, walk/run laps, a speed-ramp lane); listed by the pause menu, loaded with `run.cmd -- --level=<name>` |
| `scripts/ui/` | `Hud`, `PauseMenu`, `Reticle`, `WeaponWheel` (draws only; the player owns selection) |
| `scripts/debug/debug_outline.gd` | Wireframe for every HitBox/HurtBox shape |
| `scripts/debug/ai_debug_view.gd` | Per-enemy awareness overlay (`DebugSettings.show_ai`, F4): state label, sight cone, hearing/alert/leash rings, home, patrol, LOS, noise pulses, alert links |
| `data/` | `player_tuning.tres`, `weapons/*.tres` |
| `tests/` | `test_runner.gd` (finds `tests/unit/test_*.gd`), `TestCase` helpers, `TestDummy` (player stand-in) |
| `tools/` | `test.ps1`, `screenshot.gd` (add a `_capture_*` step for new visual features) |
| `docs/` | Design plans and decisions (`plan-awareness-slice-gadgets.md`, `gadgets.md`) |

Damage reactions: `Player._on_hurt` applies i-frames (`tuning.hurt_iframes`), knockback away
from `info.source_position` and `velocity.y = max(velocity.y, info.knockback_up)`; DoT
(`is_dot`) skips all of that. `Enemy._on_damaged` does the equivalent, scaled by
`knockback_resistance`. `HurtBox.receive()` rejects hits while invulnerable, but `HitBox`
records the hit time first, so a one-shot HitBox that touches a dodging player has spent its
hit for that activation (use `repeat_interval` for lingering hazards).

## Commands

```powershell
.\tools\test.ps1                 # full headless suite (~10s); fails on test failure OR engine error
.\tools\test.ps1 -Filter bull    # tests whose file/method name contains "bull"
godot --path . res://tools/screenshot.tscn -- --wait=4   # renders game, writes screenshots/*.png
godot --path . res://tools/screenshot.tscn -- --wait=4 --weapons   # also one shot per weapon firing
godot --path . res://tools/screenshot.tscn -- --slice      # only the greybox slice shots (slice_*, grapple_*, burrow_*, glide_*, conduit_*)
godot --path . res://tools/screenshot.tscn -- --fox        # only the fox animation contact sheets (fox_walk_side/front, fox_run_side, fox_idle) + showcase_*
.\run.cmd / .\edit.cmd           # play / open editor (extra args pass through)
```

Run the test suite after every change. Use the screenshot tool to check anything visual
(it captures gameplay, scope, firing, weapon wheel, pause menu, hitboxes, a staff swing
chill vs frozen enemies, the two flyers (cruising and diving), an overview, and the slice in
`_capture_slice`: pad view, in-level shots per beat, and top-down / AI-view / angled overviews
framed on the level's Blocks, then the grapple at GrappleLedge: `grapple_ready`, `grapple_reel`,
`grapple_reel_side`, then `_capture_burrow` at pocket A's ambush tunnel: `burrow_mound` (AI view on), `burrow_pop`,
`burrow_sneak`, then `_capture_glide` at the GlideVent: `glide_vent`, `glide_gap`, `glide_gap_side`, then `_capture_conduit` on the shortcut: `conduit_barrier_live`, `conduit_absorb`, `conduit_charged`, `conduit_terminal_dead`, `conduit_powered`, `conduit_door_open`, `conduit_door_from_pad`). Add a `_capture_<gadget>` step per gadget.

## Controls (controller / keyboard+mouse)

Move L-stick/WASD · camera R-stick/mouse · fire RT/LMB · strafe LT/RMB (scope on the rifle) ·
jump A/Space (hold while falling after the double jump: glide) · dodge B/Shift (air, ring highlighted: grapple; on soil: burrow; underground: jump pops out, dodge tunnels) · staff X/F (air: slam; pounce is off by default; staff a live barrier: charge; staff a terminal: power; charged hit on an enemy: chain lightning) · weapon wheel hold
Y/Tab (select with L-stick/WASD/mouse) · cycle LB/RB, Q/E, 1-8 · pause Start/Esc/P · hitboxes Back/F1 · AI debug F4 (controller: pause menu) · level weapon
D-pad up/F2 · next wave D-pad down/F3.

## Conventions

- **Typed GDScript everywhere.** `untyped_declaration` is an error in project.godot.
  Type for-loop variables (`for e: Enemy in ...`) and lambda params.
- **Controller first, keyboard never locked out.** All bindings live in
  `scripts/autoload/input_setup.gd`. Gameplay reads `PlayerInputState` via an
  `InputProvider`, never `Input` directly (except `DeviceInputProvider`).
- **Feel numbers are data.** Player/camera: `PlayerTuning` (`data/player_tuning.tres`).
  Weapons: `WeaponData` + per-level `WeaponLevelStats` (`data/weapons/*.tres`).
  Enemy timings: `@export` vars on each enemy script. Tests derive expectations from
  these values, so retuning should not break tests.
- **Damage only flows HitBox/projectile/hitscan → HurtBox.** Physics layers in
  `scripts/core/layers.gd`. One `DamageInfo` per hit. Area attacks prefer non-weak-spot
  hurtboxes; precise attacks (projectiles, hitscan) can crit weak spots.
- **Every HitBox/HurtBox gets a DebugOutline** (toggle Back/F1). New shape types must be
  supported in `DebugOutline.append_shape_lines`.
- **Enemies** extend `Enemy`: set body shape/size/colour in `_init`, build hitboxes in
  `_setup`, implement the pattern as states in `_tick_state`. Every transition is logged in
  `state_log` ("state@seconds") so tests can assert sequences and telegraph timings.
  Telegraphs use `telegraph` (glow) and `visual_scale` (squash).
  Unaware enemies show an `AwarenessMarker` ("?" filling with suspicion, "!" on alert; pale, never
  yellow). `_idle_flavour(delta)` runs while resting: visual-only fidgets via `visual_pitch` /
  `visual_yaw` / `visual_scale` / `visual_offset`; no hitboxes, no telegraph glow, no lunge squash.
- **Flyers** set `flying = true` (+ `hover_height`): gravity is off and `desired_velocity.y`
  steers vertically; use `hover_velocity(height)` to cruise. Frozen flyers fall and climb
  back after thawing. Lobbers share `LobProjectile.launch()` and `lead_target()`.
- **Weapons** extend `Weapon`: `_fire()` per shot, `_trigger_update()` for continuous
  weapons, `_on_level_changed()` to rebuild shapes. Kills credit XP to the weapon, including
  kills by things the weapon leaves behind (mines, sentries): pass the weapon along and use
  `weapon.make_damage()`. Loadout order is `Player.DEFAULT_WEAPONS` (= wheel order = keys 1-8).
  `WeaponLevelStats` fields are generic; each weapon script documents which ones it reads.
- **Area damage** goes through `Explosion.detonate()`; position-dependent melee damage uses
  `HitBox.damage_modifier`.
- **Status effects live on `Enemy`**: `add_chill`/`freeze`, `root`, `stagger`, `expose`,
  `add_poison`. The AI runs on `ai_speed()` (chill slows telegraphs too; frozen/staggered
  pause it and cancel hitboxes, then resume via `_state_after_flinch()`). `status_resistance`
  scales everything except expose/poison (0 = immune). New enemies get this for free; new
  attack hitboxes must be HitBox children so `_interrupt()` can switch them off.
- **Awareness** wraps every enemy pattern (`Enemy` "Awareness" exports). Unaware enemies run
  base states (`rest`, `wander`/`patrol`, `suspicious`, `investigate`, `alert`,
  `return_home`) and skip `_tick_state`; noticing ends in `idle`. Sight = range + cone +
  WORLD ray; `suspicion` fills at `notice_rate(distance)`. Damage (not `from_hazard`) or
  point-blank: aware at once. `starts_aware` is false for placed enemies; `WaveManager` and
  `TestCase.spawn_enemy` call `make_always_aware()` (no leash, never forgets). Sounds go
  through `NoiseEvent.emit(pos, radius, source)` (not `Noise`: that name is a built-in class);
  weapons use `WeaponData.noise_radius`. Per-enemy overrides go in `_init`.
- **Lures**: any node in group `"lures"` with a `lure_radius: float` property is targeted
  over the player by enemies in range. Give it a PLAYER_HURTBOX hurtbox so attacks land.
- **Reflect**: areas on `Layers.REFLECTOR` whose parent has `reflect_damage` and `weapon`
  bounce `LobProjectile`s back at their `source`. New enemy projectiles should do the same.
- **Wheel pages**: 8 weapons per page (`Player.WHEEL_PAGE_SIZE`); page 2 holds the
  status/utility weapons.
- **Time scale belongs to `GameFeel`.** Use `set_slowmo(source, scale)` / `clear_slowmo()`
  / `hit_stop()`; never write `Engine.time_scale` directly. Physics still ticks at 60 Hz
  real-time when slowed, so input read in `_physics_process` stays responsive.
- **Melee** lives in `StaffMelee` (timing, hitboxes, pose); the player reads its `phase`
  to drive movement. Tuning is in the Staff combo / Slam and pounce groups of `PlayerTuning`.
- **Hazards** extend `Hazard` (`scripts/hazards/`): neutral, so their HitBoxes use `HIT_MASK`
  (player AND enemy hurtboxes; kills credit no weapon). Same state machine + `state_log` as
  enemies; pressure plates use `make_trigger()` + `creatures_in()`. Instances live under
  `Hazards` in `main.tscn`; keep crates out of their volumes. Add each new type to
  `_capture_hazards()` in the screenshot tool.
- **Levels** (`scenes/levels/<name>.tscn`): root `Node3D` with `level_root.gd`, a `PlayerSpawn`
  Marker3D (its yaw = start facing), `Block`/`GadgetGate` geometry, `Checkpoint`s (yaw = respawn
  facing), and enemies instanced from `scenes/enemies/*.tscn` (patrol route = Marker3D children).
  `WaveManager` is optional. Every Enemy under the level at load is "placed": when the player
  dies and respawns, `LevelRoot` frees and rebuilds them all from a snapshot of their exports
  (dead ones return, living ones go home unaware at full hp). Falling off (kill plane) and
  reaching a checkpoint reset nothing; wave-spawned enemies are never touched. Enemies ignore
  a dead player (`has_target()` false during the respawn delay).
  Patrol Marker3Ds are local to the enemy, so they rotate with its yaw (give patrollers yaw 0
  unless you mean it). Enemies have no pathfinding: keep homes, wander radii and routes in open
  ground, and set `leash_radius` so chases stay in their pocket. Enemies below
  `Enemy.KILL_PLANE_Y` die; the player's kill plane respawns at the last checkpoint.
- **Level metrics**: blockout limits live in `LevelMetrics` (`scripts/world/level_metrics.gd`),
  checked against real jumps by `test_jump_metrics`. Mark critical-path Blocks with group
  `critical_path` and a `path_index` meta in walking order; `test_slice` checks every step
  against the limits and makes each jump with real input. Gated spots must exceed
  `GATE_LEDGE_MIN` / `GATE_GAP_MIN`. `scenes/levels/slice_01.tscn` is the greybox slice (see
  the plan doc for its beats and gates).
- **Gadgets**: ids `Gadgets.ALL` (&"grapple", &"glide", &"burrow", &"conduit") on
  `player.gadgets`; gates are `GadgetGate` blocks with `requires` (`is_open_for(player)`).
  Pause menu has "Unlock All Gadgets" for testing. Gadget code lives in `scripts/gadgets/`:
  a component node on the player (like `StaffMelee`) that the player asks each frame and
  that owns its own visuals; tuning in its own `PlayerTuning` group. Gadgets are context
  actions on existing verbs (no new buttons) and read only `PlayerInputState` via the player.
  Grapple: `GrappleRing` (group `grapple_rings`) anywhere, ~1.4 m above the ledge it should
  land you on (`GadgetGate.RING_HEIGHT`); the body it is mounted under never blocks its own
  line of sight. Dodge in the air with a ring highlighted grapples (instead of the air dodge;
  the release refunds the double jump); dodge or a hit with knockback ≥ `grapple_cancel_knockback`
  lets go; no firing or staff while reeling.
  Glide: `LeafCloak` opens while jump is held, falling, with the double jump spent (so a grapple
  release, which refunds it, needs jump, jump-and-hold); release/landing/dodge/grapple/knockback
  close it (forced closes need a fresh press). Weapons fire while gliding; strafe is off.
  `SteamVent` (group `steam_vents`, `lift_at(pos)`) lifts a glider to near its column top and
  barely nudges anyone else; the glide `GadgetGate` builds one (`gate.vent`). Vents never damage.
  Burrow: a floor dodge on (or onto) a `SoilPatch` (group `soil_patches`, `SoilPatch.at(tree, pos)`)
  dives under it: fox hidden, dirt mound shown, body off (layer 0, mask WORLD), invulnerable,
  `player.is_hidden()` true. Underground movement never leaves the patch; dodge on a linked patch
  (`exit`, either side; burrow `GadgetGate`s build `gate.soil` and link via `link`) tunnels to its
  partner (arrives still under), jump (or dodge on a standalone patch) pops out with a small hop.
  No firing/staff/grapple underground. Enemies: `_resolve_target()` returns null for a hidden
  player (`target_hidden`); aware enemies with `forget_time > 0` lose track (unaware, investigate
  `last_seen_position`, suspicion `LOST_TRACK_SUSPICION`). After popping out the fox stays hidden
  for `burrow_surface_conceal_time` (ended early by a staff hit or firing) and the first staff
  swing hit within `burrow_sneak_window` does ×`burrow_sneak_multiplier` to an unaware enemy
  (a staff press during the hop swings on landing). Keep patches away from lava.
  Conduit: `ConduitGauntlet` reads the staff swing HitBox's overlaps on `Layers.CONDUCTOR` (only
  that HitBox masks it) and calls `conduit_struck(gauntlet, unlocked)` on each `ConduitSocket`'s
  `receiver` once per swing. A `LightningBarrier` that is on (or charging past
  `absorb_min_charge`) gives a charge (max `conduit_max_charges`, no timeout, lost on death) and
  switches off. A `ConduitTerminal` (@tool, group `conduit_terminals`) spends one and powers up
  for good, calling `power()` (else `open()`) on its `target` NodePath; uncharged it clanks.
  Conduit `GadgetGate`s are copper doors: `power()` sinks them into the floor (collision moves
  with the body) and `is_open_for()` is `is_open`; doors are never reset by respawns. A charged
  swing hit on an enemy spends the charge as chain lightning (`discharge`, staggers).
  New strikeable things: give them a `ConduitSocket.make(...)` and a `conduit_struck` method.

## Testing gotchas

- Tests run with `--fixed-fps 60`: one awaited physics frame = 1/60 s, deterministic.
- `TestCase` instances are the 3D world root for each test; use `add_floor`,
  `add_dummy_target`, `spawn_enemy(path, pos, yaw, seed, aware = true)`;
  pass `aware = false` for a placed (unaware, at home) enemy.
- `PROCESS_MODE_DISABLED` removes a CollisionObject from physics. To freeze an
  enemy in a test use `set_physics_process(false)`.
- Area overlaps need a physics frame after spawning before they register.
- Free any Node you instantiate outside the tree, or the leak check fails the run.
- New `class_name` scripts are not always registered by `--import`; test.ps1 verifies the
  class cache and falls back to headless editor scans run for 400 frames (`--quit` exits
  before the background scan finishes). If it still reports a class as unregistered, look
  for a parse error in that script (or a script it depends on).
- `godot.exe` is a GUI-subsystem app: from PowerShell, `$null = & godot ...` or `*> $null`
  returns immediately without waiting. Pipe it (`& godot ... 2>&1 | Out-Null`) to block.
- Status timers accumulate floats: a 0.5s tick can land one frame late, so give tick-count
  assertions a little slack. Tests that kill small enemies with captured lambdas will hit
  freed objects; use the bull (160 hp) as a damage sponge.
- `--check-only --script` reports bogus "Identifier not found: GameFeel" errors because
  autoloads are not loaded in that mode; ignore those.
- Scene reload can't be tested from the runner (it would reload the runner); arena
  restart was verified with a throwaway `-s` SceneTree script instead.
- The harness can hide real-game ordering bugs (hit-stop is off, process order differs). To
  measure the real arena, run a throwaway `extends SceneTree` script from outside the repo:
  `godot --headless --path . -s <abs path>`. It compiles before autoloads exist, so use
  untyped access (`player.get("health")`) instead of class names like `Player`.
