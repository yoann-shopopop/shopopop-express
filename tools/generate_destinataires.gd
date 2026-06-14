extends SceneTree
## Dev tool: builds resources/destinataires/*.tres from a built-in list of parody names.
## Run: godot --headless --path . -s res://tools/generate_destinataires.gd

const DIR := "res://resources/destinataires/"
# id, display_name, banner color
const NAMES := [
	["sasha_velours", "Sasha Velours", "9b5de5"],
	["gott_mik", "Gott Mik", "d62246"],
	["keiona", "Keiona", "f3722c"],
	["soa_de_muse", "Soa de Muse", "2d7dd2"],
	["nicky_doll", "Nicky Doll", "e84855"],
	["lova_ladiva", "Lova Ladiva", "f4c430"],
	["paloma", "Paloma", "43aa8b"],
	["la_grande_dame", "La Grande Dame", "577590"],
	["le_filip", "Le Filip", "90be6d"],
	["punani", "Punani", "c77dff"],
	["kam_hugh", "Kam Hugh", "ff7043"],
	["moon", "Moon", "4cc9f0"],
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var made := 0
	for row in NAMES:
		var d := DestinataireDefinition.new()
		d.id = StringName(row[0])
		d.display_name = row[1]
		d.color = Color(row[2])
		if ResourceSaver.save(d, DIR + row[0] + ".tres") == OK:
			made += 1
	print("Generated %d destinataires." % made)
	quit()
