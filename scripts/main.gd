extends Node
## Einstiegspunkt: wechselt zwischen Lobby und Match.

var _current: Node


func _ready() -> void:
	randomize()
	Controls.setup()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	# Auf dem Tablet direkt im Vollbild starten; "-- --windowed" startet im Fenster.
	if not OS.has_feature("editor") and not OS.get_cmdline_user_args().has("--windowed"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_show_lobby()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			var bot := preload("res://scripts/autotest.gd").new()
			bot.duration = float(arg.trim_prefix("--autotest="))
			add_child(bot)


func _input(event: InputEvent) -> void:
	Controls.log_raw(event)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _switch_to(node: Node) -> void:
	if _current:
		_current.queue_free()
	_current = node
	add_child(node)
	move_child(node, 0)


func _show_lobby() -> void:
	var lobby := Lobby.new()
	lobby.start_requested.connect(_on_start_requested)
	_switch_to(lobby)


func _on_start_requested(participants: Array[int], wins_needed: int, round_time: float) -> void:
	var game := Game.new()
	game.setup(participants, wins_needed, round_time)
	game.match_finished.connect(func(_winner: int) -> void: _show_lobby.call_deferred())
	_switch_to(game)
