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
| `enemies.<id>` | `health` (the Normal value), `movement`, `resistances`, `melee` (damage, crit, interval, recoil, `projectile`: the weapon node `SlashAttack` may be any weapon, the skeleton's katana and the mage's revolver included), `ai` (attack_distance; nested AI nodes such as `ProximityAttack.start_delay`, and `ProximityAttack.require_line_of_sight` so ranged enemies don't shoot into walls), `split`, `crit_replace`, `keep_distance`, `lob`, `drop_chance` (the actor's own health drop on death), `drops` (see **Loot** below). Special attacks use the boss keys `attack_loop` and `damage_areas` (see **Enemy special attacks**) |
| `bosses.<id>` | Same keys as enemies, plus the ones below. Give bosses `"boss_crystal": 1` in `drops` |
| `weapons.<id>` | `interval` (fire cooldown), `recoil`, `projectile`, `projectile_angles` (one projectile per angle), `random_spread`, `initial_distance`, `damage` (added to the projectile's damage), `critical_chance`, `critical_multiply`, `upgrades`, `jackpot_weight`, `price` (see **Weapon upgrades**). `weapons.fists` is the player's fallback while the inventory is empty (an invisible zombie-claw weapon firing `projectiles.fist_slash`, a katana slash without the flying blade; tune its damage there); it has no upgrades, jackpot weight or price |
| `projectiles.<id>` | `damage`, `kickback`, `speed`, `lifetime` (range = speed × lifetime), `movement_type` (`PROJECTILE`, or `SHAPECAST` to bounce off walls), `max_bounce`, `hit_limit` (-1 means it pierces everything; `sword_slash` uses it so a swing cleaves a whole pack, each enemy is still hit once per swing), `sub_projectile` |
| `enemy_projectiles.<id>` | `damage`, crit, `kickback`, `flight_time`, `landing_radius`, `on_land` (what spawns where it lands, and its lifetime), `on_land_split` |
| `pickups.health` | `heal` |
| `pickups.meat` / `slime` / `boss_crystal` | No tunables; the entries give the ids `meat`, `slime`, `boss_crystal` |
| `traps.<id>` | `lifetime` (seconds on the map before fading; `0` on `web_trap` means it stays until it catches someone or is shot), `fade_time`. A thrown web or acid spit uses its projectile's `on_land.lifetime` instead when that is above 0. How strong the effect is lives on whoever steps in: `poison`/`slow`/`stuck` on the player and enemies |
| `rooms.<room>` | `sections.<SectionN>` (`spawn_density`, `free_distance`, `waves`), `spawn_points.<name>.max_simultaneous`, `loot_multiplier` (scales every enemy `drops` chance in that room; 1 = as listed) |
| `contraptions.meat_grinder` | `cost` (item list), `rewards` (list of `{"drop", "amount"}` spawned at the output) |
| `contraptions.slot_machine` | `cost` (item list per pull), `payouts` (see **Slot machine**) |

**Extra boss keys:**
- `attack_loop`: timing and enrage settings, plus one object per attack node with its windup, cooldown, distance and health gates, weight, and summon counts including `easy_count` / `easy_child_limit`. Lob attacks nest a `Lob` object with `angles` and `fixed_distance`.
- `damage_areas`: damage, crit, kickback and radius per hit area.
- `jelly_ai`: Big Jelly's AI, with its jump, chase and shoot nodes nested inside.

**Enemy special attacks:** normal enemies reuse the boss `attack_loop` / `damage_areas` keys. Set `enrage_health: 0` so they never enrage.
- `enemies.slime`: `attack_loop.Charge`, an occasional dash along a telegraphed line (the Giant Zombie charge, scaled down), plus `damage_areas.ChargeDamage`.
- `enemies.acid_slime`: `lob`, which throws `acid_spit` every `cooldown` seconds while the player is within `shoot_range`.
- `enemies.bloater`: `attack_loop.Jump`, a leap at the player within `min_distance`..`max_distance`. The landing spot is marked during the windup, then landing deals `damage_areas.JumpDamage` and pushes with `JumpPush`. `max_jump_distance` and `jump_time` shape the leap; `kickback_radius` / `kickback_max` / `kickback_min` set the push falloff.
  - **Burst:** at or below `burst_health` (a health ratio), each jump has `burst_chance` to pop on landing. The bloater dies and `split` releases its zombies. A burst telegraph is redder and its areas are `burst_area_scale` larger.

**Format of `damage` and `resistances`:** a number means PHYSICAL damage. An object such as `{"FIRE": 4, "PHYSICAL": 2}` mixes damage types. `0` means none.

**Wave fields:**
- `count`: kills needed to clear the wave.
- `max_alive`: most enemies spawned and alive at once. 0 or absent means only the spawn points limit it. Enemies created by splits count toward it and block new spawns, but a split can push the total above the cap.
- `enemies`: ids picked at random for each spawn.
- `is_boss`, `display_name`.

## Loot

**Item ids:** `coin` (also the score), `meat`, `slime`, `boss_crystal`. Drops can also use `health`.

**Item lists** describe every cost, e.g. `[{"item": "slime", "amount": 2}, {"item": "meat", "amount": 3}]`. A cost is paid only when the player has every entry.

**Enemy drops:** `enemies.<id>.drops` / `bosses.<id>.drops` map an item id to a chance, e.g. `{"coin": 1, "meat": 0.4, "slime": 0.1, "health": 0.3}`.
- Each item rolls on its own when an arena kill clears the enemy.
- A chance above 1 means guaranteed drops plus a roll for one more: `2.5` is 2, with 50% for a third.
- The room's `loot_multiplier` scales every chance first.
- A split slime's children share their parent's single roll.

## Weapon upgrades

`weapons.<id>.upgrades` is a list with one entry per level, bought in order at the slime workbench. Max level is the list length.

```json
"upgrades": [
	{"cost": [{"item": "slime", "amount": 2}], "damage": 1.2, "interval": 0.9},
	{"cost": [{"item": "slime", "amount": 2}, {"item": "meat", "amount": 3}], "damage": 1.4, "interval": 0.8},
	{"cost": [{"item": "slime", "amount": 3}, {"item": "boss_crystal", "amount": 1}], "damage": 1.7, "interval": 0.7}
]
```

- `damage` and `interval` are the multipliers at that level, not steps: level 2 above deals ×1.4 damage and fires with ×0.8 cooldown.
- `jackpot_weight` is how likely the slot machine's weapon payout picks this weapon, relative to the other unlocked weapons. With 0 or no value, the weapon never comes from the slot machine.
- `price` is an item list for buying the weapon. Nothing uses it yet; it is for a future shop.

## Slot machine

`contraptions.slot_machine.payouts` is a list of `{"drop", "amount", "weight"}`. One entry is picked by weight per pull.
- `drop` is `nothing`, `weapon` (a pickup picked by the weapons' `jackpot_weight`), or a loot item id.
- `amount` is how many pickups spawn.

# upgrades.json

`upgrades.json` holds the meta-upgrade graph: everything bought with boss crystals on the Upgrades screen (`game/scenes/meta_upgrades.tscn`). It is read by `MetaUpgrades` (`game/scripts/meta/MetaUpgrades.gd`). Unknown stats, icons and `requires` ids show up as `WARNING: upgrades: ...`. `game/tests/meta_upgrade_check.tscn` checks the whole file.

The Upgrades button shows on the title, game over and victory menus once a boss crystal has ever been picked up. Bought nodes are saved in `user://MetaUpgrades.tres`.

| Key | Contents |
|---|---|
| `grid` | Pixels per grid cell |
| `labels` | Branch names drawn faintly on the graph: `{"text", "pos"}`, pos in cells (fractions allowed) |
| `nodes.<id>` | One upgrade, see below. `root` is free and always owned |

**Node keys:**
- `pos`: `[x, y]` in grid cells; `[0, 0]` is the root, `y` grows downward.
- `icon`: `star`, `heart`, `sword`, `boot`, `dash`, `shield`, `coin`, `meat`, `slime` or `crystal`.
- `keystone`: `true` gives the big golden frame.
- `title`, `text`: `{stat}` in the text is replaced by that effect's amount, e.g. `"{max_hp} max health."` reads `+10 max health.`
- `cost`: an item list, e.g. `[{"item": "boss_crystal", "amount": 2}]`.
- `requires`: node ids. Owning **any one** of them makes the node buyable. A link is drawn to each.
- `effects`: stat key -> amount. Amounts add up over every owned node.

**Stats:**

| Stat | Effect |
|---|---|
| `max_hp` | Added to the player's max health |
| `hit_invulnerability` | Seconds added to the invulnerability after a hit |
| `damage_ratio` | `0.1` = +10% damage on every weapon, on top of workbench levels |
| `speed_ratio` | `0.08` = +8% max speed |
| `dash_cooldown_ratio` | `0.15` = dash cooldown 15% shorter |
| `start_coin` / `start_meat` / `start_slime` | Items at the start of every run |

The frame, cursor and icon art comes from `addons/top_down/assets/images/gui/generate_meta_frames.py`. Rerun it after changing it.
