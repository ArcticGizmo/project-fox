# Art pipeline: layout, theming and what to generate

Status: agreed 2026-11-01. Reference for building levels and dressing them, and for what
assets to generate. Ember (`assets/characters/ember/`) is the source of truth for
style and materials.

## Principle: layout and art are separate layers

What makes a level play well (jump distances, sightlines, enemy homes, gadget gates) lives
in greybox `Block`s, checked by `LevelMetrics` and `test_slice` (every critical-path jump is
made with real input). Art goes **over** that, never instead of it:

| Layer | What | Collides | Tested |
|---|---|---|---|
| Gameplay | `Block`s, `GadgetGate`s, hazards, checkpoints, enemies | yes | yes: metrics, jumps, gates |
| Surface | Each Block's `surface` role, drawn with the level's `LevelTheme` | (same Block) | material assigned, gates keep their colours |
| Dressing | `Prop`s (model or stand-in shape, optional single box) under `Level/Dressing` | rarely, simple shapes only | must not intrude on the critical path |
| Backdrop | Sky panorama, distant silhouettes, fog | no | no |

Consequences:
- Retheming a level never moves a jump. Swapping a texture never needs a retest of layout.
- A level can be stripped back to greybox (theme off, dressing hidden) to debug play.
- Dressing that blocks the player is a bug: keep collision off unless the prop is meant to
  be cover, and then use one simple box.

## Building a level

1. **Beat chart.** The sequence of moments: arrival view, first fight, gadget gate seen
   before it can be used, a breather, a reveal, the climax arena, the exit. One line each,
   with what the player learns or feels.
2. **Bubble diagram.** Spaces as bubbles, connections as lines; mark the critical path,
   optional pockets, one-way drops and shortcuts that loop back.
3. **Greybox** with `Block`s to `LevelMetrics` (single/double jump ledges and gaps; gated
   spots exceed `GATE_LEDGE_MIN` / `GATE_GAP_MIN`). Mark critical-path Blocks
   (`critical_path` group + `path_index`) so `test_slice`-style tests walk it.
4. **Play it** (and the AI debug view, F4): fights sized for each enemy's pattern (the bull
   needs a charge lane, the toad wants cover to lob over, flyers need sky), patrols and
   leashes kept in open ground.
5. **Surface roles**, then **dressing**, then **landmarks**: one or two big silhouettes per
   level visible from most places, so the player always knows where "there" is.

Readability rules that outrank looks:
- Gameplay objects keep their colour language (grapple ring gold, glide vent pale green,
  soil patch brown, conduit copper, hazards' warning colours). Themes never recolour them.
- Walkable tops read lighter and calmer than walls; walls carry the busier patterns.
- Enemies and Ember must pop: environment saturation sits below the characters', and red
  (Ember's cloak) is used sparingly in environments.

## Style guide (from Ember)

Ember is stylised and hand-painted: large flat colour shapes, soft painted shading baked into
the albedo, almost no fine noise, chunky proportions, slightly glossy leather and cloth.
Environment art should match:

- **Shapes**: chunky and slightly irregular. Big bricks, wide planks, fat rivets, soft bevels.
  No photographic detail, no pores, no high-frequency grit.
- **Shading**: painted top-light and soft dark crevices in the albedo itself (like Ember's
  fur and leather), plus a gentle normal map for the bevels. Roughness mostly high and flat.
- **Palette** (measured from Ember's texture): leather browns `#48261a` `#2b1006`, deep reds
  `#860006` `#b81d26` `#d32b32`, cream `#e8d6ca`, fur orange `#de8643`, teal accent
  `#2a8c96`, brass from her buckles. Environments use the browns, creams, brass and teal
  freely, desaturated a step; strong red is for characters and gameplay accents.
- **Setting**: magical steampunk with animal and fantasy creatures: warm stone and brick
  towns, timber, brass and copper machinery, moss and turf, steam.

**Prompt prefix** for every generated asset (keep it identical so assets match):

> Stylised hand-painted game asset, chunky soft shapes, painted lighting baked into the
> texture, warm earthy palette of leather brown, cream, brass and muted teal, magical
> steampunk storybook style, matching a cute red-hooded fox adventurer character.

For seamless textures add: *"seamless tileable texture, top-down orthographic, even
lighting, no perspective, no cast shadows"*.

## Texture sets (surface roles)

Each role is a `SurfaceStyle` (top texture + side texture, tile size, tint). A `LevelTheme`
maps roles to styles. Textures are world-mapped (triplanar), so any Block size tiles cleanly
with no UVs.

| Role | Top | Sides | Notes |
|---|---|---|---|
| `GROUND` | turf | dirt | grass lip spills over the top edge of the sides |
| `PATH` | cobble | stone wall | streets, plazas |
| `PLATFORM` | planks | stone wall | ledges and jump platforms |
| `WALL` | stone wall | stone wall | boundaries, buildings |
| `METAL` | brass plate | brass plate | machinery, industrial ledges |
| `GREYBOX` | flat `color` | flat `color` | default; untouched Blocks look as before |

Generated textures live in `assets/textures/<name>/` as `albedo.png` + `normal.png`
(OpenGL-style normal, green up), 1024² preferred, each tile covering `tile_size` metres
(2 m default). `tools/gen_textures.gd` writes procedural placeholders in the same layout, so
a generated set replaces one by dropping files in.

## Asset shopping list (in order of payoff)

1. **Seamless textures** for the first setting (6–8): cobble/flagstone, stone brick wall,
   wood planks, brass or copper plate, riveted iron, turf, dirt, roof tiles.
2. **Gameplay objects** (keep their colours): grapple ring, steam vent, soil patch, conduit
   terminal and socket, lightning barrier posts, checkpoint, the four gadget gates, and the
   hazards (fire trap, clockwork sweeper, steam hammer, lava edge).
3. **Prop pack** for the setting (15–25): crates, barrels, lanterns, pipes and valves, gears,
   signposts, fences, planters, mushrooms, rubble, banners (teal, not red).
4. **Held items**: the staff and one gun per weapon (8 on page 1). About 0.4 m long, grip at
   the origin, barrel along -Z. They mount on `FoxModel.gun_mount`.
5. **Enemies**: brass bull, clockwork rat, spitter toad, bombardier gull, brass falcon. Not
   humanoid, so auto-rigging likely won't apply: static meshes work (enemies animate by
   squash/pitch/yaw in code); separate parts (body, head, legs, wings) are better.
6. **Sky panorama** per setting.

## Model conventions

- Meshy imports land in `imported_models/<name>/`. Move each into `assets/<category>/<name>/`
  with the editor's FileSystem dock (drag; it fixes references), or move the `.glb` alone and
  let Godot reimport. `test_props` then checks every model under `assets/` (origin at the
  base, centred, plausible size in metres).
- Folder: `assets/<category>/<name>/` (`characters`, `props`, `weapons`, `enemies`,
  `gameplay`, `textures`). Keep the Meshy export name inside the folder if useful.
- Metres, Y up, origin at the base (feet / bottom centre), facing -Z (characters may face
  +Z like Ember; the wrapper turns them).
- One material per asset where possible; embedded texture extracted next to the GLB.
- Collision is never the render mesh: gameplay keeps its Block/area shapes, props get one
  box or capsule if any.
