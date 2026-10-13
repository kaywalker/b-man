class_name Art
## Zeichenroutinen für alle Spielgrafiken (keine Bilddateien nötig).

const FLOOR_A := Color("3c8c3c")
const FLOOR_B := Color("368236")
const FLOOR_SHADOW := Color(0, 0, 0, 0.28)
const HARD_BASE := Color("8c8c9c")
const HARD_LIGHT := Color("d0d0dc")
const HARD_DARK := Color("4c4c5c")
const SOFT_BASE := Color("c8783c")
const SOFT_LIGHT := Color("eca464")
const SOFT_DARK := Color("6c3818")
const SKIN := Color("f8b8a0")
const FLAME_OUT := Color("f05010")
const FLAME_MID := Color("f8b020")
const FLAME_IN := Color("fff8d0")


static func font() -> Font:
	return ThemeDB.fallback_font


static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, width := -1.0, outline := Color.BLACK) -> void:
	## pos ist die Grundlinie; bei zentrierter Ausrichtung die Mitte (width wird dann gesetzt).
	var f := font()
	var p := pos
	var w := width
	if align == HORIZONTAL_ALIGNMENT_CENTER and width < 0:
		w = 480.0
		p.x -= w / 2.0
	if outline.a > 0:
		ci.draw_string_outline(f, p, s, align, w, size, maxi(2, size / 5), outline)
	ci.draw_string(f, p, s, align, w, size, color)


static func floor_tile(ci: CanvasItem, r: Rect2, cell: Vector2i, shadow: bool) -> void:
	ci.draw_rect(r, FLOOR_A if (cell.x + cell.y) % 2 == 0 else FLOOR_B)
	if shadow:
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), FLOOR_SHADOW)


static func hard_block(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, HARD_DARK)
	ci.draw_rect(Rect2(r.position, r.size - Vector2(1, 1)), HARD_LIGHT)
	ci.draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), HARD_BASE)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 2, 2), Vector2(1, r.size.y - 3)), HARD_DARK)
	ci.draw_rect(Rect2(r.position + Vector2(2, r.size.y - 2), Vector2(r.size.x - 3, 1)), HARD_DARK)


static func soft_block(ci: CanvasItem, r: Rect2, burn := -1.0) -> void:
	## burn: -1 = normal, sonst 1..0 verbleibende Brenndauer (Anteil).
	if burn >= 0.0:
		var flick := 0.5 + 0.5 * sin(burn * 60.0)
		var inset := (1.0 - burn) * 5.0
		var rr := r.grow(-inset)
		ci.draw_rect(rr, SOFT_DARK.lerp(FLAME_OUT, flick))
		ci.draw_rect(rr.grow(-2), FLAME_MID.lerp(FLAME_IN, flick * burn))
		return
	ci.draw_rect(r, SOFT_DARK)
	var x := r.position.x
	var y := r.position.y
	# Zwei Ziegelreihen mit versetzten Fugen.
	for row in 2:
		var ry := y + 1 + row * 8
		var offs := 0 if row == 0 else 4
		for b in [-1, 0, 1]:
			var bx: float = x + offs + b * 8 + 1
			var br := Rect2(bx, ry, 7, 6).intersection(Rect2(x + 1, y + 1, 14, 14))
			if br.size.x <= 0:
				continue
			ci.draw_rect(br, SOFT_BASE)
			ci.draw_rect(Rect2(br.position, Vector2(br.size.x, 1)), SOFT_LIGHT)


static func bomb(ci: CanvasItem, c: Vector2, t: float, remote: bool) -> void:
	var pulse := 1.0 + 0.1 * sin(t * 14.0)
	var r := 6.0 * pulse
	ci.draw_circle(c + Vector2(0, 5), 5.0, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, r, Color("101018"))
	if remote:
		ci.draw_rect(Rect2(c.x - r * 0.8, c.y - 1, r * 1.6, 2), Color("e03030"))
	ci.draw_circle(c + Vector2(-2, -2) * pulse, 1.6, Color(1, 1, 1, 0.75))
	# Zündschnur mit Funke.
	ci.draw_line(c + Vector2(2, -5) * pulse, c + Vector2(4, -8), Color("c8a060"), 1.0)
	var spark := Color("fff060") if int(t * 20.0) % 2 == 0 else Color("ff8020")
	ci.draw_circle(c + Vector2(4, -8), 1.5, spark)


static func flame(ci: CanvasItem, c: Vector2, arms: int, center: bool, life: float) -> void:
	## arms: Bitmaske 1=links 2=rechts 4=oben 8=unten; life: 1 (frisch) .. 0 (verlöscht).
	var s := clampf(minf((1.0 - life) * 8.0, life * 3.0), 0.15, 1.0)
	var widths := [14.0 * s, 9.0 * s, 4.0 * s]
	var cols := [FLAME_OUT, FLAME_MID, FLAME_IN]
	for k in 3:
		var w: float = widths[k]
		var col: Color = cols[k]
		if arms & 1:
			ci.draw_rect(Rect2(c.x - 8, c.y - w / 2, 8, w), col)
		if arms & 2:
			ci.draw_rect(Rect2(c.x, c.y - w / 2, 8, w), col)
		if arms & 4:
			ci.draw_rect(Rect2(c.x - w / 2, c.y - 8, w, 8), col)
		if arms & 8:
			ci.draw_rect(Rect2(c.x - w / 2, c.y, w, 8), col)
		ci.draw_circle(c, w / 2.0 + (2.0 * s if center else 0.0), col)


static func item(ci: CanvasItem, r: Rect2, kind: int, t: float) -> void:
	var bg: Color
	match kind:
		Defs.Item.SKULL:
			bg = Color("7030a0")
		Defs.Item.FULL_FIRE:
			bg = Color("e0b020")
		Defs.Item.KICK, Defs.Item.REMOTE:
			bg = Color("2878d0")
		_:
			bg = Color("d83030")
	var blink := 0.85 + 0.15 * sin(t * 8.0)
	ci.draw_rect(r.grow(-1), Color("202020"))
	ci.draw_rect(r.grow(-2), bg * blink)
	ci.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 1)), Color(1, 1, 1, 0.5))
	item_icon(ci, r.get_center(), kind)


static func item_icon(ci: CanvasItem, c: Vector2, kind: int) -> void:
	match kind:
		Defs.Item.BOMB, Defs.Item.REMOTE:
			ci.draw_circle(c + Vector2(0, 1), 4.0, Color("101018"))
			ci.draw_circle(c + Vector2(-1.5, -0.5), 1.0, Color(1, 1, 1, 0.8))
			ci.draw_line(c + Vector2(2, -2), c + Vector2(3, -5), Color("fff060"), 1.0)
			if kind == Defs.Item.REMOTE:
				ci.draw_rect(Rect2(c.x - 4, c.y, 8, 2), Color("f03030"))
		Defs.Item.FIRE, Defs.Item.FULL_FIRE:
			var pts := PackedVector2Array([c + Vector2(0, -6), c + Vector2(4, 0), c + Vector2(3, 4),
				c + Vector2(-3, 4), c + Vector2(-4, 0), c + Vector2(-1, -2)])
			ci.draw_colored_polygon(pts, FLAME_OUT)
			ci.draw_circle(c + Vector2(0, 2), 2.2, FLAME_IN)
		Defs.Item.SPEED:
			# Rollschuh
			ci.draw_rect(Rect2(c.x - 3, c.y - 5, 4, 6), Color("f0f0f0"))
			ci.draw_rect(Rect2(c.x - 3, c.y, 8, 2), Color("f0f0f0"))
			ci.draw_circle(c + Vector2(-2, 4), 1.4, Color("202020"))
			ci.draw_circle(c + Vector2(3, 4), 1.4, Color("202020"))
		Defs.Item.KICK:
			# Stiefel
			ci.draw_rect(Rect2(c.x - 3, c.y - 5, 4, 7), Color("8a4a20"))
			ci.draw_rect(Rect2(c.x - 3, c.y + 1, 8, 3), Color("8a4a20"))
			ci.draw_rect(Rect2(c.x - 3, c.y + 4, 8, 1), Color("301808"))
		Defs.Item.SKULL:
			ci.draw_circle(c + Vector2(0, -1), 4.5, Color("f0f0f0"))
			ci.draw_rect(Rect2(c.x - 2.5, c.y + 2, 5, 3), Color("f0f0f0"))
			ci.draw_rect(Rect2(c.x - 3, c.y - 2, 2, 2), Color("202020"))
			ci.draw_rect(Rect2(c.x + 1, c.y - 2, 2, 2), Color("202020"))


static func bomber(ci: CanvasItem, feet: Vector2, idx: int, facing: Vector2i, walk: float,
		moving: bool, tint := Color.WHITE) -> void:
	## Zeichnet einen Bomberman; feet = Mitte zwischen den Füßen.
	var head_col: Color = Defs.PLAYER_COLORS[idx] * tint
	var suit_col: Color = Defs.PLAYER_SUITS[idx] * tint
	var skin := SKIN * tint
	var dark := Color("181820") * tint
	var step := sin(walk * 14.0) if moving else 0.0
	var bob := absf(step) * -1.0 if moving else 0.0
	var f := feet + Vector2(0, bob)

	ci.draw_rect(Rect2(feet.x - 6, feet.y - 1, 12, 3), Color(0, 0, 0, 0.3))
	# Füße
	var lf := -1.0 if step > 0.3 else 0.0
	var rf := -1.0 if step < -0.3 else 0.0
	ci.draw_rect(Rect2(feet.x - 5, feet.y - 3 + lf, 4, 3), suit_col.darkened(0.3))
	ci.draw_rect(Rect2(feet.x + 1, feet.y - 3 + rf, 4, 3), suit_col.darkened(0.3))
	# Körper
	ci.draw_rect(Rect2(f.x - 4, f.y - 10, 8, 7), suit_col)
	ci.draw_rect(Rect2(f.x - 4, f.y - 6, 8, 1), dark)
	# Hände
	var hs := step * 1.5
	ci.draw_circle(f + Vector2(-5, -7 + hs), 1.6, skin)
	ci.draw_circle(f + Vector2(5, -7 - hs), 1.6, skin)
	# Kopf
	var h := f + Vector2(0, -15)
	ci.draw_circle(h, 6.0, head_col.darkened(0.25))
	ci.draw_circle(h + Vector2(0, -0.5), 5.5, head_col)
	ci.draw_line(h + Vector2(0, -6), h + Vector2(0, -8), dark, 1.0)
	ci.draw_circle(h + Vector2(0, -9), 1.6, skin)
	# Gesicht je nach Blickrichtung
	if facing.y >= 0 or facing.x != 0:
		var fx := facing.x * 2.0
		ci.draw_rect(Rect2(h.x - 4 + fx, h.y - 2, 8 - absf(fx), 5), skin)
		ci.draw_rect(Rect2(h.x - 2 + fx * 1.2, h.y - 1, 1, 3), dark)
		ci.draw_rect(Rect2(h.x + 1 + fx * 1.2, h.y - 1, 1, 3), dark)
