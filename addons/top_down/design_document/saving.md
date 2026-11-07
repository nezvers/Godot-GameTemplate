# Saving

Two kinds of state go to disk under `user://`. Both use `SaveableResource` text `.tres` files.

- **Meta progress** is permanent and loaded at boot from `PersistentData.saveable_list`: Campaign, MetaUpgrades, BossCrystals, HomeBase, Profile and settings.
- **The run checkpoint** (`RunSave.tres`) holds one campaign run in progress. The title's **Continue** reads it.

## Run checkpoint

The `RunSession` autoload (`game/scripts/run/RunSession.gd`) owns the run and its players (`PlayerRegistry`).

**A run starts** in one of two ways:
- In a campaign start room: `FreshStart` resets the run and calls `start_new_run()`, which deletes any old save.
- From the title's Continue: `resume()`.

**A checkpoint is written** while the run is active:
- when the party is placed in a room (`PlayerSpawner` calls `on_party_placed` for a door arrival, a fresh spawn or a resume)
- whenever room progress changes (`RoomStateResource.updated`: a section or room cleared, a loot box opened)
- on Pause → Main Menu (`SaveAndExitButton`)
- when the window is closed

**The save is deleted** on game over (`GameOverDetect`) and on victory (`VictoryScreen`). The run's weapons are lost or sent home at that point, so the save must not bring them back.

**The save is kept** when you go to the title or the home base: `suspend()` only stops checkpointing. The run's weapons only go home on victory, so visiting the home base can't duplicate them.

**Granularity:** the save is a room checkpoint. Continue puts you at the door you came in through, or at the room's spawn marker for a start room. It brings back cleared rooms and sections, opened boxes, HP, weapons, weapon upgrades, coins, meat and slime. A wave you were in the middle of starts over.

## Format

```
RunSave (SaveableResource)          game/scripts/run/RunSave.gd
  format_version, game_version, saved_at_unix, mode (SINGLE / COOP_HOST)
  campaign_start_scene, room_scene, entry_tag
  players: Array[PlayerRunData]     one per player, matched by profile_id
  components: Array[RunSaveComponent]
```

- **`PlayerRunData`** holds hp/max_hp, the inventory as weapon *names*, the selected weapon, `weapon_levels` and the wallet (`coin`, `meat`, `slime` with value and collected_total).
  - Names are looked up again with `HomeBaseResource.find_item`, so changes to the weapon database don't break saves.
- **`PlayerState`** (`game/scripts/run/PlayerState.gd`) is the live counterpart.
  - The local player's state points at the shared global resources (`player_health`, `weapon_inventory`, `weapon_upgrade_resource`, the counters), so the player scene and HUD are unchanged.
  - Co-op teammates get their own copies (`create_remote`).
- **HP goes back last**, in `RunSession.finish_resume` once the player node is ready. Balance and `MetaStats` reset it on spawn.

## Adding run state

1. Subclass `RunSaveComponent` with a unique `id()`, exported fields, `capture()` and `apply()`. `RoomProgressComponent` is the example.
2. Append the script to `RunSession.COMPONENTS`.
3. When its fields change meaning later, override `current_version()` and handle older data in `migrate(from_version)`.

Older saves without the component get a fresh one, so `apply()` must cope with defaults. A change to the RunSave layout itself bumps `RunSave.FORMAT_VERSION`; anything newer than the code knows is not offered for Continue.

Per-player state goes into `PlayerRunData` and `PlayerState.capture/apply`. Anything added there also needs a line in `to_dict`/`from_dict`, so co-op guests can send it to the host.

## Co-op

- Only the host writes the checkpoint (`mode = COOP_HOST` while guests are connected).
- Each guest's entry is the state that guest last sent, so weapons, upgrades and wallet are complete.
- Guests missing on Continue keep their entries (`RunSession.waiting_guests`) until they rejoin.
- See multiplayer.md for the details.

## Safety

- `RunSave.read()` loads with `CACHE_MODE_IGNORE`. It rejects files that embed a GDScript (a `.tres` can carry script source) and files that aren't a valid `RunSave`.
- Network traffic never sends `.tres` data.

## Tests

- `game/tests/run_save_check.tscn` covers the round trip, the door placement, HP after the spawn reset, start-room resume, missing components and deletion when the run ends.
- Headless runs use `RunSave_headless.tres` (and the test uses `RunSave_test.tres`), so the suites never touch a real checkpoint.
