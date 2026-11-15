# SI assistance metadata: This code used the help of SI.
extends Control

const FACILITY := "res://scenes/world/facility/facility.tscn"
var _sim: LaunchSim
var _status: Label
var _altitude: Label
var _flight: Control
var _done := false
var _success := false
var _elapsed := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("101a21")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 18)
	for side in ["left", "right", "top", "bottom"]:
		layout.add_theme_constant_override("margin_" + side, 42)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 42)
	add_child(margin)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "MISSION CONTROL  /  BEACON-1"
	title.add_theme_font_override("font", ConsoleTheme.typewriter())
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", ConsoleTheme.CREAM)
	layout.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "SELENE FLIGHT DYNAMICS / UNMANNED ORBITAL INSERTION"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", ConsoleTheme.MUSTARD)
	layout.add_child(subtitle)
	_flight = FlightDisplay.new()
	_flight.custom_minimum_size = Vector2(0, 310)
	_flight.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_flight)
	_altitude = Label.new()
	_altitude.text = "ALTITUDE   000.0 KM       VELOCITY   0000 M/S"
	_altitude.add_theme_font_override("font", ConsoleTheme.mono())
	_altitude.add_theme_font_size_override("font_size", 21)
	_altitude.add_theme_color_override("font_color", ConsoleTheme.CREAM)
	layout.add_child(_altitude)
	_status = Label.new()
	_status.text = "FLIGHT COMPUTER: GUIDANCE SOLUTION ACCEPTED. IGNITION."
	_status.custom_minimum_size = Vector2(0, 56)
	_status.add_theme_font_override("font", ConsoleTheme.mono())
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", ConsoleTheme.MUSTARD)
	layout.add_child(_status)
	var actions := HBoxContainer.new()
	var retry := Button.new()
	retry.text = "RESTART FLIGHT"
	retry.pressed.connect(_start_flight)
	actions.add_child(retry)
	var return_button := Button.new()
	return_button.text = "RETURN TO FACILITY"
	return_button.pressed.connect(func() -> void: SceneManager.change_scene(FACILITY))
	actions.add_child(return_button)
	layout.add_child(actions)
	_start_flight()

func _start_flight() -> void:
	var design := GameState.current_design.duplicate(true)
	if design.is_empty():
		_status.text = "NO VEHICLE ON THE PAD. RETURN TO THE DESIGN BAY."
		_done = true
		return
	_sim = LaunchSim.new(design, DataLoader.sim_data(), DataLoader.raw.get("launch_sim", {}), {"reliability": false, "record": false})
	_done = false
	_success = false
	_elapsed = 0.0
	_flight.queue_redraw()
	_status.text = "COUNTDOWN COMPLETE. VEHICLE IS UNDER POWER."

func _process(delta: float) -> void:
	if _sim == null or _done:
		return
	_elapsed += delta
	for _i in 240:
		if _sim.done:
			break
		_sim.step()
	_flight.set("progress", clampf(_sim.altitude_m / maxf(float(_sim.mission.get("target_apogee_km", 200.0)) * 1000.0, 1.0), 0.0, 1.0))
	_altitude.text = "ALTITUDE   %07.1f KM       VELOCITY   %05.0f M/S       T+ %05.1f" % [_sim.altitude_m / 1000.0, _sim.speed_ms, _sim.t]
	_flight.queue_redraw()
	if _sim.done:
		_done = true
		_success = bool(_sim.result.get("in_orbit", false))
		if _success:
			_status.text = "ORBIT ACHIEVED. BEACON-1 IS TRANSMITTING. DOT HAS LEFT A KEY FOR YOU."
			GameState.set_flag("dad_office_unlocked")
			StoryTriggers.fire("orbit_achieved", _sim.result)
		else:
			_status.text = "FLIGHT ENDED: %s. REVIEW THE DESIGN AND TRY AGAIN." % str(_sim.result.get("failure_type", "SHORT OF ORBIT")).replace("_", " ").to_upper()

class FlightDisplay:
	extends Control
	var progress := 0.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("17282d"), true)
		draw_rect(r, Color("6f8580"), false, 2.0)
		var horizon_y := size.y * 0.74
		draw_rect(Rect2(0, horizon_y, size.x, size.y - horizon_y), Color("344e47"), true)
		for x in range(0, int(size.x), 64):
			draw_line(Vector2(x, horizon_y), Vector2(x + 34, horizon_y), Color("9bab8b", 0.45), 1.0)
		var y := lerpf(size.y * 0.62, size.y * 0.14, clampf(progress, 0.0, 1.0))
		var x := size.x * 0.52
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 38), Vector2(x + 14, y + 20), Vector2(x, y + 14), Vector2(x - 14, y + 20)]), Color("e9e0c1"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 8, y + 18), Vector2(x - 15, y + 34), Vector2(x, y + 25), Vector2(x + 15, y + 34), Vector2(x + 8, y + 18)]), Color("c98242"))
		draw_line(Vector2(20, size.y - 20), Vector2(size.x - 20, size.y - 20), Color("b39b58", 0.45), 1.0)

	func _process(_delta: float) -> void:
		queue_redraw()
