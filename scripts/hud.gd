class_name Hud
extends Node2D
## Seitenleisten mit Spielerstatus, Rundenzeit und Einblendungen.

var game: Game

const PANEL_SIZE := Vector2(108, 102)


func _panel_rect(i: int) -> Rect2:
	var x := 6.0 if i % 2 == 0 else Defs.SCREEN.x - 6.0 - PANEL_SIZE.x
	var y := 40.0 if i < 2 else 40.0 + 208.0 - PANEL_SIZE.y
	return Rect2(Vector2(x, y), PANEL_SIZE)


func _draw() -> void:
	if game == null:
		return
	_draw_top()
	for i in Defs.MAX_PLAYERS:
		_draw_panel(i)
	_draw_center()


func _draw_top() -> void:
	var t := ceili(game.time_left)
	var s := "%d:%02d" % [t / 60, t % 60]
	var col := Color.WHITE
	if game.hurry and int(game.anim_t * 4.0) % 2 == 0:
		col = Color("ff5040")
	var box := Rect2(Defs.SCREEN.x / 2 - 34, 6, 68, 26)
	draw_rect(box, Color("101018"))
	draw_rect(box, Color("606070"), false, 1.0)
	Art.text(self, Vector2(Defs.SCREEN.x / 2, 26), s, 18, col)
	Art.text(self, Vector2(Defs.ARENA_ORIGIN.x, 24), "RUNDE %d" % game.round_no, 10, Color("c0c0d0"),
		HORIZONTAL_ALIGNMENT_LEFT, 80)
	Art.text(self, Vector2(Defs.ARENA_ORIGIN.x + 240 - 80, 24), "ZIEL: %d" % game.wins_needed, 10,
		Color("c0c0d0"), HORIZONTAL_ALIGNMENT_RIGHT, 80)


func _draw_panel(i: int) -> void:
	var r := _panel_rect(i)
	var pcol: Color = Defs.PLAYER_COLORS[i]
	draw_rect(r, Color("16161f"))
	draw_rect(r, pcol.lerp(Color("606070"), 0.4), false, 1.0)
	var o := r.position
	if not game.participants.has(i):
		Art.text(self, o + Vector2(54, 56), Defs.PLAYER_NAMES[i], 12, Color("505060"))
		Art.text(self, o + Vector2(54, 72), "nicht dabei", 10, Color("404050"))
		return
	var p: BPlayer = game.players[i]

	# Portrait
	draw_set_transform(o + Vector2(20, 44), 0.0, Vector2(1.4, 1.4))
	var tint := Color.WHITE if p and p.is_active() else Color(0.35, 0.35, 0.4)
	Art.bomber(self, Vector2.ZERO, i, Vector2i.DOWN, 0.0, false, tint)
	draw_set_transform(Vector2.ZERO)
	Art.text(self, o + Vector2(44, 17), Defs.PLAYER_NAMES[i], 14, pcol if i != 1 else Color("9090a8"),
		HORIZONTAL_ALIGNMENT_LEFT, 60)

	# Siege als Pokale
	for k in game.wins_needed:
		var c := o + Vector2(48 + k * 11, 28)
		var won: bool = k < game.wins[i]
		draw_circle(c, 4.0, Color("f0c020") if won else Color("303040"))
		if won:
			draw_circle(c + Vector2(-1, -1), 1.2, Color("fff0a0"))

	if p == null:
		return
	if not p.is_active():
		Art.text(self, o + Vector2(76, 50), "K.O.", 14, Color("ff5040"))
	# Werte
	var y := o.y + 66
	_stat(Vector2(o.x + 12, y), Defs.Item.BOMB, str(p.max_bombs))
	_stat(Vector2(o.x + 46, y), Defs.Item.FIRE, str(p.fire) if p.fire < Defs.FULL_FIRE else "MAX")
	_stat(Vector2(o.x + 82, y), Defs.Item.SPEED, str(p.speed_lvl + 1))
	var x := o.x + 12
	y += 22
	if p.can_kick:
		_icon(Vector2(x, y), Defs.Item.KICK)
		x += 22
	if p.has_remote:
		_icon(Vector2(x, y), Defs.Item.REMOTE)
		x += 22
	if p.disease != Defs.Disease.NONE:
		_icon(Vector2(x, y), Defs.Item.SKULL)


func _icon(c: Vector2, kind: int) -> void:
	Art.item(self, Rect2(c - Vector2(8, 8), Vector2(16, 16)), kind, 0.0)


func _stat(c: Vector2, kind: int, value: String) -> void:
	_icon(c, kind)
	Art.text(self, c + Vector2(10, 5), value, 10, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 30)


func _draw_center() -> void:
	var mid := Defs.ARENA_ORIGIN + Vector2(Defs.GRID_W, Defs.GRID_H) * Defs.TILE / 2.0
	match game.state:
		Game.State.COUNTDOWN:
			_banner(mid, "RUNDE %d" % game.round_no, "BEREIT?", Color.WHITE)
		Game.State.ROUND_RESULT:
			if game.round_winner >= 0:
				_banner(mid, "%s GEWINNT" % Defs.PLAYER_NAMES[game.round_winner], "die Runde!",
					Defs.PLAYER_COLORS[game.round_winner])
			else:
				_banner(mid, "UNENTSCHIEDEN", "", Color.WHITE)
		Game.State.MATCH_RESULT:
			_match_result(mid)
	if game.message_t > 0.0 and game.state in [Game.State.RUNNING, Game.State.SETTLE]:
		var col := Color("ffd040") if game.message == "LOS!" else Color("ff5040")
		Art.text(self, mid + Vector2(0, 8), game.message, 28, col)


func _banner(mid: Vector2, line1: String, line2: String, col: Color) -> void:
	var h := 52.0 if line2 != "" else 34.0
	var r := Rect2(mid.x - 110, mid.y - h / 2, 220, h)
	draw_rect(r, Color(0, 0, 0, 0.75))
	draw_rect(r, Color("a0a0b0"), false, 1.0)
	var c := col if col.v > 0.35 else Color("b0b0c8")
	Art.text(self, Vector2(mid.x, r.position.y + 24), line1, 20, c)
	if line2 != "":
		Art.text(self, Vector2(mid.x, r.position.y + 44), line2, 14, Color.WHITE)


func _match_result(mid: Vector2) -> void:
	var w := game.match_winner
	var r := Rect2(mid.x - 120, mid.y - 70, 240, 140)
	draw_rect(r, Color(0, 0, 0, 0.85))
	draw_rect(r, Color("f0c020"), false, 2.0)
	Art.text(self, Vector2(mid.x, r.position.y + 26), "SIEGER!", 22, Color("f0c020"))
	var bounce := absf(sin(game.anim_t * 6.0)) * -6.0
	draw_set_transform(Vector2(mid.x, r.position.y + 92 + bounce), 0.0, Vector2(2, 2))
	Art.bomber(self, Vector2.ZERO, w, Vector2i.DOWN, 0.0, false)
	draw_set_transform(Vector2.ZERO)
	Art.text(self, Vector2(mid.x, r.position.y + 116), "%s gewinnt das Match" % Defs.PLAYER_NAMES[w], 14,
		Color.WHITE)
	if game.state_t > 1.5:
		Art.text(self, Vector2(mid.x, r.position.y + 133), "A: weiter", 10, Color("a0a0b0"))
