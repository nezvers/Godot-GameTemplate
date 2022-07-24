# Godot Game Template

Forked from [Nezvers template](https://github.com/nezvers/Godot-GameTemplate)

Template made for [Godot Wild Jam](https://godotwildjam.com/)

## Features

- Modular and clean code base.
- Quick to setup (Plugin format - enabling plugin adds all singletons).
- Easy to expand Save/Load system. (Comes with Resource saving as default but there's an option to switch to JSON).
- Comes with custom ResourceAsyncLoader class (used in scene changing. Has fallbacks to regular loading for platforms that don't support async loading).
- Localization system
- Sound effects manager system - (manages SFX sample playing to not trigger multiple same samples together)
- Controls rebinding system.
- Resolution changing system.
- Audio volume system.
- Easy to change scene transition (comes with fade to black).
- Menus can navigate without mouse.
- Convinient singleton HtmlFocus, that asks to click on it if you have HTML5 game to gain game window focus (automatically free itself if not html5).
- Comes with custom style (saved - planned to turn into theme).
- HUD singleton (ready to be used in your way).
- Music singleton for persistent music after restarting or changing scenes
- CI/CD pipeline to build and deploy to [itch.io](http://itch.io). Courtesy of [Lucas](https://github.com/lucasblanco31)

## How to use

- Enable GameTemplate plugin in Project Settings. It will set up all necessary autoloads automatically;
- Edit SettingsControls.gd (inside Autoload directory) Actions array of input map names. They are the ones uned in button remapping.
- To change scenes trigger signal: ` Game.emit_signal('change_scene', scene_file_location_string)`
- All `wav` files in `addons/Assests/Sounds` folder are loaded to SfxManager singleton and may be triggered with: `SfxManager.play("file_name_without_extension")`
- To enable/disable HUD your levels set: `Hud.visible = true `
- To enable/disable pause menu levels set: `PauseMenu.can_show = true `
- Check convinient signals in Game singleton (New Game, Continue, Resume, Restart, ChangeScene, Exit)
- Localization is possible adding languages and strings to this [CSV file](https://github.com/agustinoli/Godot-GameTemplate)
- CI/CD pipeline runs on main branch and builds an export for each plataform (Windows, Mac, Linux and HTML5) and then deploys it to an already-made itch.io page. Only needs 3 secrets (ITCH_GAME, ITCH_USER and BUTLER_CREDENTIALS). You need to edit game page so html version is playable online.

### Singletone roles:

- Game - convinient game signals, scene changing, scene restarting, game exit.
- ScreenFade - scene transitioning layer. As a template it's just Fade-to-Black ColorRect but it's easy to add fading shader to it.
- PauseMenu - Is a menu that appears while in game and pauses the game, allowing to (Resume, Options, Main Menu, Exit).
- Options - GUI for changing resolution (Fullscreen, Borderless, scaling), Audio faders (Master, Music, SFX) and Controls section for Action bindings.
- Settings - delegates order of other Settings singletons \_ready.
- SettingsSaveLoad - Manages save/load settings. Easily expandable for other parameters and comes with 2x versions Resource and JSON saving.
- SettingsResolutions - handles the resolution changes.
- SettingsControls - handles the information for controls.
- SettingsLanguage - handles information for languages.
- MenuEvent - handles events between options menu GUI.
- Hud - reserved for game specific overlay (HP, Points, etc.).
- Music - Persistent AudioStreamPlayer for music.
- HTMLfocus - if game is HTML5 it will overlay a button on screen, requesting player to click on it and allowing the game to become in focus.
