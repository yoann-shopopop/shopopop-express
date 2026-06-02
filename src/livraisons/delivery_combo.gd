class_name DeliveryCombo
extends RefCounted
## A delivery: an enseigne (pickup) clipped with a destinataire (client), plus a status. Pure logic.

var enseigne: EnseigneDefinition
var destinataire: DestinataireDefinition
var status: int = DeliveryStatus.Kind.DISPONIBLE


func _init(p_enseigne: EnseigneDefinition, p_destinataire: DestinataireDefinition) -> void:
	enseigne = p_enseigne
	destinataire = p_destinataire


## Advances the status one step (DISPONIBLE→RESERVE→EN_COURS→LIVREE). False if already LIVREE.
func advance() -> bool:
	if status >= DeliveryStatus.Kind.LIVREE:
		return false
	status += 1
	return true


## Clips a new recipient and returns the combo to DISPONIBLE (used when recycling after delivery).
func reset(p_destinataire: DestinataireDefinition) -> void:
	destinataire = p_destinataire
	status = DeliveryStatus.Kind.DISPONIBLE


func is_available() -> bool:
	return status == DeliveryStatus.Kind.DISPONIBLE


func is_done() -> bool:
	return status == DeliveryStatus.Kind.LIVREE
