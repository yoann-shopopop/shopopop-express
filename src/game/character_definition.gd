class_name CharacterDefinition
extends Resource
## A character card: a transport mode (which fixes the dice count), the two district colors of the
## character's regular route, and a one-shot super-power (resolved by data — see PowerResolver).
##
## Pure data, authored as a [code].tres[/code] (same pattern as [BlockDefinition]/[PawnDefinition]).

## The four transport modes. Bike/foot roll 1 die, car/truck roll 2.
enum Transport { VELO, A_PIED, VOITURE, CAMION }

## Stable identifier, e.g. [code]&"axelle"[/code].
@export var id: StringName = &""
## Human-readable name shown in the UI.
@export var display_name: String = ""
## The transport mode — determines [method dice_count].
@export var transport: Transport = Transport.VELO
## The two district colors of the character's regular route ([enum PlayerColor.Kind] values).
@export var colors: Array[int] = []
## Identifier of the one-shot super-power, resolved by PowerResolver (e.g. [code]&"bouclier_vert"[/code]).
@export var power_id: StringName = &""
## The character card's image.
@export var texture: Texture2D = null


## Number of dice rolled this turn: 1 for bike/foot, 2 for car/truck.
func dice_count() -> int:
	match transport:
		Transport.VOITURE, Transport.CAMION:
			return 2
		_:
			return 1


## True if [param kind] ([enum PlayerColor.Kind]) is one of the character's regular-route colors.
func owns_color(kind: int) -> bool:
	return kind in colors
