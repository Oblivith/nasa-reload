# Code generated with AI assistance (Claude). Reviewed by team.
class_name WorldAtmosphere
extends Node3D
## Lighting mood for the facility: WorldEnvironment (filmic tonemap, glow on screens and
## lamps, haze, warm 60s grade), the sun through the south windows with the only
## real-time shadows in the game, fake light shafts, and a film overlay (warm tint,
## vignette, grain). Settings are in data/facility_world.json "atmosphere"; each room's
## "mood" (ambient level, haze) is eased in as the player walks in.
##
## The Web export uses the Compatibility renderer, which has no SSAO, SSIL or volumetric
## fog. Those are switched on only when a RenderingDevice exists (desktop Forward+);
## on Web the look comes from baked vertex shading, depth fog, glow and the shafts.
##
## Quality: 2 = everything, 1 = no sun shadows, 0 = also no glow / fog / film overlay.
## F3 cycles it; auto_quality drops a level when the frame rate stays low.

signal quality_changed(level: int)

const OVERLAY_SHADER := "res://scripts/world/shaders/film_overlay.gdshader"
const SHAFT_SHADER := "res://scripts/world/shaders/beam.gdshader"

var world: FacilityWorld
var env: Environment
var sun: DirectionalLight3D
var quality: int = 2
var auto_quality: bool = true

var _cfg: Dictionary = {}
var _overlay: ColorRect
var _shafts: Node3D
var _ambient_target: float = 0.45
var _fog_target: float = 0.006
var _fog_color_target: Color = Color("d9c9a8")
var _sun_rooms: Array = []
var _slow_time: float = 0.0
var _fps_grace: float = 6.0


func setup(facility_world: FacilityWorld) -> void:
	world = facility_world
	_cfg = world.cfg.get("atmosphere", {})
	_build_environment()
	_build_sun()
	_build_overlay()
	world.room_changed.connect(_on_room_changed)
	set_quality(int(_cfg.get("quality", 2)))


func _build_environment() -> void:
	var node := WorldEnvironment.new()
	env = Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(str(_cfg.get("sky_top", "5f9fd0")))
	sky_material.sky_horizon_color = Color(str(_cfg.get("sky_horizon", "dfe9e4")))
	sky_material.ground_horizon_color = Color(str(_cfg.get("sky_horizon", "dfe9e4")))
	sky_material.ground_bottom_color = Color("8aa06e")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(str(_cfg.get("ambient_color", "fff0da")))
	env.ambient_light_energy = _ambient_target
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(_cfg.get("exposure", 1.25))
	env.tonemap_white = float(_cfg.get("white", 5.0))
	env.glow_enabled = true
	env.glow_intensity = float(_cfg.get("glow_intensity", 0.55))
	env.glow_strength = 1.0
	env.glow_bloom = float(_cfg.get("glow_bloom", 0.04))
	env.glow_hdr_threshold = float(_cfg.get("glow_threshold", 1.0))
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_light_color = _fog_color_target
	env.fog_density = _fog_target
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = float(_cfg.get("contrast", 1.06))
	env.adjustment_saturation = float(_cfg.get("saturation", 1.08))
	if RenderingServer.get_rendering_device() != null:
		# Desktop Forward+ / Mobile only; ignored by the Web export's renderer.
		env.ssao_enabled = true
		env.ssao_intensity = 1.6
		env.ssil_enabled = true
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.012
	node.environment = env
	add_child(node)


func _build_sun() -> void:
	sun = DirectionalLight3D.new()
	var dir: Array = _cfg.get("sun_direction", [0.3, -0.62, -0.72])
	var d := Vector3(float(dir[0]), float(dir[1]), float(dir[2])).normalized()
	sun.basis = Basis.looking_at(d, Vector3.UP)
	sun.light_color = Color(str(_cfg.get("sun_color", "fff0cf")))
	sun.light_energy = float(_cfg.get("sun_energy", 1.5))
	sun.light_specular = 0.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 38.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	var mask := FacilityWorld.EXTERIOR_BIT
	for room in world.room_list:
		if room.cast_shadows:
			mask |= room.layer_bit
			_sun_rooms.append(room.room_id)
	sun.light_cull_mask = mask
	add_child(sun)
	# Fake volumetrics: a faint slab of lit haze slanting in from each sunny window.
	_shafts = Node3D.new()
	_shafts.name = "LightShafts"
	add_child(_shafts)
	var material := ShaderMaterial.new()
	material.shader = load(SHAFT_SHADER)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for w: Dictionary in world.cfg.get("windows", []):
		var ids: Array = w.get("rooms", [])
		if ids.size() != 1 or str(ids[0]) not in _sun_rooms or str(w.get("axis", "x")) != "x":
			continue
		var at: Array = w["at"]
		var y0 := float(w.get("y", 0.0)) + float(w.get("sill", 0.9))
		var y1 := y0 + float(w.get("h", 1.6))
		var half := float(w.get("w", 2.0)) / 2.0 - 0.15
		var reach := (y1 - float(w.get("y", 0.0))) / maxf(0.05, -d.y)
		var push := d * minf(reach, 7.0)
		var strength := float(_cfg.get("shaft_strength", 0.11))
		for edge: float in [y0 + 0.05, y1 - 0.05, (y0 + y1) / 2.0]:
			var a := Vector3(float(at[0]) - half, edge, float(at[1]) - 0.12)
			var b := Vector3(float(at[0]) + half, edge, float(at[1]) - 0.12)
			for tri: Array in [[a, b, b + push], [a, b + push, a + push]]:
				for p: Vector3 in tri:
					st.set_color(Color(1.0, 0.93, 0.78, strength if (p == a or p == b) else 0.0))
					st.add_vertex(p)
			count += 1
	if count > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shafts.add_child(mi)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load(OVERLAY_SHADER)
	var tint: Array = _cfg.get("grade_tint", [1.0, 0.965, 0.885])
	material.set_shader_parameter("tint", Vector3(float(tint[0]), float(tint[1]), float(tint[2])))
	material.set_shader_parameter("vignette", float(_cfg.get("vignette", 0.34)))
	material.set_shader_parameter("grain", float(_cfg.get("grain", 0.055)))
	_overlay.material = material
	layer.add_child(_overlay)


func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	sun.shadow_enabled = quality >= 2
	env.glow_enabled = quality >= 1
	env.fog_enabled = quality >= 1
	_overlay.visible = quality >= 1
	_shafts.visible = quality >= 1
	quality_changed.emit(quality)


func _on_room_changed(_room_id: String, room: Dictionary) -> void:
	var mood: Dictionary = room.get("mood", {})
	_ambient_target = float(mood.get("ambient", _cfg.get("ambient", 0.45)))
	_fog_target = float(mood.get("fog", _cfg.get("fog", 0.006)))
	_fog_color_target = Color(str(mood.get("fog_color", _cfg.get("fog_color", "d9c9a8"))))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F3:
		auto_quality = false
		set_quality((quality + 2) % 3)


func _process(delta: float) -> void:
	var k := minf(1.0, delta * 1.8)
	env.ambient_light_energy = lerpf(env.ambient_light_energy, _ambient_target, k)
	env.fog_density = lerpf(env.fog_density, _fog_target, k)
	env.fog_light_color = env.fog_light_color.lerp(_fog_color_target, k)
	var sunny := world.visible_rooms.has(FacilityWorld.EXTERIOR)
	if not sunny:
		for id: String in _sun_rooms:
			if world.visible_rooms.has(id):
				sunny = true
				break
	sun.visible = sunny
	_shafts.visible = sunny and quality >= 1
	# Protect the frame rate on slow machines / browsers: step quality down if it stays low.
	if auto_quality and quality > 0:
		_fps_grace -= delta
		if _fps_grace <= 0.0:
			_slow_time = _slow_time + delta if Engine.get_frames_per_second() < 27.0 else 0.0
			if _slow_time > 4.0:
				_slow_time = 0.0
				_fps_grace = 6.0
				set_quality(quality - 1)
