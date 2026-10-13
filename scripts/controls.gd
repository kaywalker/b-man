class_name Controls
## Legt die Input-Actions p0_up … p3_b an.
##
## Jeder Spieler hat einen Joystick (Achsen oder D-Pad/Hat) und zwei Buttons (A, B).
## Die Belegung steht in user://controls.cfg und wird beim ersten Start mit
## Standardwerten angelegt – dort lässt sie sich für die Hardware des Tablets anpassen.

const CONFIG_PATH := "user://controls.cfg"
const ACTIONS := ["up", "down", "left", "right", "a", "b"]

## Tastatur-Belegung (vor allem zum Entwickeln am PC).
const DEFAULT_KEYS := [
	{"up": "W", "down": "S", "left": "A", "right": "D", "a": "Q", "b": "E"},
	{"up": "Up", "down": "Down", "left": "Left", "right": "Right", "a": "Enter", "b": "Backspace"},
	{"up": "I", "down": "K", "left": "J", "right": "L", "a": "U", "b": "O"},
	{"up": "Kp 8", "down": "Kp 5", "left": "Kp 4", "right": "Kp 6", "a": "Kp 7", "b": "Kp 9"},
]


static func action(player: int, name: String) -> StringName:
	return StringName("p%d_%s" % [player, name])


static func setup() -> void:
	var cfg := ConfigFile.new()
	var loaded := cfg.load(CONFIG_PATH) == OK
	var deadzone: float = cfg.get_value("general", "deadzone", 0.5)
	cfg.set_value("general", "deadzone", deadzone)

	for p in Defs.MAX_PLAYERS:
		var sec := "player%d" % (p + 1)
		var device: int = cfg.get_value(sec, "joypad_device", p)
		var axis_x: int = cfg.get_value(sec, "axis_x", JOY_AXIS_LEFT_X)
		var axis_y: int = cfg.get_value(sec, "axis_y", JOY_AXIS_LEFT_Y)
		var btn_a: int = cfg.get_value(sec, "button_a", JOY_BUTTON_A)
		var btn_b: int = cfg.get_value(sec, "button_b", JOY_BUTTON_B)
		cfg.set_value(sec, "joypad_device", device)
		cfg.set_value(sec, "axis_x", axis_x)
		cfg.set_value(sec, "axis_y", axis_y)
		cfg.set_value(sec, "button_a", btn_a)
		cfg.set_value(sec, "button_b", btn_b)

		for act in ACTIONS:
			var name := action(p, act)
			if InputMap.has_action(name):
				InputMap.erase_action(name)
			InputMap.add_action(name, deadzone)

			var key_str: String = cfg.get_value(sec, "key_" + act, DEFAULT_KEYS[p][act])
			cfg.set_value(sec, "key_" + act, key_str)
			var keycode := OS.find_keycode_from_string(key_str)
			if keycode != KEY_NONE:
				var ev := InputEventKey.new()
				ev.physical_keycode = keycode
				InputMap.action_add_event(name, ev)

			match act:
				"up":
					_add_axis(name, device, axis_y, -1.0)
					_add_button(name, device, JOY_BUTTON_DPAD_UP)
				"down":
					_add_axis(name, device, axis_y, 1.0)
					_add_button(name, device, JOY_BUTTON_DPAD_DOWN)
				"left":
					_add_axis(name, device, axis_x, -1.0)
					_add_button(name, device, JOY_BUTTON_DPAD_LEFT)
				"right":
					_add_axis(name, device, axis_x, 1.0)
					_add_button(name, device, JOY_BUTTON_DPAD_RIGHT)
				"a":
					_add_button(name, device, btn_a)
				"b":
					_add_button(name, device, btn_b)

	if not loaded:
		cfg.save(CONFIG_PATH)


static func _add_axis(action_name: StringName, device: int, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis as JoyAxis
	ev.axis_value = value
	InputMap.action_add_event(action_name, ev)


static func _add_button(action_name: StringName, device: int, button: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button as JoyButton
	InputMap.action_add_event(action_name, ev)


static func dir_pressed(player: int) -> Vector2i:
	var d := Vector2i.ZERO
	if Input.is_action_pressed(action(player, "left")):
		d.x -= 1
	if Input.is_action_pressed(action(player, "right")):
		d.x += 1
	if Input.is_action_pressed(action(player, "up")):
		d.y -= 1
	if Input.is_action_pressed(action(player, "down")):
		d.y += 1
	return d


static func just(player: int, name: String) -> bool:
	return Input.is_action_just_pressed(action(player, name))
