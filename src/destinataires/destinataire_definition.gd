class_name DestinataireDefinition
extends Resource
## A recipient (the client of a delivery): a fictional character with an optional portrait and a
## little quirk (flavor text, a future hook for mini-effects). Pure data (.tres).

@export var id: StringName = &""
@export var display_name: String = ""
@export var texture: Texture2D = null  ## portrait (null until the illustrator delivers — views fall back to color + name)
@export var color: Color = Color.WHITE  ## banner tint
@export_multiline var manie: String = ""  ## the character's quirk, one wry sentence (flavor)
