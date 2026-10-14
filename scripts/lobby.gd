class_name Lobby
extends Node2D
## Titelbildschirm: Spieler melden sich mit A an, mit A noch einmal sind sie bereit.

signal start_requested(participants: Array[int], wins_needed: int, round_time: float)

const WIN_OPTIONS := [1, 2, 3, 4, 5]
const TIME_OPTIONS := [90.0, 120.0, 150.0, 180.0, 240.0]
const START_DELAY := 3.0

# Einstellungen bleiben zwischen Matches erhalten.
static var win_idx := 2
static var time_idx := 2

var joined := [false, false, false, false]
var is_ready := [false, false, false, false]
var setting_row := 0
var start_t := -1.0
var anim_t := 0.0


func _process(delta: float) -> void:
	anim_t += delta
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
		return
	for i in Defs.MAX_PLAYERS:
		if Controls.just(i, "a"):
			if not joined[i]:
				joined[i] = true
				Sfx.play("select")
			elif not is_ready[i]:
				is_ready[i] = true
				Sfx.play("pickup")
		if Controls.just(i, "b"):
			if is_ready[i]:
				is_ready[i] = false
				Sfx.play("select")
			elif joined[i]:
				joined[i] = false
				Sfx.play("select")
		if Controls.just(i, "up") or Controls.just(i, "down"):
			setting_row = 1 - setting_row
			Sfx.play("select")
		var lr := int(Controls.just(i, "right")) - int(Controls.just(i, "left"))
		if lr != 0 and start_t < 0.0:
			if setting_row == 0:
				win_idx = clampi(win_idx + lr, 0, WIN_OPTIONS.size() - 1)
			else:
				time_idx = clampi(time_idx + lr, 0, TIME_OPTIONS.size() - 1)
			Sfx.play("select")

	var participants: Array[int] = []
	var all_ready := true
	for i in Defs.MAX_PLAYERS:
		if joined[i]:
			participants.append(i)
			all_ready = all_ready and is_ready[i]
	if participants.size() >= 2 and all_ready:
		if start_t < 0.0:
			start_t = START_DELAY
			Sfx.play("tick")
		var before := ceili(start_t)
		start_t -= delta
		if ceili(start_t) != before and start_t > 0.0:
			Sfx.play("tick")
		if start_t <= 0.0:
			start_requested.emit(participants, WIN_OPTIONS[win_idx], TIME_OPTIONS[time_idx])
			set_process(false)
	else:
		start_t = -1.0
	queue_redraw()


func _draw() -> void:
	# Hintergrund: Arena-Boden mit Blöcken am Rand.
	for y in 17:
		for x in 30:
			var r := Rect2(x * 16, y * 16, 16, 16)
			if y == 0 or y == 16 or x == 0 or x == 29:
				Art.hard_block(self, r)
			else:
				Art.floor_tile(self, r, Vector2i(x, y), y == 1)
	draw_rect(Rect2(16, 16, 448, 240), Color(0, 0, 0, 0.35))

	# Titel
	var bob := sin(anim_t * 3.0) * 2.0
	Art.bomb(self, Vector2(150, 40 + bob), anim_t, false)
	Art.bomb(self, Vector2(330, 40 - bob), anim_t + 1.0, false)
	Art.text(self, Vector2(240, 54), "B-MAN", 40, Color("ffd040"), HORIZONTAL_ALIGNMENT_CENTER, -1.0,
		Color("802010"))
	Art.text(self, Vector2(240, 70), "BATTLE MODE", 12, Color.WHITE)

	for i in Defs.MAX_PLAYERS:
		_draw_slot(i, Rect2(28 + i * 108, 80, 100, 100))

	# Einstellungen
	var rows := [
		"Siege zum Match:  %d" % WIN_OPTIONS[win_idx],
		"Rundenzeit:  %s" % _fmt_time(TIME_OPTIONS[time_idx]),
	]
	for k in 2:
		var y := 200 + k * 16
		var sel := k == setting_row
		var col := Color("ffd040") if sel else Color("a0a0b0")
		var line: String = rows[k]
		if sel:
			line = "<  " + line + "  >"
		Art.text(self, Vector2(240, y), line, 12, col)

	var footer := "A: mitmachen / bereit     B: zurück     Joystick: Einstellungen"
	if start_t > 0.0:
		footer = "Start in %d …" % ceili(start_t)
	elif joined.count(true) == 1:
		footer = "Mindestens 2 Spieler nötig"
	Art.text(self, Vector2(240, 246), footer, 10, Color.WHITE)
	var names := []
	for d in Input.get_connected_joypads():
		names.append("%d=%s" % [d, Input.get_joy_name(d).left(14)])
	var info := "Controller: %d %s" % [names.size(), " ".join(names)]
	if Controls.last_raw != "":
		info += "   ·   " + Controls.last_raw
	Art.text(self, Vector2(464, 262), info, 8, Color("808090"), HORIZONTAL_ALIGNMENT_RIGHT, 440)


func _draw_slot(i: int, r: Rect2) -> void:
	var pcol: Color = Defs.PLAYER_COLORS[i]
	draw_rect(r, Color("16161f", 0.9))
	draw_rect(r, pcol if joined[i] else Color("404050"), false, 1.0)
	var feet := r.position + Vector2(r.size.x / 2, 66)
	var moving: bool = is_ready[i]
	draw_set_transform(feet, 0.0, Vector2(2, 2))
	Art.bomber(self, Vector2.ZERO, i, Vector2i.DOWN, anim_t, moving,
		Color.WHITE if joined[i] else Color(0.3, 0.3, 0.35))
	draw_set_transform(Vector2.ZERO)
	Art.text(self, r.position + Vector2(r.size.x / 2, 14), Defs.PLAYER_NAMES[i], 12,
		pcol if i != 1 else Color("9090a8"))
	var status := ""
	var col := Color.WHITE
	if is_ready[i]:
		status = "BEREIT!"
		col = Color("60f060")
	elif joined[i]:
		status = "A: bereit"
		col = Color("ffd040")
	elif int(anim_t * 2.0) % 2 == 0:
		status = "A drücken"
		col = Color("a0a0b0")
	Art.text(self, r.position + Vector2(r.size.x / 2, r.size.y - 8), status, 10, col)
	var dbg := Controls.debug_text(i)
	Art.text(self, r.position + Vector2(r.size.x / 2, r.size.y + 9), dbg, 8,
		Color("60f060") if dbg.contains(" ok") else Color("f06060"))


static func _fmt_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
