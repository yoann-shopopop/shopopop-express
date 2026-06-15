class_name SceneEnvironment
extends RefCounted
## Builds the shared top-down play environment: a warm key light, a soft WorldEnvironment (filmic
## tonemap + ambient fill), a vertical gradient ground backdrop and a screen-edge vignette. Used by
## both the composition root ([Main]) and the screenshot harness so they look identical. Everything
## here is GL-Compatibility-safe — no glow / SSAO / SSR / volumetrics (those are Forward+ only).

const BG_TOP := Color("2b3650")
const BG_BOTTOM := Color("12161f")
const KEY_LIGHT := Color("fff3df")  # slightly warm sun


## Adds the light, environment, backdrop and vignette under [param parent].
static func build(parent: Node) -> void:
	_build_light(parent)
	_build_world_env(parent)
	_build_backdrop(parent)
	_build_vignette(parent)


static func _build_light(parent: Node) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58, -42, 0)
	light.light_color = KEY_LIGHT
	light.light_energy = 1.15
	light.shadow_enabled = true
	light.directional_shadow_blend_splits = true
	parent.add_child(light)


static func _build_world_env(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG_BOTTOM  # matches the gradient's bottom for any pan past the plane
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("99a4ba")
	env.ambient_light_energy = 0.85
	# Filmic tonemap lifts the midtones so the textured tiles read richer (GL-Compatibility supports
	# tonemapping; glow/SSAO/SSR do not and are intentionally left off).
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 1.0
	var holder := WorldEnvironment.new()
	holder.environment = env
	parent.add_child(holder)


static func _build_backdrop(parent: Node) -> void:
	# A large unshaded ground plane below the tiles, painted with a vertical gradient. Lives in the 3D
	# world (a CanvasLayer would draw over the board). Source-color uniforms keep the colors correct.
	var backdrop := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	backdrop.mesh = plane
	backdrop.position = Vector3(0, -2, 0)
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nrender_mode unshaded;\n" \
		+ "uniform vec3 top_color : source_color;\nuniform vec3 bottom_color : source_color;\n" \
		+ "void fragment() { ALBEDO = mix(top_color, bottom_color, UV.y); }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("top_color", BG_TOP)
	mat.set_shader_parameter("bottom_color", BG_BOTTOM)
	backdrop.material_override = mat
	parent.add_child(backdrop)


static func _build_vignette(parent: Node) -> void:
	# A 2D screen-edge darkening, on a CanvasLayer below the HUD (layer 0 < PlayHud's 1). Focuses the
	# eye on the board and adds depth without any Forward+ post-processing.
	var layer := CanvasLayer.new()
	layer.layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\n" \
		+ "uniform float strength : hint_range(0.0, 1.0) = 0.5;\n" \
		+ "uniform float radius : hint_range(0.0, 1.5) = 0.78;\n" \
		+ "void fragment() {\n" \
		+ "\tvec2 d = UV - vec2(0.5);\n" \
		+ "\tfloat r = length(d) * 1.41421356;\n" \
		+ "\tfloat v = smoothstep(radius, 1.0, r) * strength;\n" \
		+ "\tCOLOR = vec4(0.0, 0.0, 0.0, v);\n" \
		+ "}"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("strength", 0.62)
	mat.set_shader_parameter("radius", 0.72)
	rect.material = mat
	layer.add_child(rect)
	parent.add_child(layer)
