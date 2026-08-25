extends Control

func _ready() -> void:
	$VBoxContainer/HostButton.pressed.connect(_on_host)

func _on_host() -> void:
	LobbyManager.host_game()
