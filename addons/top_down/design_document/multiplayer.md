# Multiplayer (co-op)

**Plan:** co-op for 2 players first, built for up to 8 (`PlayerRegistry.MAX_PLAYERS`). The host is authoritative: the host's machine (later a dedicated server) owns the world, and guests send it requests.

## Done so far

### Session: the `Net` autoload (`game/scripts/net/Net.gd`)
- **States:** `OFFLINE`, `HOSTING`, `CONNECTING`, `JOINED`.
  - Offline uses Godot's `OfflineMultiplayerPeer`, so `Net.is_authority()` is true in single player and gameplay code needs no special cases.
- **Transport:** `NetTransport`, currently `ENetTransport` (direct IP, default port 24565).
  - Hosting tries a UPnP port mapping and lists the LAN and public addresses to share.
  - A Steam transport can replace it without touching gameplay code.
- **Handshake:**
  1. The guest sends `_hello {protocol, game_version, profile_id, name}`.
  2. The host checks the version, a free slot, that the profile isn't already in the session, and `Net.accepting` (true while in the home base lobby).
  3. The host replies `_welcome {slot, roster}`, or `_rejected {reason}` and drops the guest after `REJECT_GRACE`.
  - Every change to the roster is broadcast with `_roster_update`.
- **Security:**
  - `allow_object_decoding` is off and guests only send plain values.
  - Host handlers check the sender and validate every argument.
  - A guest that doesn't say hello within 5 s is dropped.

### Players
- `RunSession.players` (`PlayerRegistry`) maps slots to `PlayerState`.
  - The local player's state uses the shared global resources (HUD, player scene).
  - Every guest has its own HP, inventory, weapon upgrades and wallet (`PlayerState.create_remote`).
- `PlayerProfile` (`user://Profile.tres`) gives each install a random `profile_id` and a display name.

### Comms Terminal (home base, map character `N`)
- `CommsTerminal.gd` opens `CoopDialog.gd`.
  - **Offline**, it shows two tabs:
    - **Host:** set the port and press Open to friends.
    - **Join:** type an address (`ip` or `ip:port`) or pick from recent hosts (`NetSettings`, `user://NetSettings.tres`), then connect.
  - **In a session**, only the **Session** tab remains, and it opens on its own when you host, join, or reopen the dialog. It shows:
    - the players, with the host marked and a Kick button on each guest for the host
    - Invite: what a friend types, with a Copy button per address (internet when UPnP mapped the port, the network-card LAN addresses with Docker/VM/VPN interfaces filtered out, and 127.0.0.1 for the same computer), plus a port-forwarding hint when there's no internet address
    - Leave session
- While the dialog is open, player input is frozen. Escape closes the dialog without opening the pause menu, and the room keeps running.
- The terminal's screen is lit while a session is open.

## Next

8. **Dedicated server (not built yet):**
   - Launched with `--server --port --max-players --save-dir`, using a headless export preset.
   - The server has no local player of its own. `TransitionManager.instant` already covers windowless scene changes.

## Tests
- `game/tests/net_loopback_check.tscn` runs a real ENet session on 127.0.0.1 with a second headless game (`net_client.tscn`) and covers joining, rejection, the lobby gate and kicking.
- `game/tests/coop_terminal_check.tscn` covers the terminal, the dialog, the input freeze and Escape.
- `game/tests/coop_world_check.tscn` plays two real games together (the guest is `net_client.tscn` "world" mode). It covers:
  - characters, weapons, HP and the party panel
  - following through rooms and doors, and pausing online
  - enemy copies, hits in both directions, shot copies and loot
  - fights, down and revive, the party wipe, saved guest state and the host leaving

## Seeing each other (phase 5)

`NetPlayers` (`game/scripts/net/NetPlayers.gd`, created by `Net` as `/root/Net/Players`) runs on every peer.

- **Updates:** each machine sends its player about 20 times a second, unreliably: room, position, move and aim direction, weapon name, hp, max_hp and downed. Guests' updates reach the other guests through the host's server relay. The receiver checks that the sender owns the slot and that every value has the right type and range.
- **Puppets:** a teammate in your room appears as a `RemotePlayer`.
  - It is `player.tscn` with the local-only nodes removed (input, camera, player reference, juice, ResetHealth, MetaStats).
  - Its health and weapons point at the teammate's `PlayerState`. Only the weapon in hand is sent, so the puppet holds just that one.
  - Its damage and pickup receiver is off. Its body stays on the player layer so the host's doors notice it.
- **Party panel:** `PartyPanel` (`game/scripts/ui/PartyPanel.gd`, in `game_hud.tscn`) is docked to the right edge.
  - It has one card per teammate (never the local player), showing their name in the slot colour, an HP bar and numbers, and their weapon icon and name.
  - A card is dimmed with "(away)" when that teammate is in another room, or marked "DOWN".
  - Info about other players lives here, never over their heads.
- **Rooms:** the host leads.
  - When the host's scene changes, guests get `_follow_room(path, entry_tag)` and load the same room, arriving through the same door.
  - A guest leaving its home base calls its own `HomeBase.depart()`, so its one gun goes along.
  - A guest's own doors and home exit don't fire. On the host, a teammate walking into a door moves the whole party.
- **Saves:** guests never write or delete `RunSave`.
- **Pause:** online, the pause menu doesn't freeze the room (`ProcessingComponent.keep_running_online`). Only the local player stops.
- **Leaving:** the host going to the title ends the session. A guest whose host leaves mid-run goes back to its own home base.
- **Instant transitions:** `TransitionManager.instant` (or the user argument `--instant-transitions`) loads scenes without the screen grab. It's for windowless runs such as tests and a future server.

## The world: enemies, shots, loot and fights (phase 6)

`NetEntities` (`game/scripts/net/NetEntities.gd`, `/root/Net/Entities`) sees every spawn through `InstanceResource.instanced_hook`.

- **Enemies and loot** (InstanceResources under `actors/` and `pickups/`, except the player and weapon pickups):
  - On the host, each one gets a net id and is created on the guests in the same room. A guest that arrives late gets everything alive at once (a full sync).
  - On a guest, the copy of an enemy is a puppet: every child outside `PUPPET_KEEP` (AI, attacks, movement, splitting, drops) is switched off. `NetPuppet` moves it from the host's 20 Hz snapshots and shows the host's share of hp.
  - Copies never go back into the pool, or a later solo game would get puppets.
  - When the host's enemy leaves, the copy goes too, with ActorDamage's death effect if it died.
- **Arena fights** run only on the host (`ArenaSection.try_start` and the spawn loop do nothing on a guest). Guests mirror the state with `apply_net_state`, so doors, walls, announcements and the HUD follow.
- **Damage:**
  - A guest's hit on an enemy copy is measured on the guest (crits and resistances as usual) and sent as `_hit`. The host applies it with `NetEntities.apply_hit`, so splits, deaths and drops happen there.
  - On the host, enemy attacks hit the teammate's copy (`RemotePlayer`, which keeps only its damage receiver). The hit is sent to that teammate (`_hurt`), and its own machine applies it, respecting its hit cooldown.
  - The hook is `DamageResource.forward_hit`: `DamageDataResource.process` measures the hit and hands it over instead of applying it.
- **Shots:**
  - Every projectile spawned on a machine, other than a replay, is replayed on the others as a harmless copy. The copy hits walls only, does no damage and has no push.
  - Puddles and traps come from those copies on each machine and only affect that machine's player. Teammates' copies have no trap receiver.
- **Loot:**
  - Each machine collects only for its own player (`CollectingPoint` checks the body).
  - A guest that picks up a copy tells the host (`_collected_here`), and the host removes it for everyone.
  - Loot landing under a standing player is collected too. This also fixes single player.
- **Not yet replicated:**
  - Boss charge and slam hit-boxes, which live on the boss itself, only hurt the host's player.
  - Damage status effects (none are in use yet).
  - Weapon pickups each machine places for itself (start weapons, drops from inventories).

## Co-op rules (phase 7)

- **Down, not dead:**
  - While online with a teammate, 0 hp downs the player (`Downed`, added by `NetPlayers`, hooked through `HealthResource.down_instead`).
  - A downed player can't move, shoot or be hurt, and lies greyed out. Teammates see the same pose, and the party panel shows DOWN or REVIVING %.
  - A teammate standing within `revive_radius` for `revive_time` revives them with `revive_hp_ratio` hp. Clearing the room revives everyone.
  - Once everyone is down, the host sends `_party_wiped`, everyone dies for real, and each machine goes to game over. Guests follow the host from there.
  - Offline, or alone in a session, death is unchanged.
- **Scaling:** `balance.json` `coop` sets:
  - `enemy_health_per_player`, applied in DifficultyHealth
  - `wave_count_per_player`, applied in `ArenaSection._wave_quota`
  - `revive_time`, `revive_radius` and `revive_hp_ratio`
  - Everything is 1x alone (`CoopScaling`).
- **Rewards:** each machine runs its own victory screen, so a guest's extracted weapons go to its own `HomeBase` stash, and the crystals it picked up go to its own `BossCrystals`.
- **Co-op save:**
  - The host's checkpoint is `mode = COOP_HOST` while guests are connected.
  - Every 2 s, a guest sends its own run state (`PlayerRunData.to_dict`, validated by `from_dict`), and the checkpoint stores that instead of the host's partial view.
  - On Continue, guests that aren't back yet wait in `RunSession.waiting_guests`, and stay in later checkpoints.
  - A guest that rejoins with its profile gets its weapons, upgrades, wallet and hp back once it reaches the host's room (`_restore_run`).
  - Guests never write a run save of their own.

Test: `game/tests/coop_world_check.tscn` uses two real games, with the guest in `net_client.tscn` "world" mode.
