# Model inventory

Every imported model and what it is (or should be) bound to. Models still in
`imported_models/` are unused; move one into `assets/` when something uses it (see
`docs/art-pipeline.md`, "Model conventions", and CLAUDE.md, "Imported models").

Assessed 2026-11-02 from a contact sheet of each model (front, side, top, three-quarter).
All static exports are about 1 m across and centred; guns lie along X with the barrel at -X.
Held models are rolled upright for the aim pose by `HeldModel`; grips were read off a 0.1 m grid render.

## Bound

| Model | Where | Bound to | Notes |
|---|---|---|---|
| Coal Beetle | `assets/enemies/coal_beetle/` | **new enemy** `CoalBeetle` | Static. Lava-cracked shell with chimneys: crawls leaving `CoalEmber` patches, stokes then belches coals that leave embers, scorches up close. Fire-proof, frost quenches it (exposed). Wave 9. |
| Racoon Rogue | `assets/enemies/raccoon_rogue/` | **new enemy** `RaccoonRogue` | Rigged (64 bones, SmartRig). Drives `FoxModel`'s baked clips. Glimmer thief: darts in, swipes, steals and flees; hits shed loot, a kill spills it, otherwise it escapes. Wave 9. |
| Dragon Bellows | `assets/weapons/dragon_bellows/` | Salamander Breath | Dragon-head bellows: the fire-breather fits the flame cone exactly. Grip on the bellows handle. |
| Chrono Chime | `assets/weapons/chrono_chime/` | Echo Bat Horn | Clockwork gramophone horn: the sonic blast. Grip under the clock. |
| Tinker Bee-zooka | `assets/weapons/tinker_bee_zooka/` | Hornet Swarm | Hive tube for the homing swarm. |
| Bubble Blaster | `assets/weapons/bubble_blaster/` | Pufferfish Mortar | The spotted orange bulb reads as a pufferfish. |
| Alche-launcher | `assets/weapons/alche_launcher/` | Viper Spitter | Poison from the flasks. |
| Spectral Gatling Blaster | `assets/weapons/spectral_gatling/` | Woodpecker Repeater | Rotary barrels for the rapid-fire starter; held by its rear handle. |
| Storm Stinger | `assets/weapons/storm_stinger/` | Galvanic Eel | Storm-orb crossbow for chain lightning. |
| Runic Gear Cannon | `assets/weapons/runic_gear_cannon/` | Rhino Beetle Ram | Heavy charge cannon. Its grip sits under the muzzle end, so most of it lies behind the hand. |
| Clockwork Honeybee | `assets/enemies/clockwork_honeybee/` | **new enemy** `ClockworkHoneybee` | Static flyer. Hovers low round the target, winds up and darts through it; a swarm takes turns (one attacker at a time within `swarm_radius`). Fragile, flinches. Wave 10 (x5). |
| Ironhorn Sentinel | `assets/enemies/ironhorn_sentinel/` | **new enemy** `IronhornSentinel` | Rigged (28 bones). FoxModel clips: the staff swings are its punches. Jab, hook, then a slam with a Shockwave ring to jump, then a long winded opening. Heavy, never flinches. Wave 10. |

## Not yet bound (proposals)

| Model | Kind | Proposal |
|---|---|---|
| Arcane Blaster | gun, glowing magenta tube | Frost Narwhal, Silk Launcher, Owl Lens Rifle, Kraken Lash, Clockwork Swallow (and the deployables) have no model yet; the magenta tube suits none of them well. Keep for a new weapon or the Owl Lens Rifle. |
| Clockwork Chomper | gun, crocodile jaws | Kraken Lash (a snapping grab) or a future weapon; both wheel pages are full. |
| Celestial Orbital Globe | orb with orbiting rings | Not a hand gun (as deep as it is wide). A flying enemy (an orrery sentry that orbits shards round itself), a Tortoise Sentry/Moth Lantern deployable, or a gameplay prop. |
