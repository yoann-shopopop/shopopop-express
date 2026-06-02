class_name Deck
extends RefCounted
## An endless draw/discard pile of [CardDefinition]s.
##
## Pure logic — no [Node], no rendering — so it stays unit-testable, like [Board]. When the draw
## pile runs out, the discard pile is reshuffled back into it. The "draw N, keep one, discard the
## rest" rule is orchestrated by the caller: it [method draw]s, keeps one, and [method discard]s the
## others. The shuffle uses an injectable [RandomNumberGenerator] so it can be made deterministic.

## Emitted after a successful [method draw], with the cards drawn.
signal drawn(cards: Array)
## Emitted whenever a card is sent to the discard pile.
signal discarded(card: CardDefinition)
## Emitted when the discard pile is reshuffled back into an empty draw pile.
signal reshuffled

var _draw_pile: Array[CardDefinition] = []
var _discard_pile: Array[CardDefinition] = []
var _rng: RandomNumberGenerator


## Builds a deck from [param cards]. Pass a seeded [param rng] for deterministic shuffles (tests);
## when omitted, a randomized generator is used.
func _init(cards: Array[CardDefinition], rng: RandomNumberGenerator = null) -> void:
	_draw_pile = cards.duplicate()
	if rng != null:
		_rng = rng
	else:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()


## Number of cards left to draw.
func draw_count() -> int:
	return _draw_pile.size()


## Number of cards in the discard pile.
func discard_count() -> int:
	return _discard_pile.size()


## Shuffles the draw pile in place (Fisher-Yates with the instance RNG).
func shuffle() -> void:
	for i in range(_draw_pile.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := _draw_pile[i]
		_draw_pile[i] = _draw_pile[j]
		_draw_pile[j] = tmp


## Draws up to [param count] cards off the top. If the draw pile empties mid-draw and the discard
## pile is not empty, the discard is reshuffled back in and drawing continues. Returns the cards
## actually drawn (fewer than [param count] only when the deck is fully exhausted).
func draw(count: int) -> Array[CardDefinition]:
	var result: Array[CardDefinition] = []
	for _i in count:
		if _draw_pile.is_empty():
			if _discard_pile.is_empty():
				break
			reshuffle()
		result.append(_draw_pile.pop_back())
	if not result.is_empty():
		drawn.emit(result)
	return result


## Sends [param card] to the discard pile.
func discard(card: CardDefinition) -> void:
	_discard_pile.append(card)
	discarded.emit(card)


## Puts [param card] back on top of the draw pile — it will be the next card drawn.
func return_to_top(card: CardDefinition) -> void:
	_draw_pile.append(card)


## Folds the discard pile back into the draw pile and shuffles. Also done automatically by
## [method draw] when the draw pile empties mid-draw.
func reshuffle() -> void:
	_draw_pile.append_array(_discard_pile)
	_discard_pile = []
	shuffle()
	reshuffled.emit()
