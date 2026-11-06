# Home base

The home base (`game/scenes/room_H00.tscn`, **Home Base** on the title) is a room without fights. It is built by `game/tools/build_rooms.gd` from `game/tools/rooms_home.gd`.

## Memory grid

The grid hall holds a 30x30 array of pistons, which works like addressable memory. Its size is `grid_size` in the spec; `PistonGrid.size` supports 100.

- **Pistons** (`scenes/home/piston.tscn`, `Piston.gd`) are BlockWalls driven by code (`ArenaDoorBlock.set_raised`). A raised piston blocks movement and is solid in the enemy AStar grid.
- **Lane levers** (`GridLever`):
  - The extra column on the right (+x) has one lever per row.
  - The extra row at the bottom (+y) has one lever per column.
  - A lever toggles its lane's select.
  - Cell (0, 0) and lever 1 of each lane sit at the bottom-right corner where the two lever lanes meet. Every lever shows its number.
- **Control room**, just past that corner:
  - The **gate lever** (`GateLever`) picks how a row select and a column select combine into a cell select: AND (only crossings), OR, XOR, NAND, NOR or XNOR. The selected cells show a yellow preview.
  - The **data lever** (`DataLever`) picks RAISE or LOWER.
  - The **Write button** (`WriteButton`) puts that value into every selected cell. The write ripples out from the corner.
  - The **reset button** (`ResetButton`) turns every lane lever off.
- **Write results** (`Piston.WriteResult`):
  - `OK`: the cell changed.
  - `UNCHANGED`: the cell already held the value.
  - `SHORTED`: the cell is wet, so it sparks and keeps its state.
  - `BLOCKED`: somebody stands on the cell, so it won't rise.
- **Water gun:**
  - A water shot that lands on the grid wets that single piston for `Piston.wet_time` (60 s). The wet piston then masks its bit on every write.
  - The gun is never a random start weapon (`unlocked = false`).
  - If nobody holds it and it isn't lying anywhere, it reappears at the control room spot `g`.

## Weapons between missions

The weapon state is saved in `game/resources/home_base_resource.tres` (`HomeBaseResource`, `user://HomeBase.tres`).

- **Arriving at the home base:**
  - `HomeBase` resets the run state.
  - The player is handed `stash_inventory`.
  - The weapons in `dropped` are put back where they were.
  - The grid state, the lane selects, the gate, the data value, the dropped weapons and the held weapons are saved whenever they change.
- **Dropping:** the drop key (G or gamepad Y, rebindable) drops the selected weapon anywhere. Fists can't be dropped.
- **Leaving:** the MISSION stairs (`HomeExitGate`) take the player to room_N00 with at most one weapon. That weapon becomes `loadout`, and `FreshStart` hands it over.
  - With a carried gun, the start room's stairs are open from the start. The random gun is still offered.
  - With only fists, the stairs open once the random gun is picked up.
- **Coming back:**
  - After a victory or an extract, `VictoryScreen` adds the run's weapons to `stash_inventory`.
  - A game over loses them.
  - Weapon upgrades stay with the run.

## Puddles

Puddle guns lob a `puddle_shot_projectile.tscn` variant to the aimed point (`ProjectileSpawner.lob_range`). Its `PuddleOnLand` spawns the gun's puddle there.

Each puddle sets a BoolResource that an effect node in `actor.tscn` reacts to. A `PulseEffect` creates the BoolResource itself when the actor lacks one.

| Puddle | Effect | Who | Balance |
|---|---|---|---|
| `water_puddle` | `SlipperyEffect`: low acceleration, so the actor slides | everyone | `player.slippery` |
| `player_acid_puddle` | `AcidEffect` (a PoisonEffect on "acid"): damage over time | enemies only | `traps.player_acid_puddle` |
| `blood_puddle` | `EmpoweredEffect`: outgoing damage multiplier (`ActorStatsResource.get_damage_multiply`, applied by `ProjectileSpawner`) | everyone | `player.empowered` |

An acid gun or a blood gun only needs a projectile inheriting `puddle_shot_projectile.tscn` with `wets_pistons = false`, plus a weapon scene modelled on `water_gun.tscn`.
