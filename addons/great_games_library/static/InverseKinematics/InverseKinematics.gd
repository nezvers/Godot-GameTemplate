class_name InverseKinematics
extends Node

## Forward And  Backwards Reach Inverse Kinematics
## Provide array with limb length and point array that holds position state (has to be one element bigger size)
static func fabrik_2d(length_list:PackedFloat32Array, point_list:PackedVector2Array, from:Vector2, to:Vector2, itterations:int = 10, error_margin:float = 0.1)->void:
	var joint_count: = length_list.size()
	
#	var total_length: = GameMath.packed_float32_total(length_list)
#	var target_distance: = to - from
#	var normal: = target_distance.normalized()
#	point_list[0] = from
	
	# position in a straight line
#	if target_distance.length() >= total_length:
#		for i in joint_count:
#			point_list[i+1] = point_list[i] + length_list[i] * normal
#		return point_list
	
	var last_i: = joint_count
	for it in itterations:
		# backward reach
		point_list[last_i] = to
		for i in joint_count:
			var p1: = point_list[last_i -i]
			var p2: = point_list[last_i -i -1]
			var dir: = (p2 - p1).normalized()
			point_list[last_i -i -1] = point_list[last_i -i] + dir * length_list[last_i -i -1]
		# forward reach
		point_list[0] = from
		for i in joint_count:
			var p1: = point_list[i]
			var p2: = point_list[i + 1]
			var dir: = (p2 - p1).normalized()
			point_list[i + 1] = point_list[i] + length_list[i] * dir
		
		# check error_margin
		var tip_distance:float = (to -point_list[last_i]).length()
		if tip_distance <= error_margin:
			break

## FABRIK with constrain (point joints to a direction)
## Provide array with limb length and point array that holds position state (has to be one element bigger size)
static func fabrik_2d_constrained(length_list:PackedFloat32Array, point_list:PackedVector2Array, constrain:Vector2, from:Vector2, to:Vector2, itterations:int = 10, error_margin:float = 0.1)->void:
	var joint_count: = length_list.size()
	
#	var total_length: = GameMath.packed_float32_total(length_list)
#	var target_distance: = to - from
#	point_list[0] = from
	
	# position in a straight line
#	if target_distance.length() >= total_length:
#		var normal: = target_distance.normalized()
#		for i in joint_count:
#			point_list[i+1] = point_list[i] + length_list[i] * normal
#		return point_list
	
	# Constrain direction
	var normal: = (constrain - from).normalized()
	for i in joint_count:
		point_list[i+1] = point_list[i] + length_list[i] * normal
	
	var last_i: = joint_count
	for it in itterations:
		# backward reach
		point_list[last_i] = to
		for i in joint_count:
			var p1: = point_list[last_i -i]
			var p2: = point_list[last_i -i -1]
			var dir: = (p2 - p1).normalized()
			point_list[last_i -i -1] = point_list[last_i -i] + dir * length_list[last_i -i -1]
		# forward reach
		point_list[0] = from
		for i in joint_count:
			var p1: = point_list[i]
			var p2: = point_list[i + 1]
			var dir: = (p2 - p1).normalized()
			point_list[i + 1] = point_list[i] + length_list[i] * dir
		
		# check error_margin
		var tip_distance:float = (to -point_list[last_i]).length()
		if tip_distance <= error_margin:
			break


## Forward And  Backwards Reach Inverse Kinematics
## Provide array with limb length and point array that holds position state (has to be one element bigger size)
static func fabrik_3d(length_list:PackedFloat32Array, point_list:PackedVector3Array, from:Vector3, to:Vector3, itterations:int = 10, error_margin:float = 0.1)->void:
	var joint_count: = length_list.size()
	
#	var total_length: = GameMath.packed_float32_total(length_list)
#	var target_distance: = to - from
#	var normal: = target_distance.normalized()
#	point_list[0] = from
	
	# position in a straight line
#	if target_distance.length() >= total_length:
#		for i in joint_count:
#			point_list[i+1] = point_list[i] + length_list[i] * normal
#		return point_list
	
	var last_i: = joint_count
	for it in itterations:
		# backward reach
		point_list[last_i] = to
		for i in joint_count:
			var p1: = point_list[last_i -i]
			var p2: = point_list[last_i -i -1]
			var dir: = (p2 - p1).normalized()
			point_list[last_i -i -1] = point_list[last_i -i] + dir * length_list[last_i -i -1]
		# forward reach
		point_list[0] = from
		for i in joint_count:
			var p1: = point_list[i]
			var p2: = point_list[i + 1]
			var dir: = (p2 - p1).normalized()
			point_list[i + 1] = point_list[i] + length_list[i] * dir
		
		# check error_margin
		var tip_distance:float = (to -point_list[last_i]).length()
		if tip_distance <= error_margin:
			break

## FABRIK with constrain (point joints to a direction)
## Provide array with limb length and point array that holds position state (has to be one element bigger size)
static func fabrik_3d_constrained(length_list:PackedFloat32Array, point_list:PackedVector3Array, constrain:Vector3, from:Vector3, to:Vector3, itterations:int = 10, error_margin:float = 0.1)->void:
	var joint_count: = length_list.size()
	
#	var total_length: = GameMath.packed_float32_total(length_list)
#	var target_distance: = to - from
#	point_list[0] = from
	
	# position in a straight line
#	if target_distance.length() >= total_length:
#		var normal: = target_distance.normalized()
#		for i in joint_count:
#			point_list[i+1] = point_list[i] + length_list[i] * normal
#		return point_list
	
	# Constrain direction
	var normal: = (constrain - from).normalized()
	for i in joint_count:
		point_list[i+1] = point_list[i] + length_list[i] * normal
	
	var last_i: = joint_count
	for it in itterations:
		# backward reach
		point_list[last_i] = to
		for i in joint_count:
			var p1: = point_list[last_i -i]
			var p2: = point_list[last_i -i -1]
			var dir: = (p2 - p1).normalized()
			point_list[last_i -i -1] = point_list[last_i -i] + dir * length_list[last_i -i -1]
		# forward reach
		point_list[0] = from
		for i in joint_count:
			var p1: = point_list[i]
			var p2: = point_list[i + 1]
			var dir: = (p2 - p1).normalized()
			point_list[i + 1] = point_list[i] + length_list[i] * dir
		
		# check error_margin
		var tip_distance:float = (to -point_list[last_i]).length()
		if tip_distance <= error_margin:
			break

## Rope like following/pulling
## Provide array with limb length and point array that holds position state (has to be one element bigger size)
static func rope_2d(length_list:PackedFloat32Array, point_list:PackedVector2Array, to:Vector2)->void:
	var joint_count: = length_list.size()
	
	point_list[0] = to
	for i in joint_count:
		var p1: = point_list[i]
		var p2: = point_list[i + 1]
		var dir: = (p2 - p1).normalized()
		point_list[i + 1] = point_list[i] + length_list[i] * dir


## Rope like following/pulling
## Provide array with limb length and point array that holds position state (has to be one element bigger size)
static func rope_3d(length_list:PackedFloat32Array, point_list:PackedVector3Array, to:Vector3)->void:
	var joint_count: = length_list.size()
	
	point_list[0] = to
	for i in joint_count:
		var p1: = point_list[i]
		var p2: = point_list[i + 1]
		var dir: = (p2 - p1).normalized()
		point_list[i + 1] = point_list[i] + length_list[i] * dir
