# Project Fox

Third-person action-shooter prototype (Godot 4.7, typed GDScript). Magical-steampunk
animal/fantasy creatures. Priorities: game feel, weapon variety, enemy attack-pattern
variety, weapon levelling. Art is coloured primitives until real assets exist.

## Commands

```powershell
.\tools\test.ps1                 # full headless suite (~1s); fails on test failure OR engine error
.\tools\test.ps1 -Filter bull    # tests whose file/method name contains "bull"
godot --path . res://tools/screenshot.tscn -- --wait=4   # renders game, writes screenshots/*.png
godot --path . res://tools/screenshot.tscn -- --wait=4 --weapons   # also one shot per weapon firing
.\run.cmd / .\edit.cmd           # play / open editor (extra args pass through)
```

Run the test suite after every change. Use the screenshot tool to check anything visual
(it captures gameplay, scope, firing, weapon wheel, pause menu, hitboxes, a staff swing
and an overview).

## Controls (controller / keyboard+mouse)

Move L-stick/WASD · camera R-stick/mouse · fire RT/LMB · strafe LT/RMB (scope on the rifle) ·
jump A/Space · dodge B/Shift · staff X/F (air: slam; pounce is off by default) · weapon wheel hold
Y/Tab · cycle LB/RB, Q/E, 1-8 · pause Start/Esc/P · hitboxes Back/F1 · level weapon
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

## Testing gotchas

- Tests run with `--fixed-fps 60`: one awaited physics frame = 1/60 s, deterministic.
- `TestCase` instances are the 3D world root for each test; use `add_floor`,
  `add_dummy_target`, `spawn_enemy(path, pos, yaw, seed)`.
- `PROCESS_MODE_DISABLED` removes a CollisionObject from physics. To freeze an
  enemy in a test use `set_physics_process(false)`.
- Area overlaps need a physics frame after spawning before they register.
- Free any Node you instantiate outside the tree, or the leak check fails the run.
- New `class_name` scripts are not always registered by `--import`; test.ps1 verifies the
  class cache and falls back to headless editor scans run for 120 frames (`--quit` exits
  before the background scan finishes). If it still reports a class as unregistered, look
  for a parse error in that script (or a script it depends on).
- Status timers accumulate floats: a 0.5s tick can land one frame late, so give tick-count
  assertions a little slack. Tests that kill small enemies with captured lambdas will hit
  freed objects; use the bull (160 hp) as a damage sponge.
- `--check-only --script` reports bogus "Identifier not found: GameFeel" errors because
  autoloads are not loaded in that mode; ignore those.
- Scene reload can't be tested from the runner (it would reload the runner); arena
  restart was verified with a throwaway `-s` SceneTree script instead.
