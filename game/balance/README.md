# balance.json

`balance.json` holds every tunable gameplay value. It is loaded at startup by the `Balance` autoload (`game/scripts/balance/Balance.gd`). Each balanced scene has a `BalanceBinding` node, which writes that scene's entry onto its components when the scene enters the tree.

- **Typos are reported.** A misspelled key or a node that can't be found shows up as a `WARNING: balance: ...` line in the output.
- **Removing a key is safe.** The scene's own authored value is used instead.
- **Entries are matched by `scene`.** To balance a new scene, add an entry with its `scene` path. Scenes inheriting `actor.tscn`, `weapon.tscn` or `projectile.tscn` already carry the binding.
- **IDs replace resource paths.** Wherever a scene or projectile is referenced (`projectile`, `enemies`, `instance_resource`, …), use an entry id such as `zombie`, `acid_spit` or `web_trap`. A full `res://` path also works.

## Sections

| Section | Contents |
|---|---|
| `difficulty.normal` / `difficulty.easy` | `enemy_health_ratio`, `enemy_damage_ratio` (damage the player takes), `wave_count_ratio` (kills per normal wave; boss waves are not scaled), `max_alive_ratio` (0 = no cap), `spawn_interval` and `timed_spawners` (see **Spawn pacing** (`difficulty.<mode>.spawn_interval`, `timed_spawners`):
- Every active spawn point keeps its slots filled (`spawn_density`, capped by `max_simultaneous`): the wave opens with that burst and a point refills when its enemies die. This is all Easy does (`timed_spawners` 0).
- Timed points also spawn every `spawn_interval` seconds (Normal: 2) whether or not their enemies are alive, each on its own timer, first firing one interval after the burst. Normal has `timed_spawners` 1; the HORDE Nest upgrades add more, up to 6 and never more than the section's active points. They are picked at random per wave.
- Both keep the kill quota (`count`), the `max_alive` cap and `free_distance` (0 turns that check off). A spawn mark in flight counts once toward the quota and cap.
- Other HORDE stats: `spawn_rate_ratio` divides the interval by `1 + ratio`, `spawner_count` adds enemies to every spawn event (the slots grow to match) and `wave_count_ratio` grows normal waves.

**Format of `damage` and `resistances`:** a number means PHYSICAL damage. An object such as `{"FIRE": 4, "PHYSICAL": 2}` mixes damage types. `0` means none.

**Wave fields:**
- `count`: kills needed to clear the wave.
- `max_alive`: most enemies spawned and alive at once. 0 or absent means only the spawn points limit it. Enemies created by splits count toward it and block new spawns, but a split can push the total above the cap. A difficulty `max_alive_ratio` of 0 (Normal) turns the cap off.
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
| `trees` | Separate graphs, shown one at a time and switched with the header button or Tab: `{"<tree>": {"title", "root"}}`. `main` (UPGRADES, root `root`) holds the player upgrades; its sister tree `horde` (HORDE, root `horde_root`) holds the enemy buffs, which pay back with `loot_ratio` |
| `labels` | Branch names drawn faintly on the graph: `{"text", "pos", "tree"}`, pos in cells (fractions allowed), tree `main` when left out |
| `nodes.<id>` | One upgrade, see below. Each tree's root is free and always owned |

**Node keys:**
- `tree`: which tree it belongs to, `main` when left out. `requires` must stay inside the tree.
- `pos`: `[x, y]` in grid cells of its tree; `[0, 0]` is the root, `y` grows downward.
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
| `timed_spawners` | `1` = one more spawn point on its own spawn timer (Normal only; at most 6 in all, and no more than the room's points) |
| `spawn_rate_ratio` | `1.0` = timed points spawn twice as often (the spawn timer is divided by 1 + total). No effect on Easy |
| `wave_count_ratio` | `1.0` = twice the kills per normal wave, on top of the difficulty's `wave_count_ratio`. Boss waves are not scaled |
| `spawner_count` | `1` = every spawn event makes 2 enemies, on a small ring around the spawn point |
| `loot_ratio` | `0.1` = +10% chance on every enemy drop except boss crystals, on top of the room's `loot_multiplier` |

The frame, cursor and icon art comes from `addons/top_down/assets/images/gui/generate_meta_frames.py`. Rerun it after changing it.
