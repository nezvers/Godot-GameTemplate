## Tree like double linked data representing relationship between spawned enemies
class_name ActiveEnemyResource
extends Resource

var parent:ActiveEnemyResource

var children:Array[ActiveEnemyResource]

var nodes:Array[ActiveEnemy]

var clear_callback:Callable
