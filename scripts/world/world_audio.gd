# Code generated with AI assistance (Claude). Reviewed by team.
class_name WorldAudio
extends Node
## Facility sound, driven by data/facility_audio.json:
##   * per-room ambience beds that cross-fade as the player changes room;
##   * positional emitters on props (teletype, tape drives, clocks, crane, phones that
##     ring now and then), only for rooms that are currently visible;
##   * footsteps that follow the floor surface of the room;
##   * doors, the lift (ding, motor, muffled ambience during the ride) and PA calls.
## All files are synthesised placeholders from tools/gen_audio; drop real recordings
## over them in /assets/audio with the same names.

signal announcement(text: String)

const DIR := "res://assets/audio/"
const POOL_SIZE := 6
const MAX_LOOP_EMITTERS := 7

var world: FacilityWorld
var cfg: Dictionary = {}

var _streams: Dictionary = {}
var _beds: Dictionary = {}            # file -> {player, target}
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_next: int = 0
var _emitters: Array = []             # [{id, node, pos, room}]
var _active_loops: Dictionary = {}    # emitter index -> AudioStreamPlayer3D
var _timers: Dictionary = {}          # emitter id -> seconds until the next one-shot
var _steps: AudioStreamPlayer
var _lift_motor: AudioStreamPlayer
var _step_travel: float = 0.0
var _last_pos: Vector3 = Vector3.INF
var _refresh: float = 0.0
var _pa_left: float = 30.0
var _pa_index: int = 0
var _muffle: float = 0.0
var _filter: AudioEffectLowPassFilter
var _fade: float = 1.4


func setup(facility_world: FacilityWorld, config: Dictionary) -> void:
	world = facility_world
	cfg = config
	_fade = float(cfg.get("fade_seconds", 1.4))
	_make_bus("Ambience")
	_make_bus("SFX")
	var bus := AudioServer.get_bus_index("Ambience")
	if AudioServer.get_bus_effect_count(bus) == 0:
		AudioServer.add_bus_effect(bus, AudioEffectLowPassFilter.new())
	_filter = AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	_filter.cutoff_hz = 20000.0
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 3.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool.append(p)
	_steps = AudioStreamPlayer.new()
	_steps.bus = "SFX"
	add_child(_steps)
	_lift_motor = AudioStreamPlayer.new()
	_lift_motor.bus = "SFX"
	_lift_motor.stream = _stream("loop_lift")
	_lift_motor.volume_db = float((cfg.get("lift", {}) as Dictionary).get("ride_db", -10.0))
	add_child(_lift_motor)
	for room in world.room_list:
		for prop in room.props:
			for s: Dictionary in prop.sounds:
				_emitters.append({"id": str(s["id"]), "node": prop, "pos": s["pos"], "room": room.room_id})
	for id: String in (cfg.get("emitters", {}) as Dictionary):
		var spec: Dictionary = cfg["emitters"][id]
		if spec.has("every"):
			_timers[id] = randf_range(4.0, float((spec["every"] as Array)[1]))
	var pa: Dictionary = cfg.get("pa", {})
	_pa_left = float(pa.get("first", 25.0))
	world.sound_player = play_at
	world.room_changed.connect(_on_room_changed)
	if world.lift != null:
		world.lift.ride_started.connect(func(_a: int, _b: int) -> void: _lift_motor.play())
		world.lift.ride_ended.connect(func(_f: int) -> void: _lift_motor.stop())


func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _stream(file: String) -> AudioStream:
	if not _streams.has(file):
		var path := DIR + file + ".wav"
		_streams[file] = load(path) if ResourceLoader.exists(path) else null
	return _streams[file]


## A one-shot at a place in the world (doors, lift ding, phones).
func play_at(id: String, at: Vector3, db: float = -6.0, max_distance: float = 22.0) -> void:
	var stream := _stream(id)
	if stream == null:
		return
	var p := _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.stream = stream
	p.global_position = at
	p.volume_db = db
	p.max_distance = max_distance
	p.pitch_scale = randf_range(0.96, 1.04)
	p.play()


func _on_room_changed(_room_id: String, room: Dictionary) -> void:
	var wanted: Dictionary = {}
	for layer: Array in (cfg.get("ambience", {}) as Dictionary).get(str(room.get("ambience", "")), []):
		wanted[str(layer[0])] = float(layer[1])
	for file: String in wanted:
		if not _beds.has(file):
			var stream := _stream(file)
			if stream == null:
				continue
			var player := AudioStreamPlayer.new()
			player.bus = "Ambience"
			player.stream = stream
			player.volume_db = -60.0
			add_child(player)
			_beds[file] = {"player": player, "target": -60.0}
	for file: String in _beds:
		_beds[file]["target"] = float(wanted.get(file, -60.0))


func ambience_playing() -> PackedStringArray:
	var result: PackedStringArray = []
	for file: String in _beds:
		if float(_beds[file]["target"]) > -59.0:
			result.append(file)
	return result


func _process(delta: float) -> void:
	# Cross-fade the ambience beds.
	var rate := 54.0 / maxf(0.1, _fade) * delta
	for file: String in _beds:
		var bed: Dictionary = _beds[file]
		var player: AudioStreamPlayer = bed["player"]
		var target := float(bed["target"])
		player.volume_db = move_toward(player.volume_db, target, rate)
		if target > -59.0 and not player.playing:
			player.play()
		elif target <= -59.0 and player.playing and player.volume_db <= -59.0:
			player.stop()
	# Muffle everything while riding in the closed lift.
	var in_lift := world.current_room == FacilityWorld.LIFT and world.lift != null and world.lift.door_open < 0.5
	_muffle = move_toward(_muffle, 1.0 if in_lift else 0.0, delta * 2.0)
	_filter.cutoff_hz = lerpf(20000.0, float((cfg.get("lift", {}) as Dictionary).get("muffle_hz", 700.0)), _muffle)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), -9.0 * _muffle)
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.5
		_refresh_loops()
	_tick_one_shots(delta)
	_tick_pa(delta)


func _listener() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	return camera.global_position if camera != null else Vector3.ZERO


## Starts looping emitters (teletype, tape, clock, crane) in visible rooms, nearest first.
func _refresh_loops() -> void:
	var specs: Dictionary = cfg.get("emitters", {})
	var ear := _listener()
	var candidates: Array = []
	for i in _emitters.size():
		var e: Dictionary = _emitters[i]
		var spec: Dictionary = specs.get(e["id"], {})
		if not bool(spec.get("loop", false)) or not world.visible_rooms.has(e["room"]):
			continue
		var at := (e["node"] as Node3D).to_global(e["pos"])
		var d := at.distance_to(ear)
		if d <= float(spec.get("range", 10.0)) * 1.3:
			candidates.append([d, i, at, spec])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var keep: Dictionary = {}
	var per_id: Dictionary = {}
	for c: Array in candidates:
		var e: Dictionary = _emitters[int(c[1])]
		var spec: Dictionary = c[3]
		var used := int(per_id.get(e["id"], 0))
		if used >= int(spec.get("max", 2)) or keep.size() >= MAX_LOOP_EMITTERS:
			continue
		per_id[e["id"]] = used + 1
		keep[int(c[1])] = c
	for index: int in _active_loops.keys():
		if not keep.has(index):
			(_active_loops[index] as AudioStreamPlayer3D).queue_free()
			_active_loops.erase(index)
	for index: int in keep:
		if _active_loops.has(index):
			continue
		var c: Array = keep[index]
		var spec: Dictionary = c[3]
		var stream := _stream(str(spec.get("file", "")))
		if stream == null:
			continue
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.stream = stream
		p.volume_db = float(spec.get("db", -14.0))
		p.max_distance = float(spec.get("range", 10.0))
		p.unit_size = 2.0
		add_child(p)
		p.global_position = c[2]
		p.play(randf() * 1.5)
		_active_loops[index] = p


func _tick_one_shots(delta: float) -> void:
	var specs: Dictionary = cfg.get("emitters", {})
	for id: String in _timers:
		_timers[id] = float(_timers[id]) - delta
		if float(_timers[id]) > 0.0:
			continue
		var spec: Dictionary = specs[id]
		var every: Array = spec["every"]
		_timers[id] = randf_range(float(every[0]), float(every[1]))
		var options: Array = []
		for e: Dictionary in _emitters:
			if e["id"] == id and world.visible_rooms.has(e["room"]):
				options.append(e)
		if not options.is_empty():
			var e: Dictionary = options[randi() % options.size()]
			play_at(str(spec.get("file", id)), (e["node"] as Node3D).to_global(e["pos"]), float(spec.get("db", -8.0)), float(spec.get("range", 16.0)))


## A distant PA call now and then: chime, a tinny voice, and the words as a caption.
func _tick_pa(delta: float) -> void:
	var pa: Dictionary = cfg.get("pa", {})
	var lines: Array = pa.get("lines", [])
	if lines.is_empty():
		return
	_pa_left -= delta
	if _pa_left > 0.0:
		return
	var every: Array = pa.get("every", [60, 120])
	_pa_left = randf_range(float(every[0]), float(every[1]))
	var ear := _listener()
	var best := Vector3.INF
	for e: Dictionary in _emitters:
		if e["id"] == "pa" and world.visible_rooms.has(e["room"]):
			var at := (e["node"] as Node3D).to_global(e["pos"])
			if best == Vector3.INF or at.distance_to(ear) < best.distance_to(ear):
				best = at
	if best == Vector3.INF:
		best = ear + Vector3(0, 6, 12)        # somewhere down the hall
	play_at("pa_chime", best, float(pa.get("db", -8.0)), 40.0)
	announcement.emit(str(pa.get("prefix", "")) + str(lines[_pa_index % lines.size()]))
	_pa_index += 1 + randi() % 2


func _physics_process(_delta: float) -> void:
	var body := world.player() as CharacterBody3D
	if body == null:
		return
	var pos := body.global_position
	if _last_pos == Vector3.INF or pos.distance_to(_last_pos) > 1.5:
		_last_pos = pos
		return
	var moved := Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
	_last_pos = pos
	if not body.is_on_floor() or moved < 0.001:
		return
	_step_travel += moved
	var steps: Dictionary = cfg.get("footsteps", {})
	if _step_travel < float(steps.get("stride_m", 0.8)):
		return
	_step_travel = 0.0
	var files: Array = steps.get(surface_at(pos), steps.get("lino", []))
	if files.is_empty():
		return
	_steps.stream = _stream(str(files[randi() % files.size()]))
	_steps.volume_db = float(steps.get("db", -12.0))
	_steps.pitch_scale = randf_range(0.92, 1.08)
	_steps.play()


## Floor surface under a point: the room's "surface", or metal on catwalks and stairs.
func surface_at(pos: Vector3) -> String:
	var id := world.room_at(pos + Vector3(0, 0.9, 0))
	if id == "" or id == FacilityWorld.LIFT:
		return "lino"
	var room: WorldRoom = world.rooms[id]
	var raised: Dictionary = room.data.get("raised_surface", {})
	if not raised.is_empty() and pos.y > room.base_y + float(raised.get("above", 0.5)):
		return str(raised.get("surface", "metal"))
	return str(room.data.get("surface", "lino"))
