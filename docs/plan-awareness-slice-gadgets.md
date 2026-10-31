# Plan: enemy awareness, greybox slice, first gadgets

Status: approved 2026-10-31. Tasks are done in order; each one ends with a green
`.\tools\test.ps1`, a screenshot check, and a commit to master.

## Decisions

| Decision | Why |
|---|---|
| Enemy awareness first | `Enemy._resolve_target()` always returns the player, so every enemy knows where you are from spawn. Nothing can be stumbled into, snuck past or flanked. |
| Original greybox slice, not a copy of an R&C map | Copying a real layout is too close to recreating that game and bakes in its gating. Scale comes from our own movement numbers. |
| Keep the wave arena | `main.tscn` stays the combat test range; the slice is its own scene. |
| Gadgets after the slice | A gadget only means something against a gap, ledge or grate. The slice leaves gates to design against. |
| Placed enemies in levels, waves in the arena | Aggro, idle and leash only make sense for enemies with a home. `WaveManager` spawns enemies already aware. |
| Dead enemies respawn on checkpoint respawn | When the player dies and respawns at a checkpoint, every placed enemy is reset: dead ones respawn, living ones return home unaware at full health. Reaching a checkpoint alone resets nothing. |
| AI debug view | A toggle (F4 + pause-menu entry, so controller can reach it) shows state, suspicion and every boundary. See task 2. |
| Gadgets use existing verbs, no new buttons | Controller has no free comfortable button. Gadgets are context actions on jump / dodge / staff / fire near their gate objects (details per gadget below). |
| No magnet boots or grind rails as gadgets | Too close to R&C's signature pairing. Instead: **gravity rifts**, magical zones where gravity points a different way (a level feature, not a gadget). Grinding is common across games (Sonic, Jet Set Radio, Sunset Overdrive), so a rail could come back later as a level feature if wanted. |

## Task 1: Awareness core (`Enemy` base)

Awareness wraps the existing patterns. While unaware the base runs its own states and
skips `_tick_state`; on noticing, it plays an alert telegraph and enters `idle`, which
every enemy already hands straight to combat. Enemy subclasses should not need changes.

- `Awareness` export group on `Enemy`: `starts_aware` (default false; `WaveManager.spawn_enemy`
  sets true), `sight_range`, `sight_fov_deg`, `hearing_range`, `notice_time`, `alert_time`,
  `alert_radius`, `leash_radius`, `forget_time`, `point_blank_range` (~3 m). Per-enemy
  overrides in `_init` (bull: far sight, slow notice; rat: good hearing; falcon: wide cone).
- `home_position` (+ home yaw) recorded at `_ready`.
- Perception: distance + cone + line-of-sight ray against `Layers.WORLD` to the player and
  lures. Seeing fills `suspicion` 0..1 (faster when closer); not seeing drains it.
- `Noise.emit(position, radius, source)` static helper (new `scripts/combat/noise.gd` or
  `scripts/enemies/noise.gd`): unaware enemies whose `hearing_range` overlaps go to
  `investigate`. Callers: weapon fire (`noise_radius` on `WeaponData`), staff slam landing,
  `Explosion.detonate()`. Every emit is recorded so the debug view can draw it.
- Unaware states, all in `state_log`: `rest`, `patrol`/`wander` (optional `Marker3D` children
  as patrol points, else random points near home), `suspicious`, `investigate`, `alert`.
  Aware → `idle` (existing). Leash → `return_home` (walk back, heal, go unaware).
- Shortcuts: damage or point-blank → aware immediately, no alert delay.
- Group alert: entering `alert` alerts unaware enemies within `alert_radius` with line of
  sight to it, after a staggered 0.15–0.4 s delay. Does not chain.
- Statuses and `ai_speed()` keep working while unaware (chill slows suspicion too).
- Tests `tests/unit/test_awareness.gd`, expectations from exports: out of range stays
  rest; in cone notices after ~`notice_time`; behind a `Block` never notices; behind it
  (out of cone) not by sight but a noise sends it to investigate; hit → aware at once;
  group alert reaches a neighbour in radius only, no chaining; leash → `return_home` →
  unaware; wave-spawned enemies start aware; `rest → suspicious → alert → idle → ...`
  sequence. Existing tests must still pass unchanged.

## Task 2: Readability, AI debug view, idle flavour

- In-world markers (primitives): "?" that fills while suspicious, "!" during `alert`.
  These are wind-up cues, so they must look unlike live attacks.
- **AI debug view** (`DebugSettings.show_ai`, F4 + pause-menu toggle):
  - Label above each enemy: state, state time, aware flag, suspicion value with a bar.
  - Sight cone (wireframe), hearing ring, alert radius ring, leash ring around home,
    home marker, patrol points.
  - Line-of-sight ray to the target: green when clear, red when blocked.
  - Suspicion visibly filling and draining (bar + cone tint).
  - Noise pulses drawn as expanding rings at the emit point with their radius.
  - Group alert links drawn briefly between alerter and alerted.
- `_idle_flavour(delta)` virtual, no hitboxes live: bull grazes (head dip), rat scurries in
  bursts, toad puffs, gull circles home, falcon perches and turns its head.
- Screenshot step `_capture_awareness()`: resting / suspicious / alerting enemies with the
  AI debug view on.

## Task 3: Level infrastructure (done)

- Split the runtime setup in `Arena` (player, HUD, pause menu, lighting) into a reusable
  `LevelRoot`; `main.tscn` keeps working, `WaveManager` becomes optional.
- `Checkpoint` (Area3D + visible post): touching sets `Player.spawn_point`, lights up.
- Enemy reset on player respawn: the level records each placed enemy's scene and
  transform/exports; on `Player.respawned` it frees and respawns them all (dead ones come
  back, living ones reset unaware at home).
- `GadgetGate`: `Block` subclass with `requires: StringName` and a per-gadget colour
  (grapple = brass ring, glide = vent, burrow = soil, conduit = copper terminal).
- `Gadgets` on the player: `has_gadget(id)`, `unlock(id)`; pause-menu debug "unlock all".
- Level select: `run.cmd -- --level=slice_01` and a pause-menu entry.
- `GravityRift` zone (Area3D): inside it gravity points along the zone's local down.
  Prototype only if cheap; otherwise leave a stub and note it.

Done notes / deviations:
- `LevelRoot` (`scripts/world/level_root.gd`) is the root script of every playable scene;
  `Arena` is an empty subclass kept for its name. `PlayerSpawn` and `WaveManager` are optional.
- Placed enemies are snapshotted in `LevelRoot._enter_tree` (scene path, local transform,
  parent, name, every stored script export, patrol `Marker3D`s) and rebuilt only when the
  player respawns **after a death**; the kill-plane respawn (falling off) resets nothing.
- `Player.spawn_yaw` added: checkpoints set it from their own yaw; `respawn()` restores
  facing and camera yaw.
- Enemies treat a dead player as no target (`_resolve_target` returns null), so nobody
  attacks the corpse during the 1.5 s respawn delay.
- Gadgets are a `Gadgets` RefCounted on `player.gadgets` (`has`, `unlock`, `unlock_all`,
  signal `unlocked_gadget`) with `Player.has_gadget` / `unlock_gadget` shortcuts.
- `GadgetGate` gets a coloured block, a marker primitive (ring / vent slats + plume / soil
  mound / copper terminal) and a "<id> gate" label; `is_open_for(player)` for tasks 5-8.
- Level select: `run.cmd -- --level=slice_01` (`--level=arena` = `main.tscn`). Pause menu:
  "Level: X" cycles through the arena + `scenes/levels/*.tscn`; the restart button then reads
  "Load X". `scenes/levels/slice_01.tscn` is a placeholder (floor, cover, spawn, checkpoint,
  one patrolling rat, one gate per gadget) for task 4 to replace.
- **GravityRift is a stub** (`scripts/world/gravity_rift.gd`: volume, visual,
  `gravity_direction()`, no effect). Not cheap: player movement, floor checks, jumping and the
  camera all assume world-up (`velocity.y`, `is_on_floor`, CameraRig pitch). Real support means
  moving the player onto an `up_direction` basis; schedule it as its own task if wanted.

## Task 4: Greybox slice `scenes/levels/slice_01.tscn`

Scale from `PlayerTuning` (run 8.5 m/s, gravity 30, jump 2.2 m, double jump 1.6 m).
Verify the jump limits with a small test course (a test that runs real jumps) before
blocking out.

| Measure | Calculated limit | Use |
|---|---|---|
| Single-jump ledge | 2.2 m | 1.5 m steps, never above 1.8 m |
| Double-jump ledge | 3.8 m | 3.0 m skill ledges |
| Single-jump gap | ~6.5 m | 3–4 m |
| Double-jump gap | ~10 m | 6–8 m; over 10 m = gadget gate |
| Gadget-gated ledge | over 4 m | 6 m+ |
| Corridor | — | 4–6 m wide |
| Combat pocket | — | 15–25 m, two cover pieces, exit visible |
| Sight line to next pocket | — | 25–35 m |

Beats: (1) landing pad + safe zone with a view of resting enemies; (2) pocket A,
stumble-in: wandering rats + resting bull; (3) traversal run, with a visible side ledge =
grapple gate; (4) hazard yard (fire trap, sweeper, steam hammer, pressure plate), patrols
walking through it; (5) pocket B, vertical: toads on platforms, gulls overhead; (6) locked
shortcut back to the pad (conduit or burrow gate); (7) falcon ridge + finale with every type,
a glide gate leading on. Checkpoints after beats 2, 4 and 5. Screenshot step
`_capture_slice_overview()`.

## Tasks 5–8: Starter gadgets

Each: gadget script under `scripts/gadgets/`, gate objects, tuning as data
(`data/gadgets/*.tres` or `PlayerTuning` group), tests, screenshot step, and at least one gate
in the slice.

5. **Brass Grapple-Tail.** Press jump in the air while a brass ring in range is
   highlighted (reticle/marker) → reeled to it, then a release jump. Combat crossover: staff
   (X) on a light enemy at grapple range yanks it to you (later, if cheap).
6. **Leaf-wing Cloak.** Hold jump while falling after the double jump → glide (capped fall
   speed, steerable). Steam vents give updrafts.
7. **Burrow Claws.** Dodge onto a soil patch → burrow; move underground (unseen by the
   awareness system); dodge again or reach the linked patch → pop out. Popping out behind
   an unaware enemy = sneak attack bonus on the next staff hit.
8. **Copper Conduit Gauntlet.** Staff-hit a lightning barrier to absorb a charge (gauntlet
   glows); staff-hit a dead copper terminal to power a door/lift. Later: discharge as a
   chain-lightning burst.

## Bench (good later additions)

- **Fox Nose**: once collectables exist; sniff to show scent trails to them and hidden switches.
- **Ink Bomb**: if stealth becomes a pillar; drains suspicion, breaks sight.
- **Steam Boots**: if we gate the double jump or add a high charge-jump (merges with Spring Coil).
- **Echo Bell**: nearly free once `Noise` exists.
- **Gravity rifts**: level feature replacing magnet boots (see decisions).

Full brainstorm: [gadgets.md](gadgets.md).
