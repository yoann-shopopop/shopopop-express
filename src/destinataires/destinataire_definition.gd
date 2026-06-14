class_name DestinataireDefinition
extends Resource
## A recipient (the client of a delivery): a parody name, optional portrait. Pure data (.tres).

@export var id: StringName = &""
@export var display_name: String = ""
@export var texture: Texture2D = null  ## portrait (placeholder/null for now)
@export var color: Color = Color.WHITE  ## banner tint
