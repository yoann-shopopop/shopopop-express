extends SceneTree
## Dev tool: builds resources/destinataires/*.tres from a built-in list of FICTIONAL characters
## (never real people: portraits and names of identifiable persons are a legal no-go).
## Run: godot --headless --path . -s res://tools/generate_destinataires.gd

const DIR := "res://resources/destinataires/"
# id, display_name, banner color, manie (one wry sentence of flavor)
const NAMES := [
	["mamie_turbo", "Mamie Turbo", "e84855", "Vous attend déjà sur le pas de la porte, chronomètre en main."],
	["jean_mi_carton", "Jean-Mi Carton", "d62246", "Garde tous les cartons « au cas où ». Le garage est plein depuis 2019."],
	["vero_locale", "Véro Locale", "43aa8b", "Vérifie l'origine de chaque légume avant de dire merci."],
	["capitaine_apero", "Capitaine Apéro", "f4c430", "Commande « pour quelques amis ». Ils sont quarante."],
	["tata_ginette", "Tata Ginette", "f3722c", "Vous raconte sa semaine avant de signer. Prévoir dix minutes."],
	["dj_frigo", "DJ Frigo", "4cc9f0", "Range ses courses par ordre alphabétique, devant vous."],
	["m_pantoufle", "M. Pantoufle", "577590", "N'ouvre la porte qu'à moitié. Le chat, lui, sort en entier."],
	["lea_du_5e", "Léa du 5ᵉ", "9b5de5", "Six étages, pas d'ascenseur. Prévoir des mollets."],
	["papi_brouette", "Papi Brouette", "90be6d", "Insiste pour porter les packs d'eau lui-même. Refusez poliment."],
	["mme_coupon", "Mme Coupon", "2d7dd2", "Connaît chaque promo du catalogue par cœur. Vous aussi, maintenant."],
	["famille_chut", "Famille Chut", "c77dff", "Sonnette interdite : le bébé dort. Toquer doux, très doux."],
	["coach_gilbert", "Coach Gilbert", "ff7043", "Vous félicite pour votre cardio et propose un abonnement."],
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var made := 0
	for row in NAMES:
		var d := DestinataireDefinition.new()
		d.id = StringName(row[0])
		d.display_name = row[1]
		d.color = Color(row[2])
		d.manie = row[3]
		if ResourceSaver.save(d, DIR + row[0] + ".tres") == OK:
			made += 1
	print("Generated %d destinataires." % made)
	quit()
