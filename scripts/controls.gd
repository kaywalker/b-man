class_name Controls
## Eingaben pro Spieler: Tastatur (zum Testen) und Gamepad.
##
## Belegung wie beim Büro-Tisch (siehe knusperpixel/office-racer):
## - Der Prototyp meldet sich als vier Gamepads (Stick + Knöpfe).
## - Knopf 1 (und linke Schultertaste/Trigger) ist B, JEDER andere Knopf ist A.
##   Der Gas-/A-Knopf des Prototyps kommt als Knopf 3 an.
## - Die ersten beiden Controller sind am Tisch andersherum verkabelt: Pad → Spieler = 1, 0, 2, 3.
## - Der Bildschirm liegt flach, jeder sitzt an einer Seite. Der Stick wird deshalb pro Platz
##   gedreht: "vom Spieler weg" bewegt die Figur immer vom eigenen Bildschirmrand weg.
##
## Die Werte stehen in user://controls.cfg und lassen sich dort anpassen.
## Startoptionen (nach "--"): --pads=1,0,2,3  --desktop (Stick nicht drehen)

const CONFIG_PATH := "user://controls.cfg"
const CONFIG_VERSION := 2
const ACTIONS := ["up", "down", "left", "right", "a", "b"]

enum Side { BOTTOM, RIGHT, TOP, LEFT }
const SIDE_NAMES := ["unten", "rechts", "oben", "links"]

## Gamepad-Nummer je Spieler (P1..P4), wie PAD_FOR_SEAT im office-racer.
const DEFAULT_PADS := [1, 0, 2, 3]
## Sitzplatz je Spieler: P1 unten, P2 rechts, P3 oben, P4 links.
const DEFAULT_SIDES := [Side.BOTTOM, Side.RIGHT, Side.TOP, Side.LEFT]
## Knöpfe, die NICHT als A zählen.
const NOT_A := [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
	JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]

## Tastatur-Belegung wie im office-racer.
const DEFAULT_KEYS := [
	{"up": "W", "down": "S", "left": "A", "right": "D", "a": "Shift", "b": "Ctrl"},
	{"up": "Up", "down": "Down", "left": "Left", "right": "Right", "a": "Enter", "b": "Backspace"},
	{"up": "I", "down": "K", "left": "J", "right": "L", "a": "U", "b": "O"},
	{"up": "Kp 8", "down": "Kp 5", "left": "Kp 4", "right": "Kp 6", "a": "Kp 0", "b": "Kp Enter"},
]

static var deadzone := 0.4
static var table_mode := true
static var pads: Array = DEFAULT_PADS.duplicate()
static var sides: Array = DEFAULT_SIDES.duplicate()
static var button_b: Array = [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER]
## Zuletzt gedrückter Gamepad-Knopf, zur Anzeige in der Lobby.
static var last_raw := ""

static var _frame := -1
static var _now: Array = []
static var _prev: Array = []


static func action(player: int, name: String) -> StringName:
	return StringName("p%d_%s" % [player, name])


static func setup() -> void:
	var cfg := ConfigFile.new()
	var loaded := cfg.load(CONFIG_PATH) == OK and int(cfg.get_value("general", "version", 1)) >= CONFIG_VERSION
	if not loaded:
		cfg = ConfigFile.new()
	cfg.set_value("general", "version", CONFIG_VERSION)
	deadzone = cfg.get_value("general", "deadzone", deadzone)
	cfg.set_value("general", "deadzone", deadzone)
	table_mode = cfg.get_value("general", "table_mode", table_mode)
	cfg.set_value("general", "table_mode", table_mode)
	button_b = cfg.get_value("general", "buttons_b", button_b)
	cfg.set_value("general", "buttons_b", button_b)

	for p in Defs.MAX_PLAYERS:
		var sec := "player%d" % (p + 1)
		pads[p] = int(cfg.get_value(sec, "joypad_device", DEFAULT_PADS[p]))
		cfg.set_value(sec, "joypad_device", pads[p])
		var side_name: String = cfg.get_value(sec, "seat", SIDE_NAMES[DEFAULT_SIDES[p]])
		cfg.set_value(sec, "seat", side_name)
		sides[p] = maxi(SIDE_NAMES.find(side_name), 0)

		for act in ACTIONS:
			var name := action(p, act)
			if InputMap.has_action(name):
				InputMap.erase_action(name)
			InputMap.add_action(name)
			var key_str: String = cfg.get_value(sec, "key_" + act, DEFAULT_KEYS[p][act])
			cfg.set_value(sec, "key_" + act, key_str)
			var keycode := OS.find_keycode_from_string(key_str)
			if keycode != KEY_NONE:
				var ev := InputEventKey.new()
				ev.physical_keycode = keycode
				InputMap.action_add_event(name, ev)

	if not loaded:
		cfg.save(CONFIG_PATH)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pads="):
			var parts := arg.trim_prefix("--pads=").split(",")
			for i in mini(parts.size(), Defs.MAX_PLAYERS):
				pads[i] = int(parts[i])
		elif arg == "--desktop":
			table_mode = false

	_now.resize(Defs.MAX_PLAYERS)
	_prev.resize(Defs.MAX_PLAYERS)
	for p in Defs.MAX_PLAYERS:
		_now[p] = {"dir": Vector2i.ZERO, "a": false, "b": false}
		_prev[p] = _now[p]


static func log_raw(event: InputEvent) -> void:
	## Wie im office-racer: jeden Gamepad-Knopf in der Konsole (und in der Lobby) zeigen.
	if event is InputEventJoypadButton and event.pressed:
		last_raw = "Gamepad %d: Knopf %d" % [event.device, event.button_index]
		print("%s (%s)" % [last_raw, Input.get_joy_name(event.device)])


static func _update() -> void:
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	_frame = f
	var connected := Input.get_connected_joypads()
	for p in Defs.MAX_PLAYERS:
		_prev[p] = _now[p]
		_now[p] = _read(p, connected)


static func _read(p: int, connected: Array) -> Dictionary:
	# Tastatur (Bildschirm-Richtungen, nicht gedreht).
	var key := Vector2i.ZERO
	if Input.is_action_pressed(action(p, "left")):
		key.x -= 1
	if Input.is_action_pressed(action(p, "right")):
		key.x += 1
	if Input.is_action_pressed(action(p, "up")):
		key.y -= 1
	if Input.is_action_pressed(action(p, "down")):
		key.y += 1
	var a := Input.is_action_pressed(action(p, "a"))
	var b := Input.is_action_pressed(action(p, "b"))

	var pad: int = pads[p]
	var stick := Vector2i.ZERO
	if pad >= 0 and pad in connected:
		# Stick aus Sicht des Spielers: x = rechts, y = von ihm weg.
		var s := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), -Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		var dpad := Vector2(
			float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT)),
			float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP)) - float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN)))
		if dpad != Vector2.ZERO:
			s = dpad
		var screen := _to_screen(s, sides[p]) if table_mode else s
		stick = Vector2i(
			1 if screen.x > deadzone else (-1 if screen.x < -deadzone else 0),
			-1 if screen.y > deadzone else (1 if screen.y < -deadzone else 0))
		a = a or _pad_a(pad)
		b = b or _pad_b(pad)

	var dir := key if key != Vector2i.ZERO else stick
	return {"dir": dir, "a": a, "b": b}


static func _to_screen(s: Vector2, side: int) -> Vector2:
	## Dreht den Stick je nach Tischseite in Bildschirmrichtung (y nach oben).
	match side:
		Side.TOP:
			return Vector2(-s.x, -s.y)
		Side.RIGHT:
			return Vector2(-s.y, s.x)
		Side.LEFT:
			return Vector2(s.y, -s.x)
	return s


static func counts_as_a(btn: int) -> bool:
	return not (btn in NOT_A or btn in button_b)


static func _pad_a(pad: int) -> bool:
	for btn in JOY_BUTTON_MAX:
		if counts_as_a(btn) and Input.is_joy_button_pressed(pad, btn):
			return true
	return Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.4


static func _pad_b(pad: int) -> bool:
	for btn in button_b:
		if Input.is_joy_button_pressed(pad, btn):
			return true
	return Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) > 0.4


static func debug_text(player: int) -> String:
	## Für die Lobby: welches Pad, verbunden?, welche Knöpfe/Richtung kommen gerade an.
	_update()
	var pad: int = pads[player]
	var connected := pad in Input.get_connected_joypads()
	var s := "Pad %d %s" % [pad, "ok" if connected else "fehlt"]
	if connected:
		var raw := []
		for btn in JOY_BUTTON_MAX:
			if Input.is_joy_button_pressed(pad, btn):
				raw.append(str(btn))
		if not raw.is_empty():
			s += " K" + ",".join(raw)
	var st: Dictionary = _now[player]
	if st.a:
		s += " A"
	if st.b:
		s += " B"
	var arrows := {Vector2i.LEFT: "<", Vector2i.RIGHT: ">", Vector2i.UP: "^", Vector2i.DOWN: "v"}
	if st.dir.x != 0:
		s += " " + arrows[Vector2i(st.dir.x, 0)]
	if st.dir.y != 0:
		s += " " + arrows[Vector2i(0, st.dir.y)]
	return s


static func dir_pressed(player: int) -> Vector2i:
	_update()
	return _now[player].dir


static func just(player: int, name: String) -> bool:
	## "a"/"b": Knopf gerade gedrückt. "up"/"down"/"left"/"right": Richtung gerade angetippt.
	_update()
	var now: Dictionary = _now[player]
	var prev: Dictionary = _prev[player]
	match name:
		"a", "b":
			return now[name] and not prev[name]
		"up":
			return now.dir.y < 0 and prev.dir.y >= 0
		"down":
			return now.dir.y > 0 and prev.dir.y <= 0
		"left":
			return now.dir.x < 0 and prev.dir.x >= 0
		"right":
			return now.dir.x > 0 and prev.dir.x <= 0
	return false
