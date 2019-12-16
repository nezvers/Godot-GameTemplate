
# Godot-GameTemplate
**Game Template** is all necessary stuff taken care for Godot users not to worry about creating most boring and tedious work.  
Main branch will be compatible with pixel art games, since those games require some more work to get everything right.  
I'd be happy for any contribution to make this template as good as it can be and it is open for branching out Hi-Res game branch.  

![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/MainSceneTree.PNG?raw=true)

Template has main scene that's managing:  
&nbsp;&nbsp;&nbsp;&nbsp;Scene transitioning - during that background loading is taking care of the next scene loading for smooth experience.  
&nbsp;&nbsp;&nbsp;&nbsp;MainOptions - GUI for changing resolution (Fullscreen, Borderless, scaling), Audio faders (Master, Music, SFX)  
&nbsp;&nbsp;&nbsp;&nbsp;FadeLayer - As template it's just Fade-to-Black ColorRect but it's simple to add fading shader to it.  
&nbsp;&nbsp;&nbsp;&nbsp;Music - Persistent AudioStreamPlayer for music  
&nbsp;&nbsp;&nbsp;&nbsp;HTMLfocus - if game is HTML it's overlaying button on screen requesting player to click on.  

## Options menu
![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/Options.png?raw=true)

## To-Do
* Button re-binding instead of action/ button list
* Configuration Save/Load
* Pause menu
* Probably something more
