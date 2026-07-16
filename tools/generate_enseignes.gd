extends SceneTree
## Dev tool: builds resources/enseignes/*.tres from a built-in list of FICTIONAL shops (no parody of
## real brands: a commercial, brand-backed product protects parody poorly). Logos come later — an
## optional assets/trades/<id>.webp is wired in when present.
## Run: godot --headless --path . -s res://tools/generate_enseignes.gd

const DIR := "res://resources/enseignes/"
const TRADES := "res://assets/trades/"
# id, display_name, tab color
const SHOPS := [
	["hyper_topinambour", "Hyper Topinambour", "e84855"],
	["au_ptit_marche", "Au P'tit Marché", "2d7dd2"],
	["visse_et_vrille", "Visse & Vrille", "f4c430"],
	["la_cave_qui_chante", "La Cave qui Chante", "9b5de5"],
	["fanfan_fleurs", "Fanfan Fleurs", "43aa8b"],
	["fournil_dhector", "Le Fournil d'Hector", "f3722c"],
	["croquettes_cie", "Croquettes & Cie", "577590"],
	["meubles_boulon", "Meubles Boulon", "d62246"],
	["sportif_du_dimanche", "Le Sportif du Dimanche", "90be6d"],
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var made := 0
	for row in SHOPS:
		var e := EnseigneDefinition.new()
		e.id = StringName(row[0])
		e.display_name = row[1]
		e.color = Color(row[2])
		var logo := TRADES + row[0] + ".webp"
		if ResourceLoader.exists(logo):
			e.texture = load(logo)
		if ResourceSaver.save(e, DIR + e.id + ".tres") == OK:
			made += 1
	print("Generated %d enseignes." % made)
	quit()
