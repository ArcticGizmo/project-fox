# Project Fox

Third-person action-shooter prototype (Godot 4.7, typed GDScript). Magical-steampunk
animal/fantasy creatures. Priorities: game feel, weapon variety, enemy attack-pattern
variety, weapon levelling. Art is coloured primitives until real assets exist.

## Commands

```powershell
.\tools\test.ps1                 # full headless suite (~1s); fails on test failure OR engine error
.\tools\test.ps1 -Filter bull    # tests whose file/method name contains "bull"
godot --path . res://tools/screenshot.tscn -- --wait=4   # renders game, writes screenshots/*.png
godot --path .                   # play
```

Run the test suite after every change. Use the screenshot tool to check anything visual.

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
  weapons, `_on_level_changed()` to rebuild shapes. Kills credit XP to the weapon.

## Testing gotchas

- Tests run with `--fixed-fps 60`: one awaited physics frame = 1/60 s, deterministic.
- `TestCase` instances are the 3D world root for each test; use `add_floor`,
  `add_dummy_target`, `spawn_enemy(path, pos, yaw, seed)`.
- `PROCESS_MODE_DISABLED` removes a CollisionObject from physics. To freeze an
  enemy in a test use `set_physics_process(false)`.
- Area overlaps need a physics frame after spawning before they register.
- Free any Node you instantiate outside the tree, or the leak check fails the run.
