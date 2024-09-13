extends Node
class_name GameMath

## Project hit position for a moving target.
static func get_hit_position_2D(from_pos:Vector2, to_pos:Vector2, t_velocity:Vector2, projectile_speed:float)->Vector2:
	var q: = to_pos - from_pos
	q.y = 0.0
	t_velocity.y = 0.0
	
	var a:float = t_velocity.dot(t_velocity) - (projectile_speed * projectile_speed)
	var b:float = 2 * t_velocity.dot(q)
	var  c:float = q.dot(q) # Dot is basicly (q.x * q.x) + (q.y * q.y)
	var d = sqrt((b*b) - 4 * a * c)
	var t1:float = (-b + d) / (2 * a)
	var t2:float = (-b - d) / (2 * a)
	
	var time:float = max(t1, t2)
	var result:Vector2 = to_pos + time * t_velocity
	return result

static func dist_to_line_2d(pos:Vector2, line_start:Vector2, line_end:Vector2)->float:
	var ab: = line_end - line_start
	var ac: = pos - line_start
	if ac.dot(ab) <= 0.0:
		return ac.length()
	var bv: = pos - line_end
	if bv.dot(ab) >= 0.0:
		return bv.length()
	return ab.cross(ac) / ab.length()

static func dist_to_line_3d(pos:Vector3, line_start:Vector3, line_end:Vector3)->float:
	var ab: = line_end - line_start
	var ac: = pos - line_start
	if ac.dot(ab) <= 0.0:
		return ac.length()
	var bv: = pos - line_end
	if bv.dot(ab) >= 0.0:
		return bv.length()
	return ab.cross(ac).length() / ab.length()

static func get_closest_node_2d(point:Vector2, body_list:Array[Node2D])->Node2D:
	if body_list.is_empty():
		return null
	var closest:Node2D = body_list.front()
	var dist:float = (closest.global_position - point).length_squared()
	for body:Node2D in body_list:
		var _dist:float = (body.global_position - point).length_squared()
		if _dist < dist:
			dist = _dist
			closest = body
	return closest

## Outline of the formula
static func dampened_spring(displacement, damp, velocity, spring:float, delta:float):
	var force = -spring * displacement - damp * velocity
	velocity += force * delta
	displacement += velocity * delta
	return displacement

static func inverse_lerp(a:float, b:float, v:float)->float:
	return (v - a) / (b - a)

static func remap_lerp(imin:float, imax:float, omin:float, omax:float, v:float)->float:
	var t: = inverse_lerp(imin, imax, v)
	return lerp(omin, omax, t)

static func log_base(t:float, base:float)->float:
	return log(t) / log(base)

# convert values 0.0 to 1.0
static func convert_to_log(t:float, base:float)->float:
	return (pow(2.0, base * t) - 1.0) / (pow(2.0, base) - 1.0)

static func lerp_log(a:float, b:float, t:float, base:float)->float:
	return lerp(a, b, convert_to_log(t, base))

static func convert_from_log(t:float, base:float)->float:
	var v:float = t/1.0 * (pow(2, base) -1) + 1
	return log_base(v, 2) / base

static func packed_vector2_length(array:PackedVector2Array)->float:
	var point_count:int = array.size()
	if point_count < 2:
		return 0.0
	var total_length:float = 0.0
	for i in point_count -1:
		total_length += (array[i] - array[i+1]).length()
	return total_length

static func packed_float32_total(array:PackedFloat32Array)->float:
	var total:float = 0.0
	for value in array:
		total += value
	return total

## Get random values from a bell curve
static func random_standard_deviation(mean:float, deviation:float)->float:
	return deviation * -0.6266570687 * log((2147483647 * randf())) + mean;

static func approach(value:float, target:float, speed:float)->float:
	if value < target:
		return min(value + speed, target)
	else:
		return max(value - speed, target)

## Generic type
func hookes_law(displacement, current_velocity, stiffness, damping):
	return stiffness * displacement - damping * current_velocity

func hookes_law_v3f(displacement:Vector3, current_velocity:Vector3, stiffness:float, damping:float)->Vector3:
	return displacement * stiffness - damping * current_velocity
