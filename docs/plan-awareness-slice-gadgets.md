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

## Task 4: Greybox slice `scenes/levels/slice_01.tscn` (done)

Scale from `PlayerTuning` (run 8.5 m/s, gravity 30, jump 2.2 m, double jump 1.6 m), verified
by `tests/unit/test_jump_metrics.gd`: ~65 Player lanes side by side, standing jumps against a
wall for ledges and full-speed running jumps (pressed as the fox's centre passes the edge) for
gaps, double jump at the apex or after falling 1.9 m. Design limits are `LevelMetrics`; the
test fails if a path limit stops being reachable or a gate minimum becomes reachable.

| Measure | Calculated | Measured | Use (`LevelMetrics`) |
|---|---|---|---|
| Single-jump ledge | 2.2 m | 2.2 m | 1.5 m steps (`STEP_MAX`) |
| Double-jump ledge | 3.8 m | 3.7 m | 3.0 m ledges (`LEDGE_MAX`); walls that must stop you 4.5 m |
| Single-jump gap | ~6.5 m | 6.0 m | 3.5–4 m (`SINGLE_GAP_MAX` 4) |
| Double-jump gap | ~10 m | 9.5 m at the apex, 11.0 m with a late double jump | 6–7.5 m (`GAP_MAX` 7.5) |
| Gadget-gated ledge | over 4 m | — | ≥ 5.5 m above any path block in reach (`GATE_LEDGE_MIN`); slice uses 6.5 m |
| Gadget-gated gap | over 10 m | — | ≥ 13 m (`GATE_GAP_MIN`); slice uses 19 m |
| Corridor | — | — | 4–6 m wide |
| Combat pocket | — | — | 15–25 m, two cover pieces, exit visible |
| Sight line to next pocket | — | — | 25–35 m |

Layout (x east, -z north; the route loops pad → north → east → south → west → south):

1. **Landing pad** (x -6..6, z -6..6, raised 3 m, low rails). Spawn faces north over a stepped
   forecourt and a 1.2 m fence into pocket A (spawn → pocket centre ~31 m). Ammo + health
   crates. Nothing can see the pad (test).
2. **Pocket A** (22 x 22, x -11..11, z -18..-40, 4.5 m walls, fence on the pad side): three
   wandering rats (radius 3, homes ≥ 20 m from the pad edge) and a bull resting with its back
   to you; two cover pieces + a pillar. Exit east (5 m opening). **Checkpoint 1** just outside.
3. **Traversal** east then south over the void, 5 m wide: 3.5 m gap, 1.5 m step, 4 m gap,
   corner, 7 m double-jump gap, 3 m ledge up to an overlook above the yard. Side ledge
   `Level/Traversal/GrappleLedge` (grapple gate, top 6.5 m above the run, ammo crate on it).
4. **Hazard yard** (22 x 22, x 36..58, z -10..12). Drop in at the NW corner; a 2.5 m divider
   forces north lane → NE turn → south lane → west door. North lane: four fire plates across it
   (1.5 m slip gap by the divider) with two rats patrolling over them (the plates erupt behind
   them; hazards don't wake enemies). NE turn: clockwork sweeper. South lane: steam hammer
   rail. Door corridor (x 30..36): lightning barrier across its mouth, **Checkpoint 2**,
   health crate. Burrow patches `Level/Yard/BurrowIn` / `BurrowOut` either side of the divider
   skip the yard.
5. **Pocket B** (22 x 22, x 8..30, z -4..18), vertical: two toads on 3 m parapeted platforms
   (NE and SW, each with a 1.5 m step; `move_speed = 0` turret toads so they can't walk off),
   two gulls overhead, two cover pieces, ammo crate on the SW platform. West wall 8 m (blocks
   sight to the pad). Exit south: **Checkpoint 3**.
6. **Shortcut**: `Level/Shortcut/ShortcutDoor` (conduit gate, copper, full wall height) in
   pocket B's west wall, opening onto a 1.5 m step up to the pad. Visible from the pad.
7. **Falcon ridge + finale**: 1.5 m step, 3 m ledge, 6 m double-jump gap to a 4 m-wide spine
   with two falcons over it, 1.5 m step up to the finale plateau (24 x 24 at +6 m, 1 m rails,
   two cover pieces, a 1.5 m dais). Finale has every type: bull, two rats, toad (on the dais),
   gull, falcon; two health crates and an ammo crate. `Level/Finale/GlideVent` (glide gate) at
   the far edge faces `BeyondPlatform` 19 m away and 4 m lower (the next area, with a beacon).

Gates for tasks 5–8:
- **Grapple** (`GrappleLedge`): reel to the brass ring on top of the pillar from the run below
  (T2/T3, 4 m south of it), land on top for the crate.
- **Glide** (`GlideVent`): from the finale's far edge glide 19 m to `BeyondPlatform`; the vent
  is the updraft spot.
- **Burrow** (`BurrowIn` → `BurrowOut`): dodge onto the soil north of the divider, pop out
  south of it, past the plates, sweeper and hammer (still before the lightning door).
- **Conduit** (`ShortcutDoor`): the door itself is the gate. Task 8 should add a dead copper
  terminal beside it on the pocket B side (charge from the yard's lightning barrier) and make
  the door open.

Done notes / deviations:
- Critical-path Blocks are in group `critical_path` with a `path_index` meta (walking order).
  `tests/unit/test_slice.gd` checks every step against `LevelMetrics`, makes each jump for
  real with the level's player and scripted input, checks gates really need their gadget,
  beat contents (enemy types per `Enemies/<beat>` group, a gate per gadget, 3 checkpoints),
  and that 20 s idling on the pad wakes nobody while every placed enemy stays home and alive.
- Pits: the player's existing kill plane (y -20) respawns at the last checkpoint, and every pit
  sits right after one, so no extra respawn volumes. Enemies now die below
  `Enemy.KILL_PLANE_Y` (-20). A dark `AbyssFloor` at -30 is only there so pits read as deep.
- Placed-enemy reset on respawn also frees enemy projectiles in flight (`LobProjectile.GROUP`).
- Patrol markers are local to the enemy and rotate with its yaw (the first yard routes went
  through the sweeper); patrollers use yaw 0.
- Standing still (no fighting back) in a pocket the player survives pocket A's fence and the
  yard for 30 s and dies in ~15–20 s in pocket A's centre or the finale, measured headless in
  the real level; with dodging, crates and checkpoints the fights should be survivable, but
  this wants a hands-on pass.
- Estimated length: ~250 m of route (~30 s running) plus five fights → roughly 5–8 minutes.
- Screenshots: `slice_pad_view`, `slice_traversal`, `slice_hazard_yard`, `slice_pocket_b`,
  `slice_shortcut_from_pad`, `slice_ridge`, `slice_finale`, `slice_overview` (orthographic,
  framed on the level's Blocks), `slice_overview_ai` (AI debug view on), `slice_overview_angle`.
  `-- --slice` renders only these.


## Task 5: Brass Grapple-Tail (done)

- `scripts/gadgets/`: `GrappleTail` (component on the player, like `StaffMelee`: picks and
  highlights the best ring, throws the tail, returns the reel velocity, draws the rope) and
  `GrappleRing` (@tool anchor; group `grapple_rings`; halo + pip highlight). The grapple
  `GadgetGate` builds a real `GrappleRing` (`gate.ring`) `RING_HEIGHT` (1.4 m) above its top.
- Controls: jump in the air while a ring is highlighted grapples. A ring beats the double
  jump (the release refunds it, so you can still double jump after). Ground → jump → jump is
  the natural way in; there is no grapple from the ground. Without `&"grapple"` nothing is
  highlighted and jump is unchanged.
- Targeting (`PlayerTuning` "Grapple" group): within `grapple_range` 15 m of the reel point
  (1 m above the feet), farther than `grapple_min_distance` 2 m, within `grapple_aim_cone_deg`
  60° (horizontal) of the camera's forward, not more than 1 m below the feet, with a clear
  ray against WORLD. The body the ring is mounted under is excluded from that ray, so a
  ring on a ledge top is visible from below the lip. Score = angle/cone + distance/range.
  Highlight: dim halo (`IN_REACH`) on the ground, bright pulsing halo + pip (`READY`) in the
  air and while reeling; the reticle gets a brass ring when jump would grapple.
- Reel: 0.08 s throw (fox hangs, rope extends), then 8 → 22 m/s at 90 m/s², easing to 7 m/s
  over the last 2.5 m; let go within 0.6 m with a 1 m hop (not cut by releasing jump) and
  1.5 m/s carry. Pulled into a wall (the ledge lip), the reel slides along it at full speed,
  so the fox climbs the face and goes over. For 0.5 s after the release (or until landing)
  air control is ×0.15 so holding forward settles on a 4 m ledge instead of overshooting.
  Gives up after 1.6 s (stuck).
- Cancels: dodge (lets go and dodges), a hit with knockback ≥ 6 (smaller hits are shrugged
  off: i-frames and flash, no knockback), death, respawn, lava launch. No firing or staff
  while reeling: the tail is the action, and it keeps the reel short and readable.
- Camera: vertical follow uses `grapple_camera_vertical_sharpness` (14, normally 6) while
  reeling, via `CameraRig.vertical_sharpness_override`. The fox faces the ring.
- Slice: `GrappleLedge` reachable with the grapple from T2Step (test, real input); its crate
  moved off-centre (32.3, 8, -43.3) so it doesn't sit under the ring. No extra rings: a ring
  on pocket A's pillar would let you perch out of the bull's reach and hop the 4.5 m walls
  into the void; mid-gap rings have no ledge to land on. Revisit with Task 6 (glide) where a
  ring + glide chain could make a real optional route.
- Tests: `tests/unit/test_grapple.gd` (highlight only when unlocked + in range + LOS + in
  the cone; jump grapples and lands on top; reel speed within tuning; double jump unchanged
  without a ring; dodge cancels; small hit doesn't, big hit does; no firing while reeling)
  and `test_slice.test_grapple_ledge_needs_and_takes_the_grapple` (jump + double jump from
  the run falls short; with the gadget, jump then jump lands on the ledge top).
- Screenshots: `grapple_ready`, `grapple_reel`, `grapple_reel_side` (`_capture_grapple`, run
  at the end of `_capture_slice`).
- Not done (future): staff yank of light enemies at grapple range. Cheap-ish later: on staff
  press, if an enemy with low `knockback_resistance` is the aim target within `grapple_range`,
  draw the rope to it and `stagger()` + pull it toward the fox. Needs a "pulled" movement on
  `Enemy` (like knockback) and flyers handled; skipped to keep this task clean.
- Shared gadget structure for tasks 6–8: a `scripts/gadgets/<Gadget>` component node created
  in `Player._build_visual` with `player`/`tuning` set, asked each frame from
  `_physics_process` (`update_target(has_gadget(id))`-style), `is_active()` gates fire/melee
  and takes over velocity in `_move` early; anchors/objects are their own @tool nodes in a
  group, built by `GadgetGate._decorate` for gates. Tuning is a `PlayerTuning` group.

## Task 6: Leaf-wing Cloak (done)

- `scripts/gadgets/`: `LeafCloak` (component under the player's visual: open/close state,
  glide heading, `glide_velocity()`, two leaf wings that unfold over `glide_unfold_time`) and
  `SteamVent` (@tool updraft column; group `steam_vents`; `lift_at(pos)` 0..1, full up to
  `full_fraction` of `lift_height` then fading to 0 at the top; translucent cone plume +
  GPU puffs). The glide `GadgetGate` builds a real `SteamVent` (`gate.vent`,
  `VENT_LIFT_HEIGHT` 10 m) instead of the old decorative plume.
- Controls: with `&"glide"`, hold jump while falling once the double jump is spent → the cloak
  opens. In practice: jump, jump (double), keep holding. Releasing jump folds it. No new
  buttons. Logic in `Player._update_glide` (opens only with `_air_jumps_left == 0`).
- Feel (`PlayerTuning` "Glide"): fall eases to `glide_fall_speed` 2.5 m/s at 30 m/s²;
  forward `glide_speed` 9 m/s (run is 8.5) with the stick, drifting at `glide_idle_speed`
  0.5 m/s without it (so a vent can be ridden), accel 12 m/s²; the heading turns toward the
  camera-relative stick at `glide_turn_speed_deg` 150°/s (gentle: a U-turn is ~1.2 s). In a
  vent the vertical target becomes `lerp(-glide_fall_speed, glide_vent_rise_speed 7, lift)`,
  so a glider climbs to where the column fades and hovers there. A non-glider gets only
  `vent_push_acceleration` 3 m/s² (vs 30–48 gravity): a jump over a vent goes ~10% higher.
- Closes on: release, landing, dodge, grapple start, a hit with knockback ≥
  `glide_cancel_knockback` (1) or any knockback_up, `launch_up`, death and respawn. Forced
  closes (dodge, grapple, hit, launch) need jump released and held again (`_glide_needs_press`),
  so a held button never reopens it the frame the dodge ends.
- Weapons fire while gliding (the aerial-shooting crossover; the slow, steady descent is a
  stable firing platform). Strafe is off while gliding (`is_strafing()` false): strafe locks
  facing and ground speed and would fight the heading; firing still turns the fox to aim for
  `fire_facing_time`, the glide heading is unaffected.
- Grapple → glide: the release refunds the double jump, so holding jump through the release
  never opens the cloak. Press jump again (double jump), keep holding, and it opens as you
  fall. A highlighted ring still beats everything: jump while gliding grapples.
- Slice: GlideVent → BeyondPlatform (19 m, 4 m lower) unchanged geometry. Ride the vent up
  ~9 m (where its lift fades), push south, let go over the platform. Jump + double jump + run falls into the void.
  No optional ring + glide route: the only rise is the one vent, so gliding can't climb out
  of the level; a mid-gap ring still has nothing to land on, so not worth it yet.
- Tests: `tests/unit/test_glide.gd` (locked: no glide; no glide while the double jump
  remains; fall capped and settles at `glide_fall_speed`; release / landing / knockback close;
  dodge closes until a fresh press; camera-relative steering, glide speed and gentle turn;
  fire allowed, strafe off; vent lifts a glider to near the column top; vent barely boosts a
  jump; grapple release then double jump then glide) and
  `test_slice.test_glide_vent_needs_and_takes_the_glide` (real input from the vent).
- Screenshots: `glide_vent.png`, `glide_gap.png`, `glide_gap_side.png` (`_capture_glide`,
  after `_capture_grapple` in `_capture_slice`; it frees the level's enemies first).

## Task 7: Burrow Claws (done)

- `scripts/gadgets/`: `BurrowClaws` (component on the player: phases DIVE → UNDER ⇄ TUNNEL,
  underground velocity, patch confinement, the dirt mound) and `SoilPatch` (@tool flat soil disc;
  group `soil_patches`; `radius`, `contains()`, `confine()`, `SoilPatch.at()`; optional `exit`
  NodePath to a partner patch or burrow gate, resolved from either side by `partner()`). No
  collision: without the gadget a patch is ground decor. The burrow `GadgetGate` builds a real
  patch on its top (`gate.soil`, radius = half the smaller side) and links it with `link`.
- Controls (no new buttons): with `&"burrow"`, a **floor dodge on or onto a patch** digs in (the
  check runs every dodge frame on the floor, so dodging onto one from 2–3 m away works).
  Underground: stick moves the mound, **jump pops out**, **dodge tunnels** to a linked patch
  (arriving still underground, so you pick the moment to pop) or pops out of a standalone one.
  Decision: underground movement never leaves the patch (no free roaming); tunnels are authored
  links. Keeps level design controllable and stops burrowing past gates or enemies' pockets.
- Feel (`PlayerTuning` "Burrow"): dive 0.2 s (no control, fox sinks), underground speed 3.5 m/s
  (accel 30), tunnel 9 m/s with a 0.45 s minimum, pop-out hop 0.7 m (not cut by releasing jump,
  like the grapple hop; refunds the double jump), conceal 0.75 s after popping, sneak window
  1.5 s, sneak ×2.5.
- While burrowed: fox visual sinks then hides, a light fresh-earth mound with tumbling clods
  follows it (dips mid-tunnel); body `collision_layer` 0 / mask WORLD (enemies walk over it);
  hurtbox invulnerable (hazards on the surface, projectiles, everything); no fire, staff or
  grapple; the steam hammer ignores a burrowed fox (it tracks creatures). Death, respawn and
  `launch_up` drop out of the ground. Keep patches away from lava.
- Awareness: `Player.is_hidden()` (burrowed, or within the conceal time after popping out).
  `Enemy._resolve_target()` returns null for a hidden player and sets `target_hidden`, so sight
  and point-blank both fail and suspicion drains. Aware enemies with `forget_time > 0` **lose
  track** at once (`_lose_track`: hitboxes off, unaware, `investigate` at `last_seen_position`,
  suspicion `LOST_TRACK_SUSPICION` 0.5); always-aware ones (waves, tests) just have no target
  until the fox reappears. Deviation from "treat like lost sight": the existing lost-sight path
  keeps attacking the target's live position for `forget_time`, which a burrow must not allow.
- Sneak attack: the first staff **swing** hit within the window (`Player._sneak_modifier`, the
  staff HitBox's `damage_modifier`) does ×2.5 to an enemy that is not `aware` (shown as a
  crit); any enemy hit spends the window. Slams don't get it (they make noise). A staff press
  during the pop hop (or on the pop frame) waits for the landing and swings, so the ambush is
  jump + staff. The conceal time exists because point-blank (3 m) would otherwise notice the fox
  before the swing lands; a staff hit landing or firing ends it, so the victim doesn't lose
  track again. A sneak kill doesn't trigger the group alert (existing rule: a dead enemy never
  alerts); a survivor (bull 160 hp) alerts its neighbours as usual.
- Slice: `BurrowIn` links to `BurrowOut`: dodge, dodge, jump crosses under the divider past the
  fire plates, sweeper and hammer (lightning door still ahead). Optional ambush in pocket A:
  `Level/PocketA/AmbushSoil` (behind CoverA by the fence) tunnels to `AmbushSoilBull` right
  behind the resting bull; one swing from its north edge reaches the bull (35 damage). Critical
  path unchanged and completable without gadgets.
- Tests: `tests/unit/test_burrow.gd` (locked / off-soil dodge is a dodge; dodge on and onto
  soil; confined slow movement; hidden from a staring point-blank rat; suspicion drains; aware
  bull loses track and investigates; tunnel under a wall; pop-out hop, conceal and visibility;
  standalone dodge pops; no fire/staff; damage ignored; sneak ×2.5 on unaware; window expires;
  no bonus on aware; sneak kill doesn't wake a neighbour; death digs out; staff with the pop
  swings on landing) and `test_slice` (`BurrowIn → BurrowOut` with real input, needs the
  gadget; ambush patch sits behind the bull within one swing).
- Screenshots (`_capture_burrow`, between grapple and glide): `burrow_mound.png` (mound behind
  the bull, AI view on: everyone resting at 0 suspicion), `burrow_pop.png`, `burrow_sneak.png`
  (the "35!" crit).
- Wants a hands-on pass: whether 0.75 s conceal feels fair, whether pocket A's ambush is
  reachable before the rats notice you, and whether the mound should be visible to enemies
  (e.g. raise suspicion slowly when it moves in their cone) for more tension.

## Tasks 5–8: Starter gadgets

Each: gadget script under `scripts/gadgets/`, gate objects, tuning as data
(`data/gadgets/*.tres` or `PlayerTuning` group), tests, screenshot step, and at least one gate
in the slice.

5. **Brass Grapple-Tail** (done, see Task 5 above). Press jump in the air while a brass ring in range is
   highlighted (reticle/marker) → reeled to it, then a release jump. Combat crossover: staff
   (X) on a light enemy at grapple range yanks it to you (later, if cheap).
6. **Leaf-wing Cloak** (done, see Task 6 above). Hold jump while falling after the double jump → glide (capped fall
   speed, steerable). Steam vents give updrafts.
7. **Burrow Claws** (done, see Task 7 above). Dodge onto a soil patch → burrow; move underground (unseen by the
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
