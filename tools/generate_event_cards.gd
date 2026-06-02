extends SceneTree
## Dev tool: generates the event card resources (resources/events/*.tres) from the Notion catalog.
## Run: godot --headless --path . -s res://tools/generate_event_cards.gd

const DIR := "res://resources/events/"


func _init() -> void:
	var E := EventCardDefinition.Effect
	var C := EventCardDefinition.Condition
	# id, display_name, effect, amount, condition, is_malus
	var catalog := [
		# Avantages
		["prime_gouvernementale", "Prime Gouvernementale", E.EXTRA_DIE, 0, C.VELO, false],
		["faille_spatio_temporelle", "Faille Spatio-Temporelle", E.TELEPORT_QUARTIER, 0, C.NONE, false],
		["tous_les_feux_au_vert", "Tous les Feux sont au Vert", E.REJOUER, 0, C.NONE, false],
		["escorte_policiere", "Escorte Policière", E.TELEPORT_DESTINATION, 0, C.NONE, false],
		["evaluation_positive", "Évaluation Positive", E.BONUS_CASES, 5, C.NONE, false],
		["grand_soleil", "Grand Soleil", E.BONUS_CASES, 3, C.NONE, false],
		["parrainage", "Parrainage", E.DOUBLE_DICE, 0, C.NONE, false],
		["raccourci_secret", "Raccourci Secret", E.TELEPORT_PARALLELE, 0, C.NONE, false],
		["cinq_sur_cinq", "5/5", E.BONUS_SCORE, 20, C.NONE, false],
		["livraison_ecologique", "Livraison Écologique", E.DOUBLE_SCORE_LIVRAISON, 0, C.VELO, false],
		["voie_verte_prioritaire", "Voie Verte Prioritaire", E.BONUS_CASES, 5, C.VELO, false],
		# Malus
		["feu_rouge", "Feu Rouge", E.FIN_TOUR, 0, C.NONE, true],
		["recharge_batterie", "Recharge de Batterie", E.MALUS_CASES, 3, C.NONE, true],
		["sac_oublie", "Sac Oublié", E.RETOUR_DRIVE, 0, C.NONE, true],
		["manifestation", "Manifestation en Cours", E.BUDGET_UN_DE, 0, C.NONE, true],
		["fuite_canalisation", "Fuite de Canalisation", E.ROUTE_BLOQUEE, 0, C.NONE, true],
		["pluies_torrentielles", "Pluies Torrentielles", E.PONTS_FERMES, 0, C.NONE, true],
		["pic_pollution", "Pic de Pollution", E.FIN_TOUR, 0, C.NONE, true],
		["sac_isotherme_oublie", "Sac Isotherme Oublié", E.RETOUR_DEPART, 0, C.NONE, true],
		["panne_vehicule", "Panne de Véhicule", E.FIN_TOUR, 0, C.NONE, true],
		["animal_sur_la_route", "Animal sur la Route", E.MALUS_CASES, 2, C.NONE, true],
		["prevention_hyperactivite", "Prévention de l'Hyperactivité", E.MALUS_CASES, 3, C.NONE, true],
	]

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var made := 0
	for row in catalog:
		var card := EventCardDefinition.new()
		card.id = StringName(row[0])
		card.display_name = row[1]
		card.effect = row[2]
		card.amount = row[3]
		card.condition = row[4]
		card.is_malus = row[5]
		var err := ResourceSaver.save(card, DIR + row[0] + ".tres")
		if err == OK:
			made += 1
		else:
			push_error("Failed to save %s (err %d)" % [row[0], err])
	print("Generated %d / %d event cards." % [made, catalog.size()])
	quit()
