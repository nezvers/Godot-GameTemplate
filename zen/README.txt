ZEN ANIMATIONS - HOW TO USE THIS EXPORT
Exported from Zen Animator 2c6c7a2, 2026-11-01.
Runtime: standalone - a private copy in zen/zen_runtime/, no plugin needed.

SCENES IN THIS EXPORT
  res://zen/zs_wave_start.tscn
      elements: band, title, sub, skull_l, skull_r
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 wave (sample "3") in "WAVE %1"
        %2 enemies (sample "24") in "%2 MONSTERS INCOMING"
      plays once, then emits finished
  res://zen/zs_wave_cleared.tscn
      elements: splat, check, title, sub
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 wave (sample "3") in "WAVE %1 CLEARED"
        %2 waves_left (sample "2") in "%2 WAVES LEFT"
      plays once, then emits finished
  res://zen/zs_boss_wave.tscn
      elements: flash, band, stripe_0_0, stripe_0_1, stripe_0_2, stripe_0_3, stripe_0_4, stripe_0_5, stripe_0_6, stripe_0_7, stripe_0_8, stripe_0_9, stripe_0_10, stripe_0_11, stripe_0_12, stripe_0_13, stripe_0_14, stripe_1_0, stripe_1_1, stripe_1_2, stripe_1_3, stripe_1_4, stripe_1_5, stripe_1_6, stripe_1_7, stripe_1_8, stripe_1_9, stripe_1_10, stripe_1_11, stripe_1_12, stripe_1_13, stripe_1_14, title, boss
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 boss_name (sample "BIG JELLY") in "%1"
      plays once, then emits finished
  res://zen/zs_room_cleared.tscn
      elements: band, door, title, sub
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 wave (sample "5") in "WAVE %1 COMPLETED WITH %2 ROOMS LEFT"
        %2 rooms_left (sample "3") in "WAVE %1 COMPLETED WITH %2 ROOMS LEFT"
      plays once, then emits finished; 1 pause marker(s): holds there until resume() or a click
  res://zen/zs_game_over.tscn
      elements: veil, splat, drip_0, drip_1, drip_2, skull, title, sub
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 wave (sample "7") in "WAVE %1   SCORE %2"
        %2 score (sample "1250") in "WAVE %1   SCORE %2"
      plays once, then emits finished; 1 pause marker(s): holds there until resume() or a click
  res://zen/zs_victory.tscn
      elements: veil, crosshair, spark_0, spark_1, spark_2, spark_3, spark_4, spark_5, title, sub
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 rooms (sample "6") in "%1 ROOMS CLEARED   SCORE %2"
        %2 score (sample "4820") in "%1 ROOMS CLEARED   SCORE %2"
      plays once, then emits finished; 1 pause marker(s): holds there until resume() or a click
  res://zen/zs_weapon_katana.tscn
      elements: card, icon, slash, weapon, desc
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 weapon_name (sample "KATANA") in "%1"
        %2 description (sample "FAST SLASHES, CLOSE RANGE") in "%2"
      plays once, then emits finished
  res://zen/zs_weapon_pistol.tscn
      elements: card, icon, flash, weapon, desc
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 weapon_name (sample "PISTOL") in "%1"
        %2 description (sample "RELIABLE, QUICK TO AIM") in "%2"
      plays once, then emits finished
  res://zen/zs_weapon_shotgun.tscn
      elements: card, icon, weapon, desc
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 weapon_name (sample "SHOTGUN") in "%1"
        %2 description (sample "WIDE SPREAD, LOW DAMAGE") in "%2"
      plays once, then emits finished
  res://zen/zs_weapon_rifle.tscn
      elements: card, icon, flash, weapon, desc
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 weapon_name (sample "ASSAULT RIFLE") in "%1"
        %2 description (sample "FULL AUTO, HIGH FIRE RATE") in "%2"
      plays once, then emits finished
  res://zen/zs_slot_jackpot.tscn
      elements: cabinet, marquee, window_0, reel_0_skull, reel_0_meat, reel_0_coin, reel_0_slime_ball, window_1, reel_1_skull, reel_1_meat, reel_1_coin, reel_1_slime_ball, window_2, reel_2_skull, reel_2_meat, reel_2_coin, reel_2_slime_ball, flash, burst_0, burst_1, burst_2, burst_3, burst_4, burst_5, burst_6, burst_7, title, sub
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 weapon_name (sample "SHOTGUN") in "%1 DROPPED"
      plays once, then emits finished
  res://zen/zs_slot_meat.tscn
      elements: cabinet, marquee, window_0, reel_0_skull, reel_0_meat, reel_0_coin, reel_0_slime_ball, window_1, reel_1_skull, reel_1_meat, reel_1_coin, reel_1_slime_ball, window_2, reel_2_skull, reel_2_meat, reel_2_coin, reel_2_slime_ball, meat_out_0, meat_out_1, meat_out_2, meat_out_3, title
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 amount (sample "3") in "+%1 MEAT"
      plays once, then emits finished
  res://zen/zs_slot_coins.tscn
      elements: cabinet, marquee, window_0, reel_0_skull, reel_0_meat, reel_0_coin, reel_0_slime_ball, window_1, reel_1_skull, reel_1_meat, reel_1_coin, reel_1_slime_ball, window_2, reel_2_skull, reel_2_meat, reel_2_coin, reel_2_slime_ball, coin_out_0, coin_out_1, coin_out_2, coin_out_3, coin_out_4, coin_out_5, title
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 amount (sample "5") in "+%1 COINS"
      plays once, then emits finished
  res://zen/zs_slot_bust.tscn
      elements: cabinet, marquee, window_0, reel_0_skull, reel_0_meat, reel_0_coin, reel_0_slime_ball, window_1, reel_1_skull, reel_1_meat, reel_1_coin, reel_1_slime_ball, window_2, reel_2_skull, reel_2_meat, reel_2_coin, reel_2_slime_ball, title, sub
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 cost (sample "1") in "-%1 COIN"
      plays once, then emits finished
  res://zen/zs_meat_grinder.tscn
      elements: card, grinder, meat_in_0, meat_in_1, meat_in_2, heart, title, sub
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 meat (sample "3") in "%1 MEAT GROUND UP"
        %2 health (sample "1") in "+%2 HEALTH"
      plays once, then emits finished
  res://zen/zs_weapon_upgrade.tscn
      elements: card, flask, slime_ball_in_0, slime_ball_in_1, spark_0, spark_1, spark_2, spark_3, spark_4, title, sub
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 weapon_name (sample "PISTOL") in "%1 LV %2"
        %2 level (sample "2") in "%1 LV %2"
        %3 damage (sample "1.2") in "DAMAGE x%3   FIRE RATE x%4"
        %4 fire_rate (sample "1.1") in "DAMAGE x%3   FIRE RATE x%4"
      plays once, then emits finished
  res://zen/zs_workbench_unlocked.tscn
      elements: card, flask, bubble_0, bubble_1, bubble_2, title, sub
      text args (play_with([...]) / set_text_args([...]) fill them in order):
        %1 weapon_name (sample "PISTOL") in "UPGRADE YOUR %1 WITH SLIME"
      plays once, then emits finished

1. MOVE IT INTO YOUR GAME
   It was exported straight into /home/qvin/Work/gamedev/variant-ZombieShooter - nothing to copy.
   To use it in another game, copy the "zen" folder to that project's root.
   Keep the folder name and everything inside it: every file names the others
   by its full res://zen/... path, so a renamed or moved folder breaks them.
   (To use another folder, re-export with that subfolder name instead.)

2. CHECK IT
   Open the game in Godot and let it import the new files. Open a scene above
   and press F6: it fills the window, and a click (or ui_accept) continues past
   a pause marker.

3. USE IT
   a) As is - instance it anywhere, it plays on its own:
        var anim = preload("res://zen/zs_wave_start.tscn").instantiate()
        add_child(anim)
      It is a Node2D the size of its design canvas: position and scale it like
      any other. (It only stretches to the window when it is the running scene.)
   b) Driven by game code - Scene > New Inherited Scene, pick the .tscn, attach
      a script to its root and save the new scene OUTSIDE res://zen/:

        extends "res://zen/zen_runtime/runtime/zen_canvas.gd"

        func _ready() -> void:
            super()                   # required: the animation starts in here
            finished.connect(queue_free)

      play(from_start := true)   start (again), or carry on with play(false)
      stop()                     freeze where it is
      restart()                  play from the start
      resume()                   continue past a held pause marker
      fire("name", {})           run an authored signal (list above);
                                 {"args": [...]} also sets the text args
      play_with([a, b])          fill %1, %2 ... in the texts, then play
      set_text_args([a, b])      fill them without (re)starting
      release_signal()           let go of a follow / a held end pose
      pointer(kind, frac)        feed the pointer yourself ("move" / "press" /
                                 "release", canvas fractions) with pointer_input off
      signal_names()             the authored signals
      signal finished            a one-shot ran out / a terminal signal ended
      signal paused(index)       it is holding at a pause marker
      $element_name              each element is a child node, by name
      To start it stopped, untick live_playback in the inherited scene and
      call play() when it should run.

4. UPDATE IT
   Re-export with the same subfolder and copy the folder over again - delete
   the old one first, so files the new export no longer needs go away.
   Do not edit files in res://zen/: an update replaces them. Your inherited
   scenes and scripts live outside it and keep working.
