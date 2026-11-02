# Model inventory

Every imported model and what it is (or should be) bound to. Models still in
`imported_models/` are unused; move one into `assets/` when something uses it (see
`docs/art-pipeline.md`, "Model conventions", and CLAUDE.md, "Imported models").

Assessed 2026-11-02 from a contact sheet of each model (front, side, top, three-quarter).
All static exports are about 1 m across and centred; guns lie along X with the barrel at -X.

## Bound

| Model | Where | Bound to | Notes |
|---|---|---|---|
| Coal Beetle | `assets/enemies/coal_beetle/` | **new enemy** `CoalBeetle` | Static. Lava-cracked shell with chimneys: crawls leaving `CoalEmber` patches, stokes then belches coals that leave embers, scorches up close. Fire-proof, frost quenches it (exposed). Wave 9. |
| Racoon Rogue | `assets/enemies/raccoon_rogue/` | **new enemy** `RaccoonRogue` | Rigged (64 bones, SmartRig). Drives `FoxModel`'s baked clips. Glimmer thief: darts in, swipes, steals and flees; hits shed loot, a kill spills it, otherwise it escapes. Wave 9. |
| Dragon Bellows | `assets/weapons/dragon_bellows/` | Salamander Breath | Dragon-head bellows: the fire-breather fits the flame cone exactly. Grip on the bellows handle. |
| Chrono Chime | `assets/weapons/chrono_chime/` | Echo Bat Horn | Clockwork gramophone horn: the sonic blast. Grip under the clock. |

## Not yet bound (proposals)

| Model | Kind | Proposal |
|---|---|---|
| Tinker Bee-zooka | gun, honeycomb barrel | **Hornet Swarm** (homing swarm from a hive tube). Clear match. |
| Bubble Blaster | gun, orange spotted bulb | **Pufferfish Mortar** (looks like a pufferfish). Clear match. |
| Alche-launcher | gun, potion flasks | **Viper Spitter** (poison globs from the flasks). |
| Storm Stinger | crossbow with a storm orb | **Galvanic Eel** (chain lightning) or the Owl Lens Rifle (precise bolt). |
| Spectral Gatling Blaster | rotary gun | **Woodpecker Repeater** (rapid fire, ricochet signature). |
| Runic Gear Cannon | heavy tube cannon | **Rhino Beetle Ram** (charge shot) or Kraken Lash. |
| Arcane Blaster | gun, glowing magenta tube | Leftover: Frost Narwhal or Silk Launcher; colour suits neither well. |
| Clockwork Chomper | gun, crocodile jaws | Leftover: Kraken Lash (a snapping grab) or a future weapon; both wheel pages are full. |
| Celestial Orbital Globe | orb with orbiting rings | Not a hand gun (as deep as it is wide). A flying enemy (an orrery sentry that orbits shards round itself), a Tortoise Sentry/Moth Lantern deployable, or a gameplay prop. |
| Clockwork Honeybee | static flyer | **New enemy**: a small swarm flyer (or a Hornet Swarm theme for a hive enemy). `flying = true`, `fit_model`. |
| Ironhorn Sentinel | rigged (28 bones, no fingers) biped minotaur knight | **New enemy** with `FoxModel` clips (shielded guard, horn charge). Too humanoid to replace the quadruped Brass Bull, whose 1.6 x 1.5 x 2.6 box the tests rely on. |
