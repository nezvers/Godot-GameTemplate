# balance.json

`balance.json` holds every tunable gameplay value. It is loaded at startup by the `Balance` autoload (`game/scripts/balance/Balance.gd`). Each balanced scene has a `BalanceBinding` node, which writes that scene's entry onto its components when the scene enters the tree.

- **Typos are reported.** A misspelled key or a node that can't be found shows up as a `WARNING: balance: ...` line in the output.
- **Removing a key is safe.** The scene's own authored value is used instead.
- **Entries are matched by `scene`.** To balance a new scene, add an entry with its `scene` path. Scenes inheriting `actor.tscn`, `weapon.tscn` or `projectile.tscn` already carry the binding.
- **IDs replace resource paths.** Wherever a scene or projectile is referenced (`projectile`, `enemies`, `instance_resource`, …), use an entry id such as `zombie`, `acid_spit` or `web_trap`. A full `res://` path also works.

## Sections

| Section | Contents |
|---|---|
| `difficulty.normal` / `difficulty.easy` | `enemy_health_ratio`, `enemy_damage_ratio` (damage the player takes), `wave_count_ratio` (kills per normal wave; boss waves are not scaled), `max_alive_ratio` |
| `player` | `health`, `movement` (`max_speed`, `acceleration`; acceleration is also the friction), `dash`, `hit_invulnerability`, `hole_damage`, `poison`/`slow`/`stuck`, `max_weapons` |
| `enemies.<id>` | `health` (the Normal value), `movement`, `resistances`, `melee` (damage, crit, interval, recoil), `ai` (attack_distance; nested AI nodes such as `ProximityAttack.start_delay`), `split`, `crit_replace`, `keep_distance`, `lob`, `drop_chance` (the health drop) |
| `bosses.<id>` | Same keys as enemies, plus `crystal_drop_chance` (boss crystal, 1 = always) and the ones below |
| `weapons.<id>` | `interval` (fire cooldown), `recoil`, `projectile`, `projectile_angles` (one projectile per angle), `random_spread`, `initial_distance`, `damage` (added to the projectile's damage), `critical_chance`, `critical_multiply` |
| `projectiles.<id>` | `damage`, `kickback`, `speed`, `lifetime` (range = speed × lifetime), `movement_type` (`PROJECTILE`, or `SHAPECAST` to bounce off walls), `max_bounce`, `hit_limit` (-1 means it pierces everything), `sub_projectile` |
| `enemy_projectiles.<id>` | `damage`, crit, `kickback`, `flight_time`, `landing_radius`, `on_land` (what spawns where it lands, and its lifetime), `on_land_split` |
| `pickups.health` | `heal` |
| `pickups.meat` / `slime` / `boss_crystal` | No tunables; the entries give the ids `meat`, `slime`, `boss_crystal` |
| `traps.<id>` | `lifetime` (seconds on the map before fading; `0` on `web_trap` means it stays until it catches someone or is shot), `fade_time`. A thrown web or acid spit uses its projectile's `on_land.lifetime` instead when that is above 0. How strong the effect is lives on whoever steps in: `poison`/`slow`/`stuck` on the player and enemies |
| `rooms.<room>` | `sections.<SectionN>` (`spawn_density`, `free_distance`, `waves`), `spawn_points.<name>.max_simultaneous`, `health_drop_chance`, `meat_drop_chance`, `slime_drop_chance` (each rolled on its own per kill; a coin always drops) |
| `contraptions.meat_grinder` | `meat_cost` (meat per health pickup) |
| `contraptions.slime_workbench` | `slime_cost` (slime per upgrade level), `max_level`, `damage_per_level` (+20% = 0.2), `interval_per_level` (fire cooldown −10% = 0.1) |
| `contraptions.slot_machine` | `coin_cost`, `nothing_weight`, `meat_weight`, `weapon_weight` (relative weights; a weapon is an unlocked weapon pickup) |

**Extra boss keys:**
- `attack_loop`: timing and enrage settings, plus one object per attack node with its windup, cooldown, distance and health gates, weight, and summon counts including `easy_count` / `easy_child_limit`. Lob attacks nest a `Lob` object with `angles` and `fixed_distance`.
- `damage_areas`: damage, crit, kickback and radius per hit area.
- `jelly_ai`: Big Jelly's AI, with its jump, chase and shoot nodes nested inside.

**Format of `damage` and `resistances`:** a number means PHYSICAL damage. An object such as `{"FIRE": 4, "PHYSICAL": 2}` mixes damage types. `0` means none.

**Wave fields:**
- `count`: kills needed to clear the wave.
- `max_alive`: most enemies spawned and alive at once. 0 or absent means only the spawn points limit it. Enemies created by splits count toward it and block new spawns, but a split can push the total above the cap.
- `enemies`: ids picked at random for each spawn.
- `is_boss`, `display_name`.
