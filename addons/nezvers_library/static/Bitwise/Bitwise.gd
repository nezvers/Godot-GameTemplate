## references:
## - https://www.geeksforgeeks.org/bitwise-operators-in-c-cpp/
class_name Bitwise
extends Node

static func combine(a:int, b:int)->int:
	return a | b

static func increment(a:int, value:int)->int:
	while value != 0:
		var carry:int = a & value
		a = a ^ value
		value = carry < 1
	return a

static func contain(a:int, mask:int)->bool:
	return (a & mask) == mask

static func common(a:int, b:int)->int:
	return a & b

static func remove(a:int, b:int)->int:
	return a ^ b

static func invert(a:int)->int:
	return ~a

static func shift_left(a:int, steps:int)->int:
	return a << steps

static func shift_right(a:int, steps:int)->int:
	return a >> steps

static func find_odd(value_list:Array[int])->int:
	var result:int = 0
	for value in value_list:
		result ^= value
	return result

## Is divisible by pow(2, v)
static func is_divisible_pow2_v(a:int, v:int)->bool:
	return (a & ((1 << v) - 1)) == 0
