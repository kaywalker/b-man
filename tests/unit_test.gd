extends SceneTree
## Unit-Tests ohne Grafik: godot --headless --path . -s tests/unit_test.gd

var _failed := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("ok    ", what)
	else:
		_failed += 1
		printerr("FAIL  ", what)


func _initialize() -> void:
	# Knöpfe wie am Büro-Tisch: Knopf 1 = B, alles andere (z. B. 3 vom Prototyp) = A.
	_check(Controls.counts_as_a(0), "Knopf 0 ist A")
	_check(Controls.counts_as_a(3), "Knopf 3 (Prototyp) ist A")
	_check(not Controls.counts_as_a(JOY_BUTTON_B), "Knopf 1 ist nicht A")
	_check(not Controls.counts_as_a(JOY_BUTTON_DPAD_UP), "D-Pad ist nicht A")
	_check(Controls.DEFAULT_PADS == [1, 0, 2, 3], "Pad-Zuordnung 1, 0, 2, 3")

	# "Vom Spieler weg" zeigt vom eigenen Bildschirmrand weg (y nach oben).
	var away := Vector2(0, 1)
	_check(Controls._to_screen(away, Controls.Side.BOTTOM) == Vector2(0, 1), "unten: weg = nach oben")
	_check(Controls._to_screen(away, Controls.Side.TOP) == Vector2(0, -1), "oben: weg = nach unten")
	_check(Controls._to_screen(away, Controls.Side.RIGHT) == Vector2(-1, 0), "rechts: weg = nach links")
	_check(Controls._to_screen(away, Controls.Side.LEFT) == Vector2(1, 0), "links: weg = nach rechts")

	# Jede Startecke liegt im Spielfeld und auf keiner Säule.
	for c: Vector2i in Defs.START_CELLS:
		var inside := c.x > 0 and c.y > 0 and c.x < Defs.GRID_W - 1 and c.y < Defs.GRID_H - 1
		_check(inside and not (c.x % 2 == 0 and c.y % 2 == 0), "Startfeld %s frei" % c)

	print("%d Fehler" % _failed)
	quit(1 if _failed > 0 else 0)
