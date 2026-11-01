# Gadget brainstorm

Candidate gadgets with the gate each opens and how it crosses into combat or awareness.
Cost is relative to this codebase: S = about a day, M = new movement or system, L = touches
camera, collision or scale. Decisions and the current plan: [plan-awareness-slice-gadgets.md](plan-awareness-slice-gadgets.md).

**Starter set:** Brass Grapple-Tail, Leaf-wing Cloak, Burrow Claws, Copper Conduit Gauntlet.
**Bench:** Fox Nose (with collectables), Ink Bomb (if stealth), Steam Boots (if double jump is gated or a charge jump is added), Echo Bell.
**Dropped:** Magnet Soles and Grind Clamps (too close to R&C). Replaced by gravity-rift zones.

| Gadget | Kind | What it does | Gate it opens | Combat / awareness crossover | Cost | Status |
|---|---|---|---|---|---|---|
| Brass Grapple-Tail | Traversal | Jump at a highlighted brass ring in the air and get reeled to it | High ledges, gaps with a ring | Yank light enemies to you, rip shields (later) | M | Built (task 5) |
| Leaf-wing Cloak | Traversal | Hold jump to glide; steam vents give updrafts | Gaps over 10 m, vent shafts | Slow descent for aerial shooting (fire while gliding, no strafe) | S | Built (task 6) |
| Burrow Claws | Traversal / stealth | Dodge onto soil to dig in, tunnel to a linked patch | Soil patches by walls and fences | Unseen underground (enemies lose track); pop up behind for a sneak attack (×2.5 staff hit) | M | Built (task 7) |
| Copper Conduit Gauntlet | Interaction | Absorb charge from lightning barriers, discharge into terminals | Unpowered doors and lifts | Stored charge as chain lightning | M | Starter |
| Fox Nose | Sense | Sniff: scent trails, hidden switches, enemies through walls | Hidden doors, secrets | Scout sleepers before a pocket | S | Bench (collectables) |
| Ink Bomb | Stealth | Smoke burst that drains suspicion and breaks sight | — | Escape a fight, reset a pocket | S | Bench (stealth) |
| Steam Boots | Traversal | Short wall-run on copper walls; or the double jump / charge jump as an unlock | Copper walls, tall ledges | Wall-run past a charging bull | M | Bench |
| Echo Bell | Sense / stealth | Noise pulse: shatters crystal, lures enemies | Crystal barriers | Uses `Noise`: pull enemies into hazards | S | Bench |
| Swing Hook | Traversal | Swing from hook anchors, keep momentum | Long gaps over lava or pits | Aerial fire while swinging | M | |
| Air-dash Gear | Traversal | One mid-air dash, refreshed by landing or staff hits | Gaps just past double-jump reach | Air combos | S | |
| Spring Coil | Traversal | Hold to charge a super-jump | Tall shafts, 6 m+ ledges | Charged slam from height | S | Merges with Steam Boots |
| Rope Crossbow | Traversal / build | Rope between two posts makes a zipline | Paired posts across a gap | Zip over a pocket and drop in | M | |
| Shrink Charm | Traversal / stealth | Shrink to fit vents and mouse holes | Small holes, vents | Tiny = hard to see | L | |
| Bellows | Interaction | Blow/suck air: windmills, fires, fog | Windmill doors, fire walls, fog | Blow light enemies off ledges | M | |
| Frost Lens | Interaction | Freeze lava/water into a temporary crust | Lava crossings | Overlaps chill | S | |
| Wind-up Key | Interaction | Wind clockwork lifts, bridges, gates | Clockwork mechanisms | Speed up or reverse sweepers/hammers | S | |
| Stopwatch Charm | Interaction | Pause moving hazards nearby | Hazard timing puzzles | Overlaps chill | S | |
| Lift Balloon | Interaction | Float crates or enemies | Stack crates into stairs | Float an enemy, pop to drop it | M | |
| Phase Lantern | Sense | Light reveals and solidifies ghost platforms | Invisible bridges | Reveals cloaked enemies | M | |
| Owl Scout | Sense | Remote flyer scouts, marks enemies, hits far switches | Switches behind bars | Mark sleepers, distract | L | |
| Long Pounce | Traversal | Unlock the existing pounce (off by default) | Medium gaps | Pounce into combat | S | |
| Diving Bell | Traversal | Move underwater | Water (none built) | Underwater combat | L | |
| Magnet Soles | Traversal | Walk on magnetic walls/ceilings | — | — | L | Dropped (use gravity rifts) |
| Grind Clamps | Traversal | Ride rails | — | — | M | Dropped (rails maybe as level feature) |

## What each pick is checked against

- Its gate reads at a glance: one colour or shape per gadget.
- It changes how you move, not only where.
- It crosses into combat or awareness.
- No overlaps (glide / air-dash / spring all solve "gap too big").
- Cheap to greybox first; L costs wait until the slice proves the loop.
