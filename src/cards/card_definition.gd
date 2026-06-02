class_name CardDefinition
extends Resource
## A card's identity. Placeholder for now: the front art is not designed yet, and every card shares
## the same back (logo + "CARD_TYPE"), so the back is not described here.
##
## Pure data, authored as a [code].tres[/code] (same pattern as [BlockDefinition]/[PawnDefinition]).

## Stable identifier, e.g. [code]&"event_red_light"[/code].
@export var id: StringName = &""
## Human-readable name shown in the UI.
@export var display_name: String = ""
## Placeholder front image.
@export var front_texture: Texture2D = null
