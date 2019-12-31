
# Godot-GameTemplate
**Game Template** is all necessary stuff taken care for Godot users not to worry about creating most boring and tedious work.  
Main branch will be compatible with pixel art games, since those games require some more work to get everything right.  
I'd be happy for any contribution to make this template as good as it can be and it is open for branching out Hi-Res game branch.  

![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/MainSceneTree.PNG?raw=true)

Template has main scene that's managing:  
&nbsp;&nbsp;&nbsp;&nbsp;Scene transitioning - during that background loading is taking care of the next scene loading for smooth experience.  
&nbsp;&nbsp;&nbsp;&nbsp;HUDLayer - reserved for game specific overlay (HP, Points, etc.)  
&nbsp;&nbsp;&nbsp;&nbsp;PauseLayer - Is a menu that appears while in game and pauses the game, allowing to (Resume, Options, Main Menu, Exit).  
&nbsp;&nbsp;&nbsp;&nbsp;MainOptions - GUI for changing resolution (Fullscreen, Borderless, scaling), Audio faders (Master, Music, SFX) and Controls section for Action bindings.    
&nbsp;&nbsp;&nbsp;&nbsp;FadeLayer - As template it's just Fade-to-Black ColorRect but it's easy to add fading shader to it.  
&nbsp;&nbsp;&nbsp;&nbsp;Music - Persistent AudioStreamPlayer for music  
&nbsp;&nbsp;&nbsp;&nbsp;Sounds - Persistent AudioStreamPlayer for Sounds (initially for GUI)  
&nbsp;&nbsp;&nbsp;&nbsp;HTMLfocus - if game is HTML5 it will overlay a button on screen, requesting player to click on it and allowing the game to become in focus.  

## Options menu
Every option get saved uppon exiting Options menu.  
![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/Options.png?raw=true)

## Key action binding menu
Godot editor InputMap influenced rebinding, but with auto-detect function.  
Buttons gets saved uppon exiting Options menu.  
![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/Controls.PNG?raw=true)

## To-Do
* Add pixel-art compliant slider in Action rebinding list
* GUI focusing using Keyboard and Gamepad
* Localization
* Use themes instead of CustomStyle (maybe)
