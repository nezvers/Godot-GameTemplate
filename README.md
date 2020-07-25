
# Godot-GameTemplate
**Game Template** is all necessary stuff taken care for Godot users not to worry about creating most boring and tedious work.  
Main branch will be compatible with pixel art games, since those games require some more work to get everything right.  
I'd be happy for any contribution to make this template as good as it can be and it is open for branching out Hi-Res game branch.  

*Read this in other languages: [Español](README_es.md)

## How to use
With time it has become to be just drop in the project and should work with quick setup.
* Drop GameTemplate in Addons folder in your projects Addons folder;
* Enable GameTemplate plugin in Project Settings. It will set up all necessary autoloads automatically;
* Add your main menu scene to Addons/GameTemplate/Autoloads/Game/Game.tscn exported variable. It is used by PauseLayer to trigger right scene to switch;
* Edit Settings.gd (inside Autoload directory) Actions array of input map names. They are the ones included in button remapping.
* To change scenes trigger signal:
```
Game.emit_signal('change_scene', scene_file_location_string)
```
* Check other signals in Game singleton


### Template has Autoload scripts and scenes that's managing:  
* Scene transitioning - during that background loading is taking care of the next scene loading for smooth experience.  
* Hud - reserved for game specific overlay (HP, Points, etc.)  
* PauseLayer - Is a menu that appears while in game and pauses the game, allowing to (Resume, Options, Main Menu, Exit).  
* MainOptions - GUI for changing resolution (Fullscreen, Borderless, scaling), Audio faders (Master, Music, SFX) and Controls section for Action bindings.    
* FadeLayer - As a template it's just Fade-to-Black ColorRect but it's easy to add fading shader to it.  
* Music - Persistent AudioStreamPlayer for music
* HTMLfocus - if game is HTML5 it will overlay a button on screen, requesting player to click on it and allowing the game to become in focus.  

## Options menu  
Every settings option gets saved uppon exiting Options menu.  
![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/Options.png?raw=true)

## Languages menu  
At the moment simplified interaction.
Russian is translated but excluded in options because font doesn't support Cyrillic letters (If you know good pixel art font with Cyrillic supporl, please let me know).  
![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/Languages.PNG?raw=true)

## Key action binding menu  
Godot editor InputMap influenced rebinding, but with auto-detect function.  
Buttons gets saved uppon exiting Options menu.  
![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/Controls.PNG?raw=true)

## To-Do
* Add pixel-art compliant slider in Action rebinding list
* Use themes instead of CustomStyle (maybe)
* Maybe some documentation
