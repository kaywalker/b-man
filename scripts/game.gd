class_name Game
extends Node2D
## Battle-Modus: Arena, Bomben, Flammen, Items, Runden und Match-Wertung.

signal match_finished(winner: int)

enum State { COUNTDOWN, RUNNING, SETTLE, ROUND_RESULT, MATCH_RESULT }


class Bomb:
	var cell: Vector2i
	var pos: Vector2
	var owner: int
	var fuse: float
	var power: int
	var remote: bool
	var order: int
	var slide_dir := Vector2i.ZERO
	var riders := {}  # Spieler, die (noch) auf der Bombe stehen und durch dürfen
	var exploded := false


var participants: Array[int] = []
var wins_needed := 3
var round_time := 150.0
var wins := [0, 0, 0, 0]
var round_no := 0

var grid := PackedInt32Array()
var hidden_items := {}   # Vector2i -> Item (unter Softblöcken)
var items := {}          # Vector2i -> Item (sichtbar)
var bombs: Array[Bomb] = []
var flames := {}         # Vector2i -> {t, arms, center}
var burning := {}        # Vector2i -> verbleibende Brennzeit
var falling: Array = []  # [{cell, t}]
var players: Array = [null, null, null, null]

var state := State.COUNTDOWN
var state_t := 0.0
var time_left := 0.0
var hurry := false
var spiral: Array[Vector2i] = []
var spiral_i := 0
var spiral_t := 0.0
var round_winner := -1
var match_winner := -1
var message := ""
var message_t := 0.0
var anim_t := 0.0
var _bomb_counter := 0

var _players_layer: Node2D
var _overlay: Node2D
var _hud: Hud


func setup(p_participants: Array[int], p_wins_needed: int, p_round_time: float) -> void:
	participants = p_participants
	wins_needed = p_wins_needed
	round_time = p_round_time


func _ready() -> void:
	_players_layer = Node2D.new()
	_players_layer.y_sort_enabled = true
	add_child(_players_layer)
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_hud = Hud.new()
	_hud.game = self
	add_child(_hud)
	_start_round()


# ---------------------------------------------------------------- Runde / Arena

func _start_round() -> void:
	round_no += 1
	for p in players:
		if p:
			p.queue_free()
	players = [null, null, null, null]
	bombs.clear()
	flames.clear()
	burning.clear()
	falling.clear()
	items.clear()
	hidden_items.clear()
	_build_arena()
	for i in participants:
		var p := BPlayer.new()
		p.setup(i, Defs.START_CELLS[i])
		_players_layer.add_child(p)
		players[i] = p
	time_left = round_time
	hurry = false
	spiral = _build_spiral()
	spiral_i = 0
	spiral_t = 0.0
	round_winner = -1
	_set_state(State.COUNTDOWN)
	Sfx.play("tick")


func _build_arena() -> void:
	grid.resize(Defs.GRID_W * Defs.GRID_H)
	var safe := {}
	for s in Defs.START_CELLS:
		safe[s] = true
		for d in Defs.DIRS:
			safe[s + d] = true
	var soft_cells: Array[Vector2i] = []
	for y in Defs.GRID_H:
		for x in Defs.GRID_W:
			var c := Vector2i(x, y)
			var v := Defs.Cell.EMPTY
			if x == 0 or y == 0 or x == Defs.GRID_W - 1 or y == Defs.GRID_H - 1:
				v = Defs.Cell.HARD
			elif x % 2 == 0 and y % 2 == 0:
				v = Defs.Cell.HARD
			elif not safe.has(c) and randf() < Defs.SOFT_BLOCK_CHANCE:
				v = Defs.Cell.SOFT
				soft_cells.append(c)
			grid[_i(c)] = v
	soft_cells.shuffle()
	var k := 0
	for item_kind in Defs.ITEM_POOL:
		for n in Defs.ITEM_POOL[item_kind]:
			if k >= soft_cells.size():
				return
			hidden_items[soft_cells[k]] = item_kind
			k += 1


func _build_spiral() -> Array[Vector2i]:
	## Reihenfolge der Druckblöcke: von außen im Uhrzeigersinn nach innen.
	var out: Array[Vector2i] = []
	var x0 := 1
	var y0 := 1
	var x1 := Defs.GRID_W - 2
	var y1 := Defs.GRID_H - 2
	while x0 <= x1 and y0 <= y1:
		for x in range(x0, x1 + 1):
			out.append(Vector2i(x, y0))
		for y in range(y0 + 1, y1 + 1):
			out.append(Vector2i(x1, y))
		if y1 > y0:
			for x in range(x1 - 1, x0 - 1, -1):
				out.append(Vector2i(x, y1))
		if x1 > x0:
			for y in range(y1 - 1, y0, -1):
				out.append(Vector2i(x0, y))
		x0 += 1
		y0 += 1
		x1 -= 1
		y1 -= 1
	return out


func _i(c: Vector2i) -> int:
	return c.y * Defs.GRID_W + c.x


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < Defs.GRID_W and c.y < Defs.GRID_H


func cell_at(c: Vector2i) -> int:
	return grid[_i(c)] if _in_grid(c) else Defs.Cell.HARD


func bomb_at(c: Vector2i) -> Bomb:
	for b in bombs:
		if b.cell == c:
			return b
	return null


func _player_on(c: Vector2i) -> bool:
	for p in players:
		if p and p.is_active() and p.cell() == c:
			return true
	return false


func _blocked_for(c: Vector2i, p: BPlayer) -> bool:
	if cell_at(c) != Defs.Cell.EMPTY:
		return true
	var b := bomb_at(c)
	return b != null and not b.riders.has(p.idx)


func _blocked_for_bomb(c: Vector2i) -> bool:
	return cell_at(c) != Defs.Cell.EMPTY or bomb_at(c) != null or items.has(c) or _player_on(c)


# ---------------------------------------------------------------- Ablauf

func _set_state(s: State) -> void:
	state = s
	state_t = 0.0


func _show(msg: String, t: float) -> void:
	message = msg
	message_t = t


func _process(delta: float) -> void:
	anim_t += delta
	state_t += delta
	if message_t > 0.0:
		message_t -= delta

	if Input.is_action_just_pressed("ui_cancel"):
		set_process(false)
		match_finished.emit(-1)
		return

	match state:
		State.COUNTDOWN:
			if state_t >= Defs.COUNTDOWN_TIME:
				_set_state(State.RUNNING)
				_show("LOS!", 0.8)
				Sfx.play("go")
		State.RUNNING, State.SETTLE:
			_update_world(delta)
			var active := _active_players()
			if state == State.RUNNING and (active.size() <= 1 or time_left <= 0.0):
				_set_state(State.SETTLE)
			elif state == State.SETTLE and state_t >= Defs.ROUND_SETTLE_TIME:
				_finish_round()
		State.ROUND_RESULT:
			_update_animations(delta)
			if state_t >= Defs.ROUND_RESULT_TIME:
				if match_winner >= 0:
					_set_state(State.MATCH_RESULT)
					Sfx.play("win")
				else:
					_start_round()
		State.MATCH_RESULT:
			if state_t >= Defs.MATCH_RESULT_TIME or (state_t > 1.5 and _any_a_pressed()):
				set_process(false)
				match_finished.emit(match_winner)
				return
	queue_redraw()
	_overlay.queue_redraw()
	_hud.queue_redraw()


func _active_players() -> Array:
	var out := []
	for p in players:
		if p and p.is_active():
			out.append(p)
	return out


func _any_a_pressed() -> bool:
	for i in participants:
		if Controls.just(i, "a"):
			return true
	return false


func _finish_round() -> void:
	var active := _active_players()
	if active.size() == 1 and time_left > 0.0:
		round_winner = active[0].idx
		wins[round_winner] += 1
		if wins[round_winner] >= wins_needed:
			match_winner = round_winner
		Sfx.play("win")
	else:
		round_winner = -1
	_set_state(State.ROUND_RESULT)


func _update_world(delta: float) -> void:
	time_left = maxf(time_left - delta, 0.0)
	if not hurry and time_left <= Defs.HURRY_AT and round_time > Defs.HURRY_AT:
		hurry = true
		_show("HURRY UP!", 2.0)
		Sfx.play("hurry")

	for p in players:
		if p and p.is_active():
			_update_player(p, delta)
	_update_bombs(delta)
	_update_animations(delta)
	_check_collisions()
	if hurry:
		_update_pressure(delta)


func _update_animations(delta: float) -> void:
	for c in flames.keys():
		flames[c].t -= delta
		if flames[c].t <= 0.0:
			flames.erase(c)
	for c in burning.keys():
		burning[c] -= delta
		if burning[c] <= 0.0:
			burning.erase(c)
			grid[_i(c)] = Defs.Cell.EMPTY
			if hidden_items.has(c):
				items[c] = hidden_items[c]
				hidden_items.erase(c)


# ---------------------------------------------------------------- Spieler

func _update_player(p: BPlayer, delta: float) -> void:
	if p.disease != Defs.Disease.NONE:
		p.disease_t -= delta
		if p.disease_t <= 0.0:
			p.disease = Defs.Disease.NONE

	var d := Controls.dir_pressed(p.idx)
	if p.disease == Defs.Disease.REVERSE:
		d = -d

	p.moving = false
	if d != Vector2i.ZERO:
		var cands: Array[Vector2i] = []
		if d.x != 0 and d.y != 0:
			# Diagonal: zuerst die Achse probieren, auf der man gerade nicht läuft (Abbiegen).
			if p.last_axis == 0:
				cands = [Vector2i(0, d.y), Vector2i(d.x, 0)]
			else:
				cands = [Vector2i(d.x, 0), Vector2i(0, d.y)]
		else:
			cands = [d]
		var dist := p.speed() * delta
		for dir in cands:
			var np := _try_move(p, dir, dist)
			if not np.is_equal_approx(p.cell_pos):
				p.cell_pos = np
				p.facing = dir
				p.last_axis = 0 if dir.x != 0 else 1
				p.moving = true
				break
		if not p.moving:
			p.facing = cands[0]
			for dir in cands:
				if p.can_kick and _try_kick(p, dir):
					break
		p.sync_position()

	var want_bomb := Controls.just(p.idx, "a") or p.disease == Defs.Disease.AUTO_BOMB
	if want_bomb:
		_place_bomb(p)
	if Controls.just(p.idx, "b"):
		_detonate_remote(p)


func _try_move(p: BPlayer, dir: Vector2i, dist: float) -> Vector2:
	## Bewegung entlang des Rasters mit Ecken-Assistent wie beim Original:
	## Steht man leicht versetzt, wird man automatisch in die freie Gasse geschoben.
	var pos := p.cell_pos
	var a := 0 if dir.x != 0 else 1
	var b := 1 - a
	var s := dir[a]
	var c := Vector2i(roundi(pos.x), roundi(pos.y))
	var ahead := c
	ahead[a] += s
	var off: float = pos[b] - c[b]
	var np := pos

	if absf(off) > 0.001:
		var target_b := float(c[b])
		if _blocked_for(ahead, p):
			var other := c
			other[b] += 1 if off > 0.0 else -1
			var other_ahead := other
			other_ahead[a] += s
			if _blocked_for(other, p) or _blocked_for(other_ahead, p):
				return pos
			target_b = float(other[b])
		np[b] = move_toward(pos[b], target_b, dist)
		return np

	np[b] = float(c[b])
	var m: float = pos[a] + s * dist
	if _blocked_for(ahead, p):
		if s > 0:
			m = minf(m, maxf(pos[a], float(c[a])))
		else:
			m = maxf(m, minf(pos[a], float(c[a])))
	np[a] = m
	return np


func _try_kick(p: BPlayer, dir: Vector2i) -> bool:
	var c := p.cell()
	if p.cell_pos.distance_to(Vector2(c)) > 0.05:
		return false
	var b := bomb_at(c + dir)
	if b == null or b.slide_dir != Vector2i.ZERO or b.riders.has(p.idx):
		return false
	if _blocked_for_bomb(b.cell + dir):
		return false
	b.slide_dir = dir
	b.riders.clear()
	Sfx.play("kick")
	return true


func _place_bomb(p: BPlayer) -> void:
	if p.disease == Defs.Disease.NO_BOMB or p.bombs_out >= p.max_bombs:
		return
	var c := p.cell()
	if cell_at(c) != Defs.Cell.EMPTY or bomb_at(c) != null:
		return
	var b := Bomb.new()
	b.cell = c
	b.pos = Vector2(c)
	b.owner = p.idx
	b.power = p.power()
	b.remote = p.has_remote
	b.fuse = INF if b.remote else Defs.FUSE_TIME
	_bomb_counter += 1
	b.order = _bomb_counter
	for q in players:
		if q and q.is_active() and absf(q.cell_pos.x - c.x) < 0.999 and absf(q.cell_pos.y - c.y) < 0.999:
			b.riders[q.idx] = true
	bombs.append(b)
	p.bombs_out += 1
	Sfx.play("place")


func _detonate_remote(p: BPlayer) -> void:
	var oldest: Bomb = null
	for b in bombs:
		if b.owner == p.idx and b.remote and (oldest == null or b.order < oldest.order):
			oldest = b
	if oldest:
		_explode(oldest)


# ---------------------------------------------------------------- Bomben & Flammen

func _update_bombs(delta: float) -> void:
	for b in bombs.duplicate():
		if b.exploded:
			continue
		for k in b.riders.keys():
			var q: BPlayer = players[k]
			if q == null or not q.is_active() \
					or absf(q.cell_pos.x - b.cell.x) >= 0.999 or absf(q.cell_pos.y - b.cell.y) >= 0.999:
				b.riders.erase(k)
		if b.slide_dir != Vector2i.ZERO:
			_slide_bomb(b, delta)
		# Fernzünder-Bomben explodieren normal, wenn ihr Besitzer stirbt.
		if b.remote:
			var owner: BPlayer = players[b.owner]
			if owner == null or not owner.is_active():
				b.remote = false
				b.fuse = Defs.FUSE_TIME
		b.fuse -= delta
		if b.fuse <= 0.0 or flames.has(b.cell):
			_explode(b)


func _slide_bomb(b: Bomb, delta: float) -> void:
	var dir := Vector2(b.slide_dir)
	var center := Vector2(b.cell)
	var new_pos := b.pos + dir * Defs.BOMB_SLIDE_SPEED * delta
	var progress := (new_pos - center).dot(dir)
	if progress >= 0.0 and _blocked_for_bomb(b.cell + b.slide_dir):
		b.pos = center
		b.slide_dir = Vector2i.ZERO
		return
	b.pos = new_pos
	if progress >= 0.5:
		b.cell += b.slide_dir


func _explode(first: Bomb) -> void:
	var queue: Array[Bomb] = [first]
	while not queue.is_empty():
		var b: Bomb = queue.pop_back()
		if b.exploded:
			continue
		b.exploded = true
		bombs.erase(b)
		var owner: BPlayer = players[b.owner]
		if owner:
			owner.bombs_out = maxi(owner.bombs_out - 1, 0)
		var c := b.cell
		_add_flame(c, 15, true)
		for d in Defs.DIRS:
			var back := _arm_bit(-d)
			var fwd := _arm_bit(d)
			for r in range(1, b.power + 1):
				var cc: Vector2i = c + d * r
				var v := cell_at(cc)
				if v == Defs.Cell.HARD:
					break
				if v == Defs.Cell.SOFT:
					if not burning.has(cc):
						burning[cc] = Defs.BURN_TIME
					break
				var other := bomb_at(cc)
				if other:
					queue.append(other)
					break
				if items.has(cc):
					items.erase(cc)
					_add_flame(cc, back, false)
					break
				_add_flame(cc, back | (fwd if r < b.power else 0), false)
	Sfx.play("explode")


func _arm_bit(d: Vector2i) -> int:
	match d:
		Vector2i.LEFT:
			return 1
		Vector2i.RIGHT:
			return 2
		Vector2i.UP:
			return 4
	return 8


func _add_flame(c: Vector2i, arms: int, center: bool) -> void:
	if flames.has(c):
		var f: Dictionary = flames[c]
		f.t = Defs.FLAME_TIME
		f.arms |= arms
		f.center = f.center or center
	else:
		flames[c] = {"t": Defs.FLAME_TIME, "arms": arms, "center": center}


# ---------------------------------------------------------------- Kollisionen / Items

func _check_collisions() -> void:
	var active := _active_players()
	for p: BPlayer in active:
		var c := p.cell()
		if flames.has(c):
			p.kill()
			continue
		if items.has(c):
			_apply_item(p, items[c])
			items.erase(c)
	# Krankheiten (Totenkopf) springen bei Berührung über.
	for i in active.size():
		for j in range(i + 1, active.size()):
			var a: BPlayer = active[i]
			var b: BPlayer = active[j]
			if a.cell_pos.distance_to(b.cell_pos) > 0.75:
				continue
			if a.disease != Defs.Disease.NONE and b.disease == Defs.Disease.NONE:
				b.disease = a.disease
				b.disease_t = Defs.DISEASE_TIME
			elif b.disease != Defs.Disease.NONE and a.disease == Defs.Disease.NONE:
				a.disease = b.disease
				a.disease_t = Defs.DISEASE_TIME


func _apply_item(p: BPlayer, kind: int) -> void:
	match kind:
		Defs.Item.BOMB:
			p.max_bombs = mini(p.max_bombs + 1, Defs.MAX_BOMBS)
		Defs.Item.FIRE:
			p.fire = mini(p.fire + 1, Defs.MAX_FIRE) if p.fire < Defs.MAX_FIRE else p.fire
		Defs.Item.FULL_FIRE:
			p.fire = Defs.FULL_FIRE
		Defs.Item.SPEED:
			p.speed_lvl = mini(p.speed_lvl + 1, Defs.MAX_SPEED_LVL)
		Defs.Item.KICK:
			p.can_kick = true
		Defs.Item.REMOTE:
			p.has_remote = true
		Defs.Item.SKULL:
			p.disease = randi_range(Defs.Disease.SLOW, Defs.Disease.SHORT_FIRE) as Defs.Disease
			p.disease_t = Defs.DISEASE_TIME
			Sfx.play("skull")
			return
	Sfx.play("pickup")


# ---------------------------------------------------------------- Druckblöcke (Hurry Up)

func _update_pressure(delta: float) -> void:
	spiral_t -= delta
	while spiral_t <= 0.0 and spiral_i < spiral.size():
		var c := spiral[spiral_i]
		spiral_i += 1
		if cell_at(c) == Defs.Cell.HARD:
			continue
		falling.append({"cell": c, "t": Defs.FALL_TIME})
		spiral_t += Defs.PRESSURE_INTERVAL
	for f in falling.duplicate():
		f.t -= delta
		if f.t <= 0.0:
			falling.erase(f)
			_land_block(f.cell)


func _land_block(c: Vector2i) -> void:
	grid[_i(c)] = Defs.Cell.HARD
	items.erase(c)
	hidden_items.erase(c)
	burning.erase(c)
	var b := bomb_at(c)
	if b:
		b.exploded = true
		bombs.erase(b)
		var owner: BPlayer = players[b.owner]
		if owner:
			owner.bombs_out = maxi(owner.bombs_out - 1, 0)
	for p in _active_players():
		if absf(p.cell_pos.x - c.x) < 0.7 and absf(p.cell_pos.y - c.y) < 0.7:
			p.kill()
	Sfx.play("thud", -6.0)


# ---------------------------------------------------------------- Zeichnen

func _tile_rect(c: Vector2i) -> Rect2:
	return Rect2(Defs.ARENA_ORIGIN + Vector2(c) * Defs.TILE, Vector2(Defs.TILE, Defs.TILE))


func _draw() -> void:
	var arena := Rect2(Defs.ARENA_ORIGIN, Vector2(Defs.GRID_W, Defs.GRID_H) * Defs.TILE)
	draw_rect(arena.grow(3), Color("101018"))
	for y in Defs.GRID_H:
		for x in Defs.GRID_W:
			var c := Vector2i(x, y)
			var r := _tile_rect(c)
			match grid[_i(c)]:
				Defs.Cell.HARD:
					Art.hard_block(self, r)
				Defs.Cell.SOFT:
					Art.floor_tile(self, r, c, false)
					Art.soft_block(self, r, burning[c] / Defs.BURN_TIME if burning.has(c) else -1.0)
				_:
					Art.floor_tile(self, r, c, cell_at(c + Vector2i.UP) != Defs.Cell.EMPTY)
					if items.has(c):
						Art.item(self, r, items[c], anim_t)
	for b in bombs:
		Art.bomb(self, Defs.cell_to_screen(b.pos), anim_t + b.order, b.remote)


func _draw_overlay() -> void:
	for c in flames:
		var f: Dictionary = flames[c]
		Art.flame(_overlay, Defs.cell_to_screen(Vector2(c)), f.arms, f.center, f.t / Defs.FLAME_TIME)
	for f in falling:
		var r := _tile_rect(f.cell)
		var k: float = f.t / Defs.FALL_TIME
		_overlay.draw_rect(r.grow(-4.0 * (1.0 - k) - 2.0), Color(0, 0, 0, 0.35 * (1.0 - k)))
		Art.hard_block(_overlay, Rect2(r.position - Vector2(0, k * 48.0), r.size))
