
# Godot-GameTemplate
**Game Template** is all necessary stuff taken care for Godot users not to worry about creating most boring and tedious work.  
Main branch will be compatible with pixel art games, since those games require some more work to get everything right.  
I'd be happy for any contribution to make this template as good as it can be and it is open for branching out Hi-Res game branch.  

*Read this in other languages: [Español](README_es.md)

## Features
* Modular and clean code base.
* Quick to setup (Plugin format - enabling plugin adds all singletons).
* Easy to expand Save/Load system. (Comes with Resource saving as default but there's an option to switch to JSON).
* Comes with custom ResourceAsyncLoader class (used in scene changing. Has fallbacks to regular loading for platforms that don't support async loading).
* Localization system - community helped (EN, DE, ES, FR, IT, pt_BR, RU, sv_SE, TR. RU is not active due to font limitation).
* Sound effects manager system - (manages SFX sample playing to not trigger multiple same samples together)
* Controls rebinding system.
* Resolution changing system.
* Audio volume system.
* Easy to change scene transition (comes with fade to black).
* Menus can navigate without mouse.
* Convinient singleton HtmlFocus, that asks to click on it if you have HTML5 game to gain game window focus (automatically free itself if not html5).
* Comes with custom style (saved - planned to turn into theme).
* HUD singleton (ready to be used in your way).
* Music singleton for persistent music after restarting or changing scenes


## How to use
* Drop GameTemplate from Addons folder in your projects Addons folder;
* Enable GameTemplate plugin in Project Settings. It will set up all necessary autoloads automatically;
* Set projects audio bus layer - res://Addons/GameTemplate/Assets/Audio_bus_layout.tres. Plugin can't do that automatically yet.
* Add your main menu scene to Addons/GameTemplate/Autoloads/PauseMenu.scn script variable 'MainMenu'. It is used by PauseLayer to switch scene to main menu or similar;
* Edit SettingsControls.gd (inside Autoload directory) Actions array of input map names. They are the ones uned in button remapping.
* To change scenes trigger signal:  ``` Game.emit_signal('change_scene', scene_file_location_string)```
* To use SfxManager give Array of samples to load: ```SfxManager.load_samples( ["res://...."] ) ``` and trigger samples with: ```SfxManager.play("file_name_without_extension")```
* To enable/disable HUD your levels set: ```Hud.visible = true ```
* To enable/disable pause menu levels set: ```PauseMenu.can_show = true ```
* Check convinient signals in Game singleton (New Game, Continue, Resume, Restart, ChangeScene, Exit)

## Walkthrough video
<div align="left">
      <a href="https://youtu.be/oi_V9w3DayA">
     <img 
      src="https://img.youtube.com/vi/oi_V9w3DayA/0.jpg" 
      alt="State machine walkthrough" 
      style="width:100%;">
      </a>
    </div>


### Singletone roles:  
* Game - convinient game signals, scene changing, scene restarting, game exit.
* ScreenFade - scene transitioning layer. As a template it's just Fade-to-Black ColorRect but it's easy to add fading shader to it.
* PauseMenu - Is a menu that appears while in game and pauses the game, allowing to (Resume, Options, Main Menu, Exit).
* Options - GUI for changing resolution (Fullscreen, Borderless, scaling), Audio faders (Master, Music, SFX) and Controls section for Action bindings.
* Settings - delegates order of other Settings singletons _ready.
* SettingsSaveLoad - Manages save/load settings. Easily expandable for other parameters and comes with 2x versions Resource and JSON saving.
* SettingsResolutions - handles the resolution changes.
* SettingsControls - handles the information for controls.
* SettingsLanguage - handles information for languages.
* MenuEvent - handles events between options menu GUI.
* Hud - reserved for game specific overlay (HP, Points, etc.).
* Music - Persistent AudioStreamPlayer for music.
* HTMLfocus - if game is HTML5 it will overlay a button on screen, requesting player to click on it and allowing the game to become in focus.  

## Options menu  
Every settings option gets saved uppon exiting Options menu.  
![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/Options.png?raw=true)

## Languages menu  
At the moment simplified interaction.
Russian is translated but excluded in options because font doesn't support Cyrillic letters (If you know good pixel art font with Cyrillic supporl, please let me know).  
![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/Languages.PNG?raw=true)

## Key action binding menu  
Godot editor InputMap influenced rebinding with auto-detect function.  
Buttons gets saved uppon exiting Options menu.  
![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/Controls.PNG?raw=true)

## To-Do
* Add pixel-art compliant slider in Action rebinding list
* Use themes instead of CustomStyle (maybe)
* Maybe some documentation
