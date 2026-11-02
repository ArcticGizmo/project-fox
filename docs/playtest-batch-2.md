# Playtest batch 2

One sitting, controller in hand. Everything here was only measured headless or
judged from screenshots. Notes in any form are fine: a word per line ("too
slow", "love it", "confusing") is plenty. Numbers to tune are in brackets with
where they live.

**Shortcuts (pause menu → Debug...):** max all weapons, current weapon +1 level,
spawn any enemy in front of you, boss to phase 2 / 3, invulnerable, rumble and
sound sliders. "Unlock All Gadgets" is on the main page. Hitboxes Back/F1, AI view F4.

**Route:** 1-4 and 13 in the arena (`run.cmd`), 5-6, 11 and 14 in `slice_01`, 7-9 and 14 in `slice_02`,
10 in `boss_furnace_stag`, 15 anywhere.

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

## 11. Glimmer, Magpie Peddler and saving (slice_01)

A new save owns three weapons (Repeater, Hornet Swarm, Mortar); the rest are bought. Debug page:
"+1000 Glimmer", "Own All Weapons", "Reset Save" (asks twice). The arena never saves.

- [ ] Glimmer motes popping out and flying to you: satisfying? Magnet radius (5 m, `glimmer_magnet_radius`) and speed?
- [ ] Pickup chime with lots of motes at once: pleasant or grating? The HUD counter rolling up: readable?
- [ ] Economy: enemies drop 3 glimmer per XP point (`Enemy.GLIMMER_PER_XP`), crates 8, jars 60. Prices 600-1800 (`WeaponData.price`). How many weapons could you afford after one run? Too slow, too fast?
- [ ] Magpie stall on the pad: did you notice it? "Strike the bell" (staff) to trade: natural, or do you want a button?
- [ ] Shop menu on a controller: navigation, focus, reading descriptions, buying. Is "Refill all ammo" worth having?
- [ ] Locked wheel slots (empty sockets with the price): motivating or clutter?
- [ ] Jars (one on the pocket A pillar you have to shoot, others off the path) and the two Heartsprings (grapple ledge, beyond the glide gap): fun to look for? Want a map/counter beyond the pause menu tally?
- [ ] Quit and relaunch, then load slice_01: back at your last checkpoint with your glimmer, weapons and finds?

## 13. Held weapon models (arena; Debug → Own All Weapons)

- [ ] Each of the 8 modelled guns: right size in her hand? Grip looks held, not floating? (`WeaponData.model_grip`, `model_length`)
- [ ] Shots, flame and the horn blast start at the barrel tip now: noticeable improvement? Any that look off?
- [ ] Recoil kick (8 cm back, 14° up at full kick, `PlayerTuning.recoil_*`; per weapon from its strongest `fire_rumble` motor): punchy, too much on the rapid-fire Repeater, too little on the Ram?
- [ ] The Rhino Beetle Ram (Runic Gear Cannon) is held near its muzzle like a shoulder cannon: fine, or swap the grip?
- [ ] Weapons still on a box (Owl Lens Rifle, Kraken Lash, Tortoise Sentry, Frost Narwhal, Silk, Moth Lantern, Bulwark, Swallow): jarring next to the models?

## 14. New enemies (placed in the slices; arena waves 9-10; or Debug → Spawn)

Placed: Coal Beetle in `slice_01`'s hazard yard (SE corner), Raccoon Rogue in the `slice_01` finale
(NW corner), Ironhorn Sentinel on `slice_02`'s cliff terrace, three Clockwork Honeybees over island B.

- [ ] **Coal Beetle** (110 hp): ember trail (4 dmg ticks every 0.5 s, 5 s) noticeable and worth avoiding? Belch (3 coals, 14 dmg, 0.9 s stoke) readable from the landing marks? Scorch up close (16 dmg) fair? Did you discover frost quenching it (steam, purple exposed glow)? Fire doing nothing: clear, or confusing?
- [ ] **Raccoon Rogue** (45 hp): did it steal from you? Steal size (40, `steal_amount`) and escape (5 s and 14 m away): exciting chase or just annoying? Hits knocking glimmer loose (10 a hit): satisfying? In a walled space it can't get away: fine?
- [ ] **Clockwork Honeybee** (18 hp): low hover (2.4 m) easy to hit with the staff and guns? One-at-a-time stings: do you read the rhythm? Dart (16 m/s, 0.55 s wind-up) dodgeable? Do they meet you well as you land from the glide?
- [ ] **Ironhorn Sentinel** (220 hp): jab → hook → slam readable? Can you dodge each blow and jump the ring? Winded opening (1.6 s) long enough to punish? The slam on the cliff terrace knocking you off the edge: fun or cheap?
- [ ] Rigged enemies (rogue, Sentinel) use the fox's animations: do they look right, or obviously borrowed?
- [ ] Telegraph glows on textured models: still clear (the whole model lights yellow)?

## 15. Anything else

- [ ] Anything that felt bad, confusing or broken that isn't above.
- [ ] Your favourite and least favourite new thing.
