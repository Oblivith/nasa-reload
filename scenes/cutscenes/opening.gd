# Code generated with AI assistance (Claude). Reviewed by team.
extends Control
## Opening cutscene: typewriter text over a dark star field, the flashback (dialogue on
## black, a door closing), then the title card, then the facility lobby.
## The beats and timings are in data/story_level1.json "opening"; the words are in
## data/story_dialogue.json scene "opening".
## E / Space / click = next, Esc = skip the whole thing.
## Debug: `-- --selftest` (runs fast and prints every beat),
##        `-- --beat=<n> --screenshot=<png>` (saves a picture of beat n).

const BG := Color("0a0e16")
const TEXT := Color("f2e8cf")

var _cfg: Dictionary = {}
var _stars: StarField
var _label: Label
var _title: Label
var _rule: ColorRect
var _hint: Label
var _fade: ColorRect
var _sfx: AudioStreamPlayer
var _box: StoryDialogueBox = null
var _advance: bool = false
var _skipped: bool = false
var _selftest: bool = false
var _shot_beat: int = -1
var _shot_path: String = ""
var _log: PackedStringArray = []


func _ready() -> void:
	_cfg = Story.flow.get("opening", {})
	for arg in OS.get_cmdline_user_args():
		if arg == "--selftest":
			_selftest = true
		elif arg.begins_with("--beat="):
			_shot_beat = int(arg.trim_prefix("--beat="))
		elif arg.begins_with("--screenshot="):
			_shot_path = arg.trim_prefix("--screenshot=")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_stars = StarField.new()
	_stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stars)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 0.5
	_label.anchor_bottom = 0.5
	_label.offset_left = -700
	_label.offset_right = 700
	_label.offset_top = -160
	_label.offset_bottom = 160
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_override("font", ConsoleTheme.typewriter())
	_label.add_theme_font_size_override("font_size", 44)
	_label.add_theme_color_override("font_color", TEXT)
	_label.add_theme_constant_override("line_spacing", 14)
	add_child(_label)

	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", ConsoleTheme.typewriter())
	_title.add_theme_font_size_override("font_size", 120)
	_title.add_theme_color_override("font_color", TEXT)
	_title.modulate.a = 0.0
	add_child(_title)
	_rule = ColorRect.new()
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.color = ConsoleTheme.MUSTARD
	_rule.anchor_left = 0.5
	_rule.anchor_right = 0.5
	_rule.anchor_top = 0.5
	_rule.anchor_bottom = 0.5
	_rule.offset_left = -330
	_rule.offset_right = 330
	_rule.offset_top = 88
	_rule.offset_bottom = 94
	_rule.modulate.a = 0.0
	add_child(_rule)

	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.text = Story.text("ui.hint_skip_opening")
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -640
	_hint.offset_right = -36
	_hint.offset_top = -58
	_hint.offset_bottom = -24
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(TEXT, 0.45))
	add_child(_hint)

	_fade = ColorRect.new()
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	if _selftest:
		Engine.time_scale = 12.0
	_run()


func _run() -> void:
	await _fade_to(0.0, 1.0)
	var beats: Array = _cfg.get("beats", [])
	for i in beats.size():
		if _skipped:
			break
		var beat: Dictionary = beats[i]
		_log.append("%d %s %s" % [i, str(beat.get("type", "")), str(beat.get("line", beat.get("lines", beat.get("file", ""))))])
		match str(beat.get("type", "")):
			"narrate":
				await _narrate(Story.text(str(beat["line"])), float(beat.get("hold", _cfg.get("hold_seconds", 1.9))), i)
			"stars":
				await _fade_stars(float(beat.get("alpha", 1.0)), float(beat.get("seconds", 1.0)))
			"dialogue":
				await _dialogue(beat, i)
			"sfx":
				_play(str(beat.get("file", "")))
				await _wait(float(beat.get("wait", 1.0)), false)
			"title":
				await _title_card(Story.text(str(beat["line"])), float(beat.get("hold", 3.5)), i)
	await _fade_to(1.0, 0.4 if _skipped else 1.2)
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	GameState.set_flag("opening_seen")
	if _selftest:
		for entry in _log:
			print("  beat " + entry)
		var ok := _skipped or _log.size() == (_cfg.get("beats", []) as Array).size()
		print("OPENING SELFTEST %s (%d beats)" % ["PASS" if ok and not _log.is_empty() else "FAIL", _log.size()])
		get_tree().quit(0 if ok and not _log.is_empty() else 1)
		return
	SceneManager.change_scene(str(_cfg.get("next_scene", "res://scenes/world/facility/facility.tscn")))


# --- Beats ---------------------------------------------------------------------------

func _narrate(line_text: String, hold: float, index: int) -> void:
	_label.text = line_text
	_label.visible_ratio = 0.0
	_label.modulate.a = 1.0
	var total := maxf(1.0, float(line_text.length()))
	var cps := float(_cfg.get("chars_per_second", 30.0))
	var shown := 0.0
	_advance = false
	while shown < total and not _skipped:
		await get_tree().process_frame
		shown += get_process_delta_time() * cps
		if _advance or _selftest:
			shown = total
		_label.visible_ratio = minf(1.0, shown / total)
	_label.visible_ratio = 1.0
	await _maybe_screenshot(index)
	await _wait(hold + line_text.length() * 0.012)
	await _fade_node(_label, 0.0, 0.45)
	_label.text = ""


func _dialogue(beat: Dictionary, index: int) -> void:
	_box = Story.make_box(Story.lines(beat.get("lines", []), {"auto": float(beat.get("auto", 2.2))}))
	_box.esc_skips_all = false
	_box.set_process_unhandled_key_input(false)      # this scene owns the keys
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	move_child(_fade, get_child_count() - 1)
	_hint.visible = false
	var box := _box
	if index == _shot_beat:
		await get_tree().create_timer(1.2).timeout
		await _maybe_screenshot(index)
	while is_instance_valid(box) and not box.is_queued_for_deletion():
		await get_tree().process_frame
		if _skipped and is_instance_valid(box):
			box.queue_free()
	_box = null
	_hint.visible = true


func _title_card(title_text: String, hold: float, index: int) -> void:
	_title.text = title_text
	_hint.visible = false
	await _fade_node(_title, 1.0, 1.4)
	await _fade_node(_rule, 1.0, 0.5)
	await _maybe_screenshot(index)
	await _wait(hold)


func _fade_stars(alpha: float, seconds: float) -> void:
	await _fade_node(_stars, alpha, seconds)


func _fade_to(alpha: float, seconds: float) -> void:
	await _fade_node(_fade, alpha, seconds)


func _fade_node(node: CanvasItem, alpha: float, seconds: float) -> void:
	var from := node.modulate.a
	var t := 0.0
	while t < seconds and not (_skipped and node != _fade):
		await get_tree().process_frame
		t += get_process_delta_time()
		node.modulate.a = lerpf(from, alpha, clampf(t / maxf(seconds, 0.001), 0.0, 1.0))
	node.modulate.a = alpha


## Waits `seconds`, or until the player presses E / clicks (when `can_advance`).
func _wait(seconds: float, can_advance: bool = true) -> void:
	var t := 0.0
	_advance = false
	while t < seconds and not _skipped:
		await get_tree().process_frame
		t += get_process_delta_time()
		if can_advance and _advance:
			break
	_advance = false


func _play(file: String) -> void:
	var path := "res://assets/audio/%s.wav" % file
	if file == "" or not ResourceLoader.exists(path):
		return
	_sfx.stream = load(path)
	_sfx.volume_db = -3.0
	_sfx.play()


func _maybe_screenshot(index: int) -> void:
	if index != _shot_beat or _shot_path == "":
		return
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(_shot_path)
	print("Opening: beat %d screenshot -> %s (%s)" % [index, _shot_path, error_string(err)])
	get_tree().quit()


# --- Input ---------------------------------------------------------------------------

func _next() -> void:
	if _box != null and is_instance_valid(_box):
		_box.advance()
	else:
		_advance = true


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_next()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	if code == KEY_ESCAPE:
		_skipped = true
	elif code == KEY_E or code == KEY_SPACE or code == KEY_ENTER or code == KEY_KP_ENTER or key.physical_keycode == KEY_E:
		_next()
	get_viewport().set_input_as_handled()


## A few hundred slowly twinkling stars, drawn in code (no texture needed).
class StarField:
	extends Control

	const COUNT := 220
	var _points: Array = []
	var _t: float = 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1958
		for i in COUNT:
			_points.append([rng.randf(), rng.randf(), rng.randf_range(0.8, 2.4), rng.randf() * TAU, rng.randf_range(0.3, 1.4)])

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for p: Array in _points:
			var glow := 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * float(p[4]) + float(p[3])))
			draw_circle(Vector2(float(p[0]) * size.x, float(p[1]) * size.y), float(p[2]), Color(0.95, 0.93, 0.85, glow * 0.85))
