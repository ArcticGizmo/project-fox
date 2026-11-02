# Playtest batch 2

One sitting, controller in hand. Everything here was only measured headless or
judged from screenshots. Notes in any form are fine: a word per line ("too
slow", "love it", "confusing") is plenty. Numbers to tune are in brackets with
where they live.

**Shortcuts (pause menu → Debug...):** max all weapons, current weapon +1 level,
spawn any enemy in front of you, boss to phase 2 / 3, invulnerable, rumble and
sound sliders. "Unlock All Gadgets" is on the main page. Hitboxes Back/F1, AI view F4.

**Route:** 1-4 in the arena (`run.cmd`), 5-6 in `slice_01`, 7-9 in `slice_02`,
10 in `boss_furnace_stag`, 11 anywhere.

---

## 1. Feel: rumble and sound (arena)

- [ ] Rumble strength overall. Use the Debug slider and note where it feels right (default 1.0).
- [ ] Fire each weapon on page 1 and 2: does each rumble suit its weapon? (`WeaponData.fire_rumble`)
- [ ] Hits, slams, wall impacts rumble via shake/hit-stop: too much during busy fights?
- [ ] Placeholder sounds: any that grate, or are too loud or too quiet? Which ones? (`SfxBank` recipes)
- [ ] Wind-up cue: every telegraph plays a rising whine. Helpful warning, or noisy with 6+ enemies?
- [ ] Shielded hits and pangolin armour "clank": do you understand why your shots did little?
- [ ] Level-up slow-mo blip (0.25 s at 0.3 speed): satisfying, or a stutter mid-fight? (`PlayerTuning.level_up_slowmo_*`)

## 2. Weapons and levelling (arena)

- [ ] Level-up popup: readable at a glance? Does the perk line tell you what changed?
- [ ] Max all weapons, then try each level-4 signature:
  - [ ] Rifle weak-spot crits stagger (bull boiler)
  - [ ] Lash tip hits expose (purple glow)
  - [ ] Salamander stokes over 2 s of holding (orange → blue-white): noticeable? worth holding?
  - [ ] Frost: kill a frozen enemy, does the shatter chill neighbours visibly?
  - [ ] Silk webs expose
  - [ ] Echo Horn reflects lobs and shards in its cone: timing window fair?
  - [ ] Repeater ricochets: noticeable, or lost in the noise?
- [ ] Clockwork Swallow: do the curves read? Do you trust it to go round armour? (darts are small)
- [ ] Rhino Beetle Ram: charge time (1 s, `charge_time`), the full-charge chime and reticle ring. Does upending feel strong?
- [ ] Dodging or swinging while charging drops the charge. Right call, or annoying?
- [ ] Wheel page 2 is now full (8). Any weapon you never reach for?

## 3. Brass Pangolin (arena, or Debug → Spawn: pangolin)

- [ ] Front armour (85% blocked, 120° cone): obvious from the clank and sparks, or confusing?
- [ ] Turn speed (100°/s): can you flank it on a stick?
- [ ] Shard volley (5 × 8 dmg): fair, too punishing up close?
- [ ] Roll: dodgeable? Does baiting it into walls feel clever? Dizzy window (2 s) long enough to punish?
- [ ] The flipped "legs up" pose reads as "now hit it"?
- [ ] Reflected shards (Bulwark/Echo Horn) bounce off its own front armour: feels wrong or fine?

## 4. Chime Heron (arena waves 6 and 8, or spawn it)

- [ ] Do you notice the shield bubbles and tethers in a real fight?
- [ ] Is it obvious the heron is the cause? Do you go for it first?
- [ ] 25% damage while shielded: too strong / too weak?
- [ ] It backs off to 10-16 m: annoying to chase, or a fair priority target?
- [ ] Peck when cornered: noticeable at all?

## 5. Awareness and stealth (slice_01; open since batch 1)

- [ ] "?" fill time: enough to back off or commit? Bull slow to notice, rat hearing, falcon's wide cone?
- [ ] Group alert (0.15-0.4 s): a pocket waking as one, or a fun cascade?
- [ ] Leash and return home: chases end at sensible spots?
- [ ] Idle flavour (grazing, scurrying, puffing): reads as "unaware" from mid-range?

## 6. slice_01 traversal and gadgets (open since batch 1)

- [ ] Survival in pocket A and the finale with dodging, crates and checkpoints. Pocket B crossfire fair?
- [ ] Length (estimate 5-8 min), sight lines, do the yard hazards read before you are in them? The 7 m double-jump gap on a real stick?
- [ ] Grapple: jump-then-dodge discoverable? Reel speed (22 m/s), release hop, camera during the reel?
- [ ] Glide: turn rate (150°/s), fall 2.5 m/s, holding jump through the double jump to open, vent top readable?
- [ ] Burrow: 0.75 s conceal after popping out fair? Floor dodge on soil ever triggers when you meant to dodge?
- [ ] Conduit: barrier reach from ~1.9 m, barrier off ~3 s too generous? Stray charge loss on an enemy annoying?
- [ ] Gadget HUD bar: do the lit slots help (grapple ring in reach, gliding, underground, conduit pip)?
- [ ] Context rules colliding (dodge on soil mid-fight, staff near a terminal mid-combat)?

## 7. slice_02: Choir courtyard

- [ ] Two pangolins + two rats + heron: how does the fight play? Do you use the low wall (bait rolls, cover)?
- [ ] Does the heron shield make you change target, or just slow the fight down?

## 8. slice_02: rifts and gadget chains

- [ ] Rift lift up the 12 m cliff: obvious what to do? Purple + chevrons readable? Bobbing at the top then stepping off: smooth or fiddly?
- [ ] Grapple to the pillar, then glide to island B: does the chain feel good? Is the ring easy to pick up from the terrace edge?
- [ ] Rift current over the 16 m gap: obvious you should step in? Speed (8 m/s), steering across it?
- [ ] Rifts in general: fun as a level feature? Want walls/ceilings (needs a big player rework) or is this enough?

## 9. slice_02: choke and door

- [ ] Two pangolins guarding a 4 m gap: is the burrow tunnel behind them discoverable? Does the sneak attack land?
- [ ] Charging at the lightning barrier and carrying it to the door terminal: clear what's needed?

## 10. Furnace Stag (end of slice_02, or the arena level)

- [ ] Overall difficulty (1200 hp). Time to kill? Deaths?
- [ ] Phase 1: guard (60% blocked from the front) pushes you to flank? Sweep readable? Stomp shockwave jumpable (0.7 m tall ring, 9 m/s)?
- [ ] Phase 2: furnace weak spot obvious? Barrage fair? Charge into pillars: do you bait it on purpose?
- [ ] Phase 3: lightning marks readable in time (0.9 s)? Too much at once?
- [ ] Roars between phases: dramatic beat or dead time?
- [ ] Beetle full charge during the rear-up topples it: did you discover it? Satisfying?
- [ ] Boss bar and phase names helpful?

## 11. Anything else

- [ ] Anything that felt bad, confusing or broken that isn't above.
- [ ] Your favourite and least favourite new thing.
