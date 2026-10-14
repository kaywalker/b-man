extends Node
## Bewegungstest mit echtem Spiel (braucht das Sfx-Autoload, daher als Szene):
##   godot --headless --path . --fixed-fps 60 res://tests/movement_test.tscn
## Prüft, dass die Figur bei schräg gehaltenem Stick nie auf der Stelle hängen bleibt.

const FRAMES := 20
const DIAGONALS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
## Kreuzung, waagerechter Gang, senkrechter Gang und leicht versetzte Positionen.
const POSITIONS := [Vector2(5, 7), Vector2(6, 7), Vector2(5, 6), Vector2(7, 5), Vector2(8, 5),
	Vector2(5.3, 7), Vector2(5, 6.7), Vector2(6.4, 7), Vector2(9, 8.2), Vector2(3, 3)]

var _game: Game
var _cases: Array = []
var _case := -1
var _frame := 0
var _start := Vector2.ZERO
var _failed := 0


func _ready() -> void:
	Controls.setup()
	_game = Game.new()
	_game.setup([0, 1] as Array[int], 3, 150.0)
	add_child(_game)
	for pos in POSITIONS:
		for d in DIAGONALS:
			_cases.append([pos, d])


func _act(name: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = Controls.action(0, name)
	e.pressed = pressed
	Input.parse_input_event(e)


func _hold(d: Vector2i) -> void:
	_act("left", d.x < 0)
	_act("right", d.x > 0)
	_act("up", d.y < 0)
	_act("down", d.y > 0)


func _process(_delta: float) -> void:
	if _case < 0:
		# Feld leer räumen (nur Säulen bleiben), Runde sofort starten.
		for y in range(1, Defs.GRID_H - 1):
			for x in range(1, Defs.GRID_W - 1):
				if not (x % 2 == 0 and y % 2 == 0):
					_game.grid[_game._i(Vector2i(x, y))] = Defs.Cell.EMPTY
		_game.hidden_items.clear()
		_game.time_left = 1000.0
		_game._set_state(Game.State.RUNNING)
		_next_case()
		return
	var p: BPlayer = _game.players[0]
	_frame += 1
	if _frame < FRAMES:
		return
	var moved := p.cell_pos.distance_to(_start)
	var c: Array = _cases[_case]
	var ok := moved > 0.3
	if not ok:
		_failed += 1
	print("%s  start %s  schräg %s  bewegt %.2f" % ["ok  " if ok else "FAIL", c[0], c[1], moved])
	_next_case()


func _next_case() -> void:
	_case += 1
	if _case >= _cases.size():
		_hold(Vector2i.ZERO)
		print("%d Fehler" % _failed)
		get_tree().quit(1 if _failed > 0 else 0)
		return
	var c: Array = _cases[_case]
	var p: BPlayer = _game.players[0]
	p.cell_pos = c[0]
	p.last_axis = 0
	_start = p.cell_pos
	_frame = 0
	_hold(c[1])
