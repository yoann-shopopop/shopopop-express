class_name EventCardChoice
extends Node3D
## A self-contained "draw 2, keep 1, activate" event-card interaction, shown on the board when a pawn
## lands on a rainbow cell. Two cards are dealt face up; click one to choose it (the other returns to
## the deck), then click the chosen card to activate it. Emits [signal resolved] with the kept card
## and the discarded ones, then frees itself. Reuses [CardView]; mirrors the card demo's flow.

## Emitted once the player has chosen and activated a card.
signal resolved(chosen: EventCardDefinition, discarded: Array)

enum _State { CHOOSING, DONE }

const _REVEAL: Array[Vector3] = [Vector3(-1.18, 0.0, 0.0), Vector3(1.18, 0.0, 0.0)]
const _ACTIVE := Vector3(0.0, 0.0, 1.8)
const _AWAY := Vector3(0.0, 0.0, -3.0)

var _camera: Camera3D
var _state: int = _State.DONE
var _entries: Array = []          # [{ "view": CardView, "card": EventCardDefinition }]
var _discarded: Array = []

# World positions of the PIOCHE / DÉFAUSSE piles, so resolved cards visibly fly to them (set by the
# host each frame). reject_to_discard = Carnet d'Adresses (the rejected card is discarded, not top-decked).
var pioche_target: Vector3 = Vector3.ZERO
var defausse_target: Vector3 = Vector3.ZERO
var reject_to_discard: bool = false


## Shows [param cards] (1 or 2) at [param anchor] world position, picked with [param camera].
func present(cards: Array, camera: Camera3D, anchor: Vector3) -> void:
	_camera = camera
	position = anchor
	# Scale is driven by the host (GameRoot pins/sizes the choice to the screen); default to 1 here.
	for i in cards.size():
		var view := CardView.new()
		add_child(view)
		var card = cards[i]
		# Event cards wear the designed 2D face (rendered to a texture); other cards use their own art.
		if card is EventCardDefinition:
			view.bind(card, EventCardFace.build_texture(card, view))
		else:
			view.bind(card)
		view.set_face_up(false)
		view.position = Vector3.ZERO
		# A lone forced card is centered; two cards spread left/right for the keep-1 choice.
		var slot := Vector3.ZERO if cards.size() == 1 else _REVEAL[i % _REVEAL.size()]
		view.animate_deal(slot, i * 0.12)
		_entries.append({"view": view, "card": card})
	_state = _State.CHOOSING


func _unhandled_input(event: InputEvent) -> void:
	if _state != _State.CHOOSING or _camera == null:
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var picked := _pick(_views())
	if picked != null:
		get_viewport().set_input_as_handled()
		_keep(picked)


# A SINGLE click both keeps and plays the card: the kept one pops then flies to the DÉFAUSSE; the
# rejected one flies back ON TOP of the PIOCHE (or to the DÉFAUSSE for Carnet d'Adresses). Seeing each
# card travel to its pile makes the draw/discard legible.
func _keep(picked: CardView) -> void:
	_state = _State.DONE
	_discarded = []
	var chosen_card: EventCardDefinition = null
	for entry in _entries:
		var view: CardView = entry["view"]
		if view == picked:
			chosen_card = entry["card"]
		else:
			_discarded.append(entry["card"])
			view.animate_discard(_pile_local(defausse_target if reject_to_discard else pioche_target))
	picked.animate_move_to(_ACTIVE)
	await picked.animate_activate()
	picked.animate_discard(_pile_local(defausse_target))  # the played card goes to the discard
	resolved.emit(chosen_card, _discarded)
	await get_tree().create_timer(0.4).timeout
	queue_free()


# Converts a pile's WORLD target into this (scaled) node's local space for the card tween. Falls back
# to a neutral off-screen slide if the host hasn't provided pile targets.
func _pile_local(world_target: Vector3) -> Vector3:
	if world_target == Vector3.ZERO:
		return _AWAY
	return to_local(world_target)


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
