class_name PawnDefinition
extends Resource
## A pawn's identity: its name, its image, and what kind of pawn it is.
##
## Pure data, authored as a [code].tres[/code] (same pattern as [BlockDefinition]). It carries the
## rendering [Texture2D] but performs no rendering itself; the mutable runtime state lives in [Pawn].

## The three kinds of pawn. Only the cotransporter moves; drive and recipient are placed once at
## setup and then stay put.
enum PawnType {
	COTRANSPORTER,  ## The player's token; moves according to the dice.
	DRIVE,  ## Pickup point; placed once, then fixed.
	RECIPIENT,  ## Delivery destination; placed once, then fixed.
}

## Stable identifier, e.g. [code]&"cotransporter_axelle"[/code].
@export var id: StringName = &""
## Human-readable name shown in the UI.
@export var display_name: String = ""
## The pawn's image (used by fixed pawns — drive/recipient — that carry a shop sign).
@export var texture: Texture2D = null
## The player color, used to tint a cotransporter's figure.
@export var color: Color = Color.WHITE
## Which kind of pawn this is.
@export var type: PawnType = PawnType.COTRANSPORTER


## True only for the cotransporter — the single source of truth for "who can move".
func is_mobile() -> bool:
	return type == PawnType.COTRANSPORTER
