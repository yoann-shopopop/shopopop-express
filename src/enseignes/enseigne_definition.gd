class_name EnseigneDefinition
extends Resource
## A pickup point (shop sign): a parody brand with its logo. Pure data (.tres), like PawnDefinition.

@export var id: StringName = &""
@export var display_name: String = ""
@export var texture: Texture2D = null  ## the brand logo (assets/trades/*)
@export var color: Color = Color.WHITE  ## tab tint
