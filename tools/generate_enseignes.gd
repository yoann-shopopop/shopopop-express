extends SceneTree
## Dev tool: builds resources/enseignes/*.tres from the brand images in assets/trades/.
## Run: godot --headless --path . -s res://tools/generate_enseignes.gd

const DIR := "res://resources/enseignes/"
const TRADES := "res://assets/trades/"
# A varied tab color per brand (cosmetic for now).
const COLORS := [
	Color("e84855"), Color("2d7dd2"), Color("f4c430"), Color("9b5de5"),
	Color("43aa8b"), Color("f3722c"), Color("577590"), Color("d62246"), Color("90be6d"),
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var dir := DirAccess.open(TRADES)
	var made := 0
	var i := 0
	for file in dir.get_files():
		if not file.ends_with(".webp"):
			continue
		var base := file.get_basename()  # e.g. CHUPER_U
		var e := EnseigneDefinition.new()
		e.id = StringName(base.to_lower())
		e.display_name = base.replace("_", " ").capitalize()
		e.texture = load(TRADES + file)
		e.color = COLORS[i % COLORS.size()]
		if ResourceSaver.save(e, DIR + e.id + ".tres") == OK:
			made += 1
		i += 1
	print("Generated %d enseignes." % made)
	quit()
