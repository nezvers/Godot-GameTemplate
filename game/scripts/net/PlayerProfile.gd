## Who this install is: a random id made on first boot (later the Steam id) and a
## display name. Run saves and co-op sessions match players by profile_id.
class_name PlayerProfile
extends SaveableResource

@export var profile_id:String
@export var display_name:String = "Player"

func _init()->void:
	resource_name = "Profile"

func ensure_id()->void:
	if !profile_id.is_empty():
		return
	profile_id = Crypto.new().generate_random_bytes(16).hex_encode()
	save_resource()

func prepare_save()->Resource:
	var _data:PlayerProfile = PlayerProfile.new()
	_data.profile_id = profile_id
	_data.display_name = display_name
	return _data

func prepare_load(data:Resource)->void:
	profile_id = data.profile_id
	display_name = data.display_name

func reset_resource()->void:
	profile_id = ""
	display_name = "Player"
