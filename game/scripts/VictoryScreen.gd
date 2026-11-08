## Victory screen: plays the zen victory animation first, then shows the menu.
##
## Host or solo: Return to Home Base (the default), Play Again, Upgrades, Main
## Menu. Online, guests go wherever the host goes next (NetPlayers), so:
##   - Upgrades is hidden (guests would be pulled into a menu screen);
##   - Main Menu ends the co-op session: with guests connected it asks first;
##   - a party list shows who is still with us and who went home as a ghost
##     (their rejoin portal opens once we're back in our home base).
## A co-op guest gets the GuestLeaveMenu instead: stay with the host, or go to
## its own home base (optionally leaving its ghost).
class_name VictoryScreen
extends Node

@export var overlay_scene: PackedScene
## Hidden while the animation plays.
@export var menu: Control
@export var room_state_resource: RoomStateResource
@export var score_resource: ScoreResource
## Reaching a boss room's victory exit unlocks New Game+.
@export var campaign_resource: CampaignResource

## Weapons of a won run go home (game over loses them).
const HOME_BASE: HomeBaseResource = preload("res://game/resources/home_base_resource.tres")
const WEAPON_INVENTORY: ItemCollectionResource = preload("res://addons/top_down/resources/ItemCollectionResource/weapon_inventory.tres")

## Main Menu's ChangeSceneButton: online with guests, its press asks first.
@export var main_menu_component: ChangeSceneButton
## Hidden while online.
@export var upgrades_entry: Control
@export var home_button: Button

## Shown to a co-op guest instead of the menu (GuestLeaveMenu).
var guest_menu: GuestLeaveMenu
## Host: the teammates and where they are (built in code).
var party_list: VBoxContainer
## Host: the "this ends the session" question, while it is up.
var confirm: ConfirmPrompt
const PARTY_FONT_SIZE: int = 8

func _ready() -> void:
	# ghosts who left mid-run get their carried weapons before the run closes
	Net.players.send_ghost_rewards()
	var _guest: bool = Net.is_guest()
	RunSession.end_run()
	if campaign_resource != null:
		campaign_resource.unlock_ng_plus()
	_stash_weapons()
	if overlay_scene == null:
		if _guest && Net.is_guest():
			menu.visible = false
			guest_menu = GuestLeaveMenu.open(self, GuestLeaveMenu.Context.VICTORY)
		else:
			# after the siblings' _ready (UpgradesEntry shows its button there)
			_show_menu.call_deferred()
		return
	menu.visible = false
	var _layer: CanvasLayer = CanvasLayer.new()
	add_child(_layer)
	var _anim: Node2D = overlay_scene.instantiate()
	_anim.pointer_input = false
	_anim.set_text_args([
		room_state_resource.cleared_section_count() if room_state_resource != null else 0,
		score_resource.value if score_resource != null else 0,
	])
	var _width: float = get_viewport().get_visible_rect().size.x
	_anim.position.x = roundf((_width - _anim.design_size.x) * 0.5)
	_layer.add_child(_anim)
	await _anim.finished
	_layer.queue_free()
	if _guest && Net.is_guest():
		# a guest doesn't pick the next room: follow the host or go home
		guest_menu = GuestLeaveMenu.open(self, GuestLeaveMenu.Context.VICTORY)
		return
	_show_menu()

func _show_menu() -> void:
	menu.visible = true
	if upgrades_entry != null && Net.is_online():
		upgrades_entry.visible = false
	if main_menu_component != null && main_menu_component.button.pressed.is_connected(main_menu_component.pressed):
		main_menu_component.button.pressed.disconnect(main_menu_component.pressed)
		main_menu_component.button.pressed.connect(_on_main_menu)
	if Net.is_host():
		_build_party_list()
	var _button: Button = home_button if home_button != null else menu.find_child("Button") as Button
	if _button != null:
		_button.grab_focus()

## Teammates in the session (ghosts too: they're coming back), not the hidden
## dedicated-server player.
static func teammates() -> Array[PlayerState]:
	var _list: Array[PlayerState] = []
	for _state: PlayerState in RunSession.players.all():
		if !_state.is_local && !_state.hidden:
			_list.append(_state)
	return _list

## Main Menu: alone it just goes; with guests it ends their session, so ask.
func _on_main_menu() -> void:
	var _count: int = teammates().size() if Net.is_host() else 0
	if _count == 0:
		_go_main_menu()
		return
	if confirm != null && is_instance_valid(confirm):
		return
	var _who: String = "1 other player" if _count == 1 else "%d other players" % _count
	confirm = ConfirmPrompt.open(self, "Going to the main menu ends the co-op session for %s." % _who, "Leave", "Stay")
	confirm.confirmed.connect(_go_main_menu)
	confirm.tree_exiting.connect(func () -> void:
		if is_inside_tree() && main_menu_component != null:
			main_menu_component.button.grab_focus()
	)

func _go_main_menu() -> void:
	if main_menu_component.button.pressed.is_connected(_on_main_menu):
		main_menu_component.button.pressed.disconnect(_on_main_menu)
	Transition.change_scene(main_menu_component.scene_path)

func _build_party_list() -> void:
	if party_list != null:
		return
	var _layer: CanvasLayer = CanvasLayer.new()
	_layer.layer = 2
	add_child(_layer)
	party_list = VBoxContainer.new()
	party_list.name = "PartyList"
	party_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_list.add_theme_constant_override(&"separation", 1)
	party_list.position = Vector2(8, 6)
	_layer.add_child(party_list)
	Net.roster_changed.connect(_refresh_party)
	Net.state_changed.connect(_refresh_party)
	tree_exiting.connect(func () -> void:
		if Net.roster_changed.is_connected(_refresh_party):
			Net.roster_changed.disconnect(_refresh_party)
		if Net.state_changed.is_connected(_refresh_party):
			Net.state_changed.disconnect(_refresh_party)
	)
	_refresh_party()

## One line per teammate: with us, or gone home as a ghost.
static func party_line(state: PlayerState) -> String:
	return "%s - %s" % [state.display_name, "gone home, will return" if state.ghost else "with you"]

func _refresh_party() -> void:
	if party_list == null || !is_instance_valid(party_list):
		return
	for _child: Node in party_list.get_children():
		_child.queue_free()
	var _list: Array[PlayerState] = teammates() if Net.is_host() else []
	party_list.visible = !_list.is_empty()
	if _list.is_empty():
		return
	party_list.add_child(_party_label("Party", Color(1, 0.92, 0.5)))
	for _state: PlayerState in _list:
		var _color: Color = PartyPanel.SLOT_COLORS[_state.slot % PartyPanel.SLOT_COLORS.size()]
		if _state.ghost:
			_color.a = 0.6
		party_list.add_child(_party_label(party_line(_state), _color))

func _party_label(text: String, color: Color) -> Label:
	var _label: Label = Label.new()
	_label.text = text
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", PARTY_FONT_SIZE)
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)
	return _label

## The next home base visit hands them to the player.
func _stash_weapons() -> void:
	# a ghost-tier co-op guest keeps nothing (GuestTier)
	if !GuestTier.keeps_loot():
		return
	var inventory: ItemCollectionResource = WEAPON_INVENTORY
	if inventory.list.is_empty():
		return
	HOME_BASE.stash_weapons(inventory)
