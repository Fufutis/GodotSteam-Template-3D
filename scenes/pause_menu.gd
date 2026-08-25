extends Control
class_name PauseMenu

# The player reads this to know when to freeze. This is the only thing
# added beyond the original working menu, and the player needs it.
static var is_open := false

func _ready() -> void:
	hide()
	is_open = false
	$VBoxContainer/ResumeButton.pressed.connect(_on_resume)
	$VBoxContainer/InviteButton.pressed.connect(_on_invite)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_on_resume()
		else:
			_open()

func _open() -> void:
	show()
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_resume() -> void:
	hide()
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_invite() -> void:
	if LobbyManager.lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(LobbyManager.lobby_id)

func _on_quit() -> void:
	# Reset state so the next session isn't stuck "paused".
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Cleanly drop the network connection before leaving.
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/mainmenu.tscn")
