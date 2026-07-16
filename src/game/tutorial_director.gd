class_name TutorialDirector
extends Node
## Sequences the first-time tutorial's beats: connects directly to the SAME GamePhase signals
## GameRoot itself reacts to, and shows a short bubble (via [TutorialOverlay]) each time the player
## reaches the next teachable moment (first roll, reservation, automatic pickup, the event card
## choice, the completed delivery's score). Reactive, not turn-locked: it adapts to whatever budget
## the dice actually give — [TutorialScenario]'s mini-board is short enough that any 2d6 roll makes
## real progress, across one turn or two — and it never blocks input. The player plays for real; the
## tutorial only narrates alongside, which is simpler and more robust than hard-locking every button
## down to the one expected action.

signal finished

var _overlay: TutorialOverlay
var _phase: GamePhase
var _reserved_seen := false


## Wires the director to [param phase] and starts narrating into [param overlay].
func start(phase: GamePhase, overlay: TutorialOverlay) -> void:
	_phase = phase
	_overlay = overlay
	_overlay.finished_pressed.connect(func() -> void: finished.emit())
	_phase.subphase_changed.connect(_on_subphase_changed)
	_phase.delivery_reserved.connect(_on_delivery_reserved)
	_phase.delivery_in_progress.connect(_on_delivery_in_progress)
	_phase.event_triggered.connect(_on_event_triggered)
	_phase.delivery_completed.connect(_on_delivery_completed)
	_overlay.say(tr("Bienvenue chez Shopopop Express ! Lance les dés pour commencer ta tournée."))


func _on_subphase_changed(subphase: int) -> void:
	if subphase != GamePhase.SubPhase.DEPLACEMENT or _phase.movement() == null:
		return
	if _phase.movement().path().size() > 1:
		return  # a fresh movement just began, not mid-walk
	if not _reserved_seen:
		_overlay.say(tr("Survole une case pour voir le chemin ; clique pour t'y rendre."))


func _on_delivery_reserved(_delivery: Delivery) -> void:
	if _reserved_seen:
		return
	_reserved_seen = true
	_overlay.say(tr("Livraison réservée ! File vers le point de retrait (case grise)."))


func _on_delivery_in_progress(_delivery: Delivery) -> void:
	_overlay.say(tr("Chargé automatiquement, sans un clic de plus ! Direction le client (case verte)."))


func _on_event_triggered(_cell: Vector2i) -> void:
	_overlay.say(tr("Case événement : pioche 2 cartes, garde la meilleure — l'autre repart dans le deck."))


func _on_delivery_completed(_delivery: Delivery, points: int) -> void:
	_overlay.say(
		tr("Livraison terminée : %d points (5 de base + tes deux tuiles) ! Le bouton « ? » en haut te rappelle tout ça.") % points)
	_overlay.show_finish_button()
