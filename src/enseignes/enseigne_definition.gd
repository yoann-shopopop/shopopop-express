class_name EnseigneDefinition
extends Resource
## A pickup point (shop sign): a FICTIONAL shop with an optional logo. Pure data (.tres), like
## PawnDefinition. Never a real-brand parody: a commercial product protects parody poorly.

@export var id: StringName = &""
@export var display_name: String = ""
@export var texture: Texture2D = null  ## shop logo (null until the illustrator delivers — views fall back to color + name)
@export var color: Color = Color.WHITE  ## tab tint
