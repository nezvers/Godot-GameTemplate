## Saved co-op preferences: the port to host on and recently joined addresses.
class_name NetSettings
extends SaveableResource

const MAX_RECENT:int = 5

@export var host_port:int = 24565
@export var recent_hosts:PackedStringArray
## Write a playtest log (PlaytestLog) every session.
@export var playtest_log:bool

func remember_host(address:String)->void:
	var _list:PackedStringArray = [address]
	for _old:String in recent_hosts:
		if _old != address && _list.size() < MAX_RECENT:
			_list.append(_old)
	recent_hosts = _list
	save_resource()

func prepare_save()->Resource:
	var _data:NetSettings = NetSettings.new()
	_data.host_port = host_port
	_data.recent_hosts = recent_hosts
	_data.playtest_log = playtest_log
	return _data

func prepare_load(data:Resource)->void:
	host_port = data.host_port
	recent_hosts = data.recent_hosts
	playtest_log = bool(data.get("playtest_log")) if "playtest_log" in data else false

func reset_resource()->void:
	host_port = 24565
	recent_hosts = PackedStringArray()
	playtest_log = false
