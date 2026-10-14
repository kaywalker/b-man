extends Node
## Smoke-Test ohne Spieler: "-- --autotest=SEKUNDEN" startet ein Match mit vier
## Zufalls-Bots, die über die normalen Input-Actions steuern, und beendet sich danach.
## Ausgabe endet mit "autotest after …"; bei Skriptfehlern fehlt diese Zeile.

var duration := 60.0
var _t := 0.0
var _next_change := 0.0
var _rng := RandomNumberGenerator.new()
var _main: Node
var _rounds_seen := 0


func _ready() -> void:
	_rng.seed = 1
	_main = get_parent()


func _game() -> Game:
	for c in _main.get_children():
		if c is Game:
			return c
	return null


func _act(name: StringName, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = pressed
	Input.parse_input_event(e)


func _process(delta: float) -> void:
	_t += delta
	var g := _game()
	if g == null:
		# Lobby: alle vier melden sich an und sind bereit.
		var press := fmod(_t, 0.2) < 0.1
		for i in Defs.MAX_PLAYERS:
			_act(Controls.action(i, "a"), press)
	else:
		_rounds_seen = maxi(_rounds_seen, g.round_no)
		_next_change -= delta
		if _next_change <= 0.0:
			_next_change = 0.3
			for i in Defs.MAX_PLAYERS:
				for d in ["up", "down", "left", "right"]:
					_act(Controls.action(i, d), false)
				_act(Controls.action(i, ["up", "down", "left", "right"][_rng.randi() % 4]), true)
				_act(Controls.action(i, "a"), _rng.randf() < 0.35)
				_act(Controls.action(i, "b"), _rng.randf() < 0.1)
	if _t >= duration:
		var wins: Array = g.wins if g else []
		print("autotest after %.0f s: rounds=%d wins=%s" % [_t, _rounds_seen, str(wins)])
		get_tree().quit(0 if _rounds_seen >= 1 else 1)
