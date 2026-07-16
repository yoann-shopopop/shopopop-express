class_name DeliveryGenerator
extends RefCounted
## Generates deliveries by clipping each enseigne slot with a random destinataire (drawn without
## replacement). Advancing a combo cycles its status; completing it recycles the recipient — a new one
## is drawn from the remaining pool, or the slot is left empty when the pool is exhausted. Pure logic;
## the RNG is injectable for deterministic tests. Mirrors SetupDistributor's seeded Fisher-Yates draw.
##
## [param max_deliveries] caps the TOTAL deliveries a game can produce (initial + recycled): the pool
## keeps only that many identities after the shuffle. The rules set it to the number of placed tiles
## (« total tuiles = livraisons ») — pass a negative value to leave the pool uncapped (score modes).

signal combo_changed(index: int)
signal recycled(index: int)
signal exhausted

var _combos: Array[DeliveryCombo] = []
var _pool: Array[DestinataireDefinition] = []  # remaining recipients (draw pile)
var _rng: RandomNumberGenerator


func _init(
	enseignes: Array[EnseigneDefinition],
	destinataires: Array[DestinataireDefinition],
	slots: int,
	rng: RandomNumberGenerator = null,
	max_deliveries: int = -1,
) -> void:
	if rng != null:
		_rng = rng
	else:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	_pool = destinataires.duplicate()
	_shuffle(_pool)
	if max_deliveries >= 0 and _pool.size() > max_deliveries:
		_pool.resize(max_deliveries)
	# One combo per slot, capped by the recipient pool (no recipient, no delivery). Enseignes cycle
	# when there are more slots than brands, so two tiles can share a brand.
	var count := mini(slots, _pool.size())
	for i in count:
		var enseigne: EnseigneDefinition = enseignes[i % enseignes.size()] if not enseignes.is_empty() else null
		_combos.append(DeliveryCombo.new(enseigne, _draw()))


## The current combos (one per active slot).
func combos() -> Array[DeliveryCombo]:
	return _combos


## Recipients left in the draw pile.
func remaining_recipients() -> int:
	return _pool.size()


## Peeks the next [param n] recipients that would be drawn (by [method recycle] or a fresh clip),
## without consuming them — for a "next up" queue display (La Tournée). Draw order is LIFO
## (pop_back in [method _draw]), so this reads the pool from its tail backwards. Fewer than
## [param n] if the pool is nearly empty.
func peek_upcoming(n: int) -> Array[DestinataireDefinition]:
	var result: Array[DestinataireDefinition] = []
	var i := _pool.size() - 1
	while i >= 0 and result.size() < n:
		result.append(_pool[i])
		i -= 1
	return result


## Advances a combo's status up to EN_COURS (LIVREE is done via [method complete]).
func advance(index: int) -> bool:
	var combo := _combos[index]
	if combo.status >= DeliveryStatus.Kind.EN_COURS:
		return false
	combo.advance()
	combo_changed.emit(index)
	return true


## Completes an EN_COURS combo: removes its recipient and clips a new one (or leaves it empty).
func complete(index: int) -> bool:
	if _combos[index].status != DeliveryStatus.Kind.EN_COURS:
		return false
	recycle(index)
	return true


## Clips a new recipient onto combo [param index] (regardless of status), or leaves it empty when the
## pool is exhausted. Returns the new recipient (or null). Used by the board to recycle on delivery.
func recycle(index: int) -> DestinataireDefinition:
	var combo := _combos[index]
	combo.reset(_draw())  # new recipient (or null when the pool is exhausted) + back to DISPONIBLE
	recycled.emit(index)
	if combo.destinataire == null:
		exhausted.emit()
	return combo.destinataire


# Pops the top recipient from the (shuffled) pool, or null when empty.
func _draw() -> DestinataireDefinition:
	if _pool.is_empty():
		return null
	return _pool.pop_back()


func _shuffle(pile: Array[DestinataireDefinition]) -> void:
	for i in range(pile.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: DestinataireDefinition = pile[i]
		pile[i] = pile[j]
		pile[j] = tmp
