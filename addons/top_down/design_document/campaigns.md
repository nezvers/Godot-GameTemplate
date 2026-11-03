# Campaigns: New Game, New Game+, portals

The title's **New Game** starts `game/scenes/room_N00.tscn`. **New Game+** starts
`room_P00.tscn` and is only shown once it is unlocked. Both campaigns are made by the room
builder from ASCII maps:

| campaign | data script | rooms | bosses |
|---|---|---|---|
| New Game | `game/tools/rooms_new_game.gd` | N00–N31 | Giant Zombie (N12), Broodmother (N23) |
| New Game+ | `game/tools/rooms_new_game_plus.gd` | P00–P32 | Big Jelly (P12), Plague Mother (P23), Giant Zombie (P32) |
| boss path (from room_1) | `game/tools/rooms_boss_path.gd` | C00–C31 | not a campaign: no portals |

```
N00 > N01 long hall > N02 hub ┬ west  N10 (side vault) > N11 gallery > N12 GIANT ZOMBIE
                              ├ east  N20 junction ┬ N21 strongroom (dead end)
                              │                    └ N22 > N23 BROODMOTHER
                              └ south N30 > N31 cistern (dead end)

P00 > P01 hub ┬ north P10 gullet > P11 (side vault) > P12 BIG JELLY
              ├ east  P20 junction ┬ P21 larder (dead end)
              │                    └ P22 spine > P23 PLAGUE MOTHER
              └ south P30 (side vault) > P31 long throat > P32 GIANT ZOMBIE
```

Each room has 1–3 sections. Dead-end rooms and side vaults are the fake paths. Long
corridors (N01, N11, P10, P22, P31) have spawn alcoves along the way.

## Side rooms
A side room is an alcove off the main path holding interactables:

- loot box `L`
- meat grinder `M`
- slime workbench `K`
- slot machine `$`

The room spec marks it with `"side_room": <section>`, which must be the room's last
section. That section is written without `requires`, and no gate waits for it, so its
guard fight is optional. The alcove is closed by a gate, a `3` barrier and a `z` trigger.

To add a new interactable:
1. Put its scene in `scenes/interactables/`. Give it an `AstarShapeObstacle` pointing at its
   `StaticBody2D`, so enemies path around it rather than into it. The obstacle blocks every grid
   tile its body touches, and frees them while the node is disabled, as with the hidden
   workbench. `game/tests/obstacle_path_check` checks that the blocked tiles never cut off
   floor and that a zombie walks around each contraption.
2. Add a character for it to `INTERACTABLES` in `game/tools/build_rooms.gd`.
3. Place it in a side room of each campaign. `campaign_check` fails until every
   interactable scene appears in every campaign.

## Loot box
`scenes/interactables/loot_box.tscn` (`LootBox.gd`, extends `SlotMachine`) is free and
opens once. It pays out one weighted entry of `contraptions.loot_box.payouts` in
balance.json. It stays open for the run: `RoomStateResource.looted` remembers it until
the next campaign start.

## Portals
`scenes/obstacles/portal.tscn` (`game/scripts/Portal.gd`, extends `SceneEntry`) is shut
and hidden until the room in `open_when_cleared` is cleared, then appears as the open vortex.

- **Boss room:** `O` goes to the campaign hub. `V` is the victory exit to
  `victory.tscn`. Both wait for the boss room itself.
- **Hub:** has one portal per boss room. Each waits for its boss room, so killing a boss
  opens a two-way shortcut for the rest of the run.

The builder checks that every boss fight is the room's last section, that every
campaign boss room has `O` and `V`, and that every portal arrives at a portal of its
target room.

## Run state and New Game+
- **Campaign start:** the start rooms (`"start": true`) get a `FreshStart`. A fresh start
  resets the run resources, including `RoomStateResource`, so cleared rooms, portals and
  loot boxes all start over. It also records itself as `CampaignResource.start_scene`.
  Try Again (game over) and Play Again (victory) use `CampaignRestartButton` to restart
  that campaign.
- **Starting weapon:** each `w` cell in a start room's map becomes a `StartingWeaponSpawner`
  spot. It holds one random unlocked weapon, and the room's doors stay hidden until every
  spot is picked up, as in `room_start`. Walking back in through a door places nothing.
  The N00 and P00 start rooms have one `w` each.
- **Unlocking New Game+:** walking through a boss room's victory exit opens the victory
  screen. That calls `CampaignResource.unlock_ng_plus()`, which is saved as
  `user://Campaign.tres` and loaded at boot by `PersistentData`. The title's
  `NewGamePlusEntry` shows New Game+ from then on.

## Editing a campaign
1. Edit a map in a `rooms_*.gd` data script. See the legend at the top of
   `build_rooms.gd`.
2. Rebuild:
   `Godot --headless --path . res://game/tools/build_rooms.tscn [-- N02 P10]`.
   It rewrites the room scenes. For campaign rooms it also rewrites their balance.json
   `rooms` entries and leaves every other entry as it is.
3. Check: `Godot --headless --path . res://game/tests/campaign_check.tscn`.
