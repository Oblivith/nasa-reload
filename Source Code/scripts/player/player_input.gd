# SI assistance metadata: This code used the help of SI.
class_name PlayerInput
extends RefCounted

const MOVE_LEFT := &"player_move_left"
const MOVE_RIGHT := &"player_move_right"
const MOVE_FORWARD := &"player_move_forward"
const MOVE_BACK := &"player_move_back"
const SPRINT := &"player_sprint"
const INTERACT := &"player_interact"
const SWAP_SHOULDER := &"player_swap_shoulder"
const CANCEL := &"player_cancel"
const LOOK_LEFT := &"player_look_left"
const LOOK_RIGHT := &"player_look_right"
const LOOK_UP := &"player_look_up"
const LOOK_DOWN := &"player_look_down"

const DEFAULTS := {
	MOVE_LEFT: {"keys": [KEY_A, KEY_LEFT], "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	MOVE_RIGHT: {"keys": [KEY_D, KEY_RIGHT], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
	MOVE_FORWARD: {"keys": [KEY_W, KEY_UP], "axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
	MOVE_BACK: {"keys": [KEY_S, KEY_DOWN], "axes": [[JOY_AXIS_LEFT_Y, 1.0]]},
	SPRINT: {"keys": [KEY_SHIFT], "buttons": [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_B]},
	INTERACT: {"keys": [KEY_E], "buttons": [JOY_BUTTON_A]},
	SWAP_SHOULDER: {"keys": [KEY_Q], "buttons": [JOY_BUTTON_RIGHT_STICK]},
	CANCEL: {"keys": [KEY_ESCAPE], "buttons": [JOY_BUTTON_START]},
	LOOK_LEFT: {"axes": [[JOY_AXIS_RIGHT_X, -1.0]]},
	LOOK_RIGHT: {"axes": [[JOY_AXIS_RIGHT_X, 1.0]]},
	LOOK_UP: {"axes": [[JOY_AXIS_RIGHT_Y, -1.0]]},
	LOOK_DOWN: {"axes": [[JOY_AXIS_RIGHT_Y, 1.0]]},
}

static func ensure_actions() -> void:
	for action: StringName in DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.25)
		var spec: Dictionary = DEFAULTS[action]
		for code: int in spec.get("keys", []):
			var key := InputEventKey.new()
			key.physical_keycode = code as Key
			InputMap.action_add_event(action, key)
		for button: int in spec.get("buttons", []):
			var pad := InputEventJoypadButton.new()
			pad.button_index = button as JoyButton
			InputMap.action_add_event(action, pad)
		for axis: Array in spec.get("axes", []):
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(axis[0]) as JoyAxis
			motion.axis_value = float(axis[1])
			InputMap.action_add_event(action, motion)

static func key_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if code == KEY_ESCAPE:
			return "Esc"
		return OS.get_keycode_string(code)
	return "?"
