
# Godot-GameTemplate
**Game Template**  Se ocupa de todas las cosas necesarias para que los usuarios de Godot no se tengan que preocupar haciendo la parte mas aburrida y tediosa del trabajo.
La rama principal será compatible con los juegos en pixel art, ya que estos juegos requieren algo mas de trabajo para que todo funcione de manera correcta.
Me encantaría cualquier contribución para que esta plantilla sea tan buena como pueda ser y esta abierta para las ramas de Juegos Hi-Res.  

![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/MainSceneTree.PNG?raw=true)

La escena principal de la plantilla maneja:

&nbsp;&nbsp;&nbsp;&nbsp;Scene transitioning - Durante la cargar en segundo plano se ocupa de la carga de la 
siguiente escena para una experiencia mas fluida.
&nbsp;&nbsp;&nbsp;&nbsp;HUDLayer - Reservada para camas especificas del juego (Salud, Puntaje, etc.)
&nbsp;&nbsp;&nbsp;&nbsp;PauseLayer - Es un menú que aparece mientras el esta en pausa y pausa el juego, 
permitiendo (Reanudar, Opciones, Menú principal, Salir).
&nbsp;&nbsp;&nbsp;&nbsp;MainOptions - Interfaz para cambiar la resolución (Pantalla completa, sin bordes, escalado), 
Audio (Principal, Música, Efectos de sonido) y Sección de botones para configurar las acciones   
&nbsp;&nbsp;&nbsp;&nbsp;FadeLayer - Como plantilla es solo un Rectángulo de color para oscurecer pero es fácil añadirle 
fadings shader.
&nbsp;&nbsp;&nbsp;&nbsp;Music - Controles para música.  
&nbsp;&nbsp;&nbsp;&nbsp;Sounds - Controles para sonidos (iniciado en la interfaz)
&nbsp;&nbsp;&nbsp;&nbsp;HTMLfocus - Sí es un juego que corre bajo HTML5 colocara un botón sobre la capa de la pantalla, 
pidiendo al jugador que haga click sobre el, permitiendo al juego activarse

## Options menu  
Cada opción es guardada aun que se salga del menú  
![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/Options.png?raw=true)

## Languages menu  
Hasta el momento simplifica la interacción, Se necesita ayuda con el Francés Español (hasta el momento es solo el traductor de google.)
Esta traducido en ruso pero es excluido en las opciones por que la fuente de las letras no soporta el alfabeto cirílico 
(Si sabes de alguna buena fuente de letras que soporte el alfabeto cirílico, por favor házmelo saber).  

![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/Languages.PNG?raw=true)

## Key action binding menu  
Con las características nativas del Motor para mapeo de entrada pero con función de auto detector.  
La configuración es guardada aun que se salga del menú   

![](https://github.com/nezvers/Godot-GameTemplate/blob/master/Img/Controls.PNG?raw=true)

## Pendientes
* Agregar control deslizante compatible con pixel art en la lista de Re-enlazado de acciones
* Navegación en la lista de acciones usando ui_directions (el ruler no responde)
* Usar temas en vez de CustomStyles (Quizá)
* Alguna documentación
