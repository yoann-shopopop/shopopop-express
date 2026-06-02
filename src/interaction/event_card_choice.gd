class_name EventCardChoice
extends Node3D
## A self-contained "draw 2, keep 1, activate" event-card interaction, shown on the board when a pawn
## lands on a rainbow cell. Two cards are dealt face up; click one to choose it (the other returns to
## the deck), then click the chosen card to activate it. Emits [signal resolved] with the kept card
## and the discarded ones, then frees itself. Reuses [CardView]; mirrors the card demo's flow.

## Emitted once the player has chosen and activated a card.
signal resolved(chosen: EventCardDefinition, discarded: Array)

enum _State { CHOOSING, ACTIVATING, DONE }

const _REVEAL: Array[Vector3] = [Vector3(-1.3, 0.0, 0.0), Vector3(1.3, 0.0, 0.0)]
const _ACTIVE := Vector3(0.0, 0.0, 1.8)
const _AWAY := Vector3(0.0, 0.0, -3.0)

var _camera: Camera3D
var _state: int = _State.DONE
var _entries: Array = []          # [{ "view": CardView, "card": EventCardDefinition }]
var _chosen: Dictionary = {}
var _discarded: Array = []


## Shows [param cards] (1 or 2) at [param anchor] world position, picked with [param camera].
func present(cards: Array, camera: Camera3D, anchor: Vector3) -> void:
	_camera = camera
	position = anchor
	# Scale is driven by the host (GameRoot pins/sizes the choice to the screen); default to 1 here.
	for i in cards.size():
		var view := CardView.new()
		add_child(view)
		view.bind(cards[i])
		view.set_face_up(false)
		view.position = Vector3.ZERO
		view.animate_deal(_REVEAL[i % _REVEAL.size()], i * 0.12)
		_entries.append({"view": view, "card": cards[i]})
	_state = _State.CHOOSING


func _unhandled_input(event: InputEvent) -> void:
	if _state == _State.DONE or _camera == null:
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if _state == _State.CHOOSING:
		var picked := _pick(_views())
		if picked != null:
			get_viewport().set_input_as_handled()
			_choose(picked)
	elif _state == _State.ACTIVATING:
		if _pick([_chosen["view"]]) != null:
			get_viewport().set_input_as_handled()
			_activate()


func _choose(picked: CardView) -> void:
	_discarded = []
	for entry in _entries:
		var view: CardView = entry["view"]
		if view == picked:
			_chosen = entry
			view.animate_move_to(_ACTIVE)
		else:
			_discarded.append(entry["card"])
			view.animate_discard(_AWAY)
	_state = _State.ACTIVATING


func _activate() -> void:
	_state = _State.DONE
	var view: CardView = _chosen["view"]
	await view.animate_activate()
	view.animate_discard(_AWAY)
	resolved.emit(_chosen["card"], _discarded)
	await get_tree().create_timer(0.4).timeout
	queue_free()


# Nearest card under the cursor within its PICK_RADIUS (camera ray vs card sphere), or null.
func _pick(views: Array) -> CardView:
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var dir := _camera.project_ray_normal(mouse)
	var nearest: CardView = null
	var nearest_along := INF
	for view in views:
		var to_center: Vector3 = view.global_position - origin
		var along := to_center.dot(dir)
		if along <= 0.0:
			continue
		var closest := origin + dir * along
		if closest.distance_to(view.global_position) <= CardView.PICK_RADIUS * scale.x and along < nearest_along:
			nearest_along = along
			nearest = view
	return nearest


func _views() -> Array:
	var result: Array = []
	for entry in _entries:
		result.append(entry["view"])
	return result
