class_name BPlayer
extends Node2D
## Ein Bomberman. Position in Feldkoordinaten (ganze Zahl = Feldmitte).

var idx := 0
var cell_pos := Vector2.ZERO
var alive := true
var death_t := 0.0

var max_bombs := 1
var bombs_out := 0
var fire := Defs.START_FIRE
var speed_lvl := 0
var can_kick := false
var has_remote := false
var disease := Defs.Disease.NONE
var disease_t := 0.0

var facing := Vector2i.DOWN
var moving := false
var walk_t := 0.0
var last_axis := 0  # 0 = horizontal, 1 = vertikal


func setup(player_idx: int, start: Vector2i) -> void:
	idx = player_idx
	cell_pos = Vector2(start)
	sync_position()


func cell() -> Vector2i:
	return Vector2i(roundi(cell_pos.x), roundi(cell_pos.y))


func speed() -> float:
	match disease:
		Defs.Disease.SLOW:
			return 1.6
		Defs.Disease.FAST:
			return 7.5
	return Defs.BASE_SPEED + speed_lvl * Defs.SPEED_STEP


func power() -> int:
	return 1 if disease == Defs.Disease.SHORT_FIRE else fire


func is_active() -> bool:
	return alive and death_t <= 0.0


func kill() -> void:
	if not alive or death_t > 0.0:
		return
	death_t = Defs.DEATH_TIME
	has_remote = false
	Sfx.play("death")


func sync_position() -> void:
	# Node-Position = Füße (unten in der Feldmitte), damit die Y-Sortierung stimmt.
	position = Defs.cell_to_screen(cell_pos) + Vector2(0, 6)


func _process(delta: float) -> void:
	if death_t > 0.0:
		death_t -= delta
		if death_t <= 0.0:
			alive = false
			visible = false
	if moving:
		walk_t += delta
	queue_redraw()


func _draw() -> void:
	if not alive:
		return
	if death_t > 0.0:
		var k := death_t / Defs.DEATH_TIME
		var tint := Color(1, 1, 1, k).lerp(Color(1, 0.4, 0.2, k), 1.0 - k)
		draw_set_transform(Vector2(0, -8), sin((1.0 - k) * 18.0) * 0.6, Vector2(k, k) * 0.6 + Vector2(0.4, 0.4))
		Art.bomber(self, Vector2(0, 8), idx, Vector2i.DOWN, 0.0, false, tint)
		draw_set_transform(Vector2.ZERO)
		return
	var tint := Color.WHITE
	if disease != Defs.Disease.NONE and int(disease_t * 10.0) % 2 == 0:
		tint = Color(0.75, 0.45, 1.0)
	Art.bomber(self, Vector2.ZERO, idx, facing, walk_t, moving, tint)
