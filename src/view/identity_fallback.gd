class_name IdentityFallback
extends RefCounted
## Shared "couleur + nom" placeholder for any enseigne/destinataire without illustrated art yet — a
## stable color derived from the entity's name plus its initials, so every untextured identity reads
## as visually distinct instead of an identical blank void. Used by both [PawnView] (3D board tokens)
## and [DeliveryPanel] (2D delivery cards) so the fallback looks and behaves the same everywhere.

const _SKIP_WORDS := ["le", "la", "les", "l'", "au", "aux", "du", "de", "des", "d'"]


## A stable color derived from [param name]'s hash — distinct-enough placeholder identities before
## real art exists, without needing per-entity authored colors. Returns [param fallback] for an
## empty name (nothing to derive a color from).
static func color(name: String, fallback: Color) -> Color:
	if name.is_empty():
		return fallback
	var hue := float(hash(name) % 360) / 360.0
	return Color.from_hsv(hue, 0.55, 0.88)


## Up to two initials from [param name]'s meaningful words (short French articles skipped), e.g.
## "Le Fournil d'Hector" -> "FD". Falls back to the raw first letters if every word is skipped.
static func initials(name: String) -> String:
	var all_words := name.split(" ", false)
	var words: Array = []
	for w in all_words:
		if not (w.to_lower() in _SKIP_WORDS):
			words.append(w)
	if words.is_empty():
		words = all_words
	var result := ""
	for w in words:
		if w.is_empty():
			continue
		result += w.substr(0, 1).to_upper()
		if result.length() >= 2:
			break
	return result
