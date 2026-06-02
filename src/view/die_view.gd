class_name DieView
extends Node3D
## A 3D six-sided die with pips. The value is decided elsewhere ([DiceRoller]); this view only
## shows it, orienting the matching face up. Opposite faces sum to 7. Pure rendering.

const SIZE := 0.8
const HALF := SIZE * 0.5
const PIP_RADIUS := 0.075
const PIP_OFFSET := 0.2  # distance of corner pips from the face center

# Which face (cube axis) carries each value. Opposite faces sum to 7.
# 1:+Y  6:-Y   2:+X  5:-X   3:+Z  4:-Z
const _FACES := [
	{"value": 1, "n": Vector3.UP, "u": Vector3.RIGHT, "w": Vector3.BACK},
	{"value": 6, "n": Vector3.DOWN, "u": Vector3.RIGHT, "w": Vector3.BACK},
	{"value": 2, "n": Vector3.RIGHT, "u": Vector3.BACK, "w": Vector3.UP},
	{"value": 5, "n": Vector3.LEFT, "u": Vector3.BACK, "w": Vector3.UP},
	{"value": 3, "n": Vector3.BACK, "u": Vector3.RIGHT, "w": Vector3.UP},
	{"value": 4, "n": Vector3.FORWARD, "u": Vector3.RIGHT, "w": Vector3.UP},
]

# Pip layouts: grid offsets (in units of PIP_OFFSET) for each value.
const _PATTERNS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(-1, 1), Vector2(0, 0), Vector2(1, -1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1)],
}

# Euler degrees that bring each value's face to the top (+Y).
const _FACE_UP_ROTATION := {
	1: Vector3(0, 0, 0),
	6: Vector3(180, 0, 0),
	2: Vector3(0, 0, 90),
	5: Vector3(0, 0, -90),
	3: Vector3(-90, 0, 0),
	4: Vector3(90, 0, 0),
}


func _ready() -> void:
	_build_body()
	for face in _FACES:
		_build_pips(face)


## Snaps the die so [param value] shows on top.
func show_value(value: int) -> void:
	rotation_degrees = _FACE_UP_ROTATION[value]


## Tumbles the die, then settles with [param value] on top.
func roll_to(value: int) -> void:
	var tween := create_tween()
	tween.tween_property(self, "rotation_degrees", _random_tumble(), 0.18)
	tween.tween_property(self, "rotation_degrees", _random_tumble(), 0.18)
	tween.tween_property(self, "rotation_degrees", _FACE_UP_ROTATION[value], 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _random_tumble() -> Vector3:
	return Vector3(randf_range(180, 540), randf_range(180, 540), randf_range(180, 540))


func _build_body() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SIZE, SIZE, SIZE)
	body.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f3f1ea")
	body.material_override = material
	add_child(body)


func _build_pips(face: Dictionary) -> void:
	var normal: Vector3 = face["n"]
	var u: Vector3 = face["u"]
	var w: Vector3 = face["w"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("23262b")
	for offset in _PATTERNS[face["value"]]:
		var pip := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = PIP_RADIUS
		sphere.height = PIP_RADIUS * 2.0
		pip.mesh = sphere
		pip.material_override = material
		pip.position = normal * HALF \
			+ u * (offset.x * PIP_OFFSET) + w * (offset.y * PIP_OFFSET)
		add_child(pip)
