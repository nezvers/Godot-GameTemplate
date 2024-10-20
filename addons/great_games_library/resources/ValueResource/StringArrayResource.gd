class_name StringArrayResource
extends ValueResource

@export var value:Array[String]

func set_value(_value:Array[String])->void:
	value = _value
	updated.emit()

func append(item:String)->void:
	value.append(item)
	updated.emit()

func set_item(i:int, item:String)->void:
	value[i] = item
	updated.emit()

func size()->int:
	return value.size()
