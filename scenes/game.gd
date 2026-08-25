extends Node3D

@export var player_scene: PackedScene
var _players := {}   # id -> true, server tracks who exists

func _ready() -> void:
	$PlayerSpawner.spawn_function = _spawn_player
	if not multiplayer.is_server():
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_remove_player)
	_add_player(1)   # host itself

func _on_peer_connected(id: int) -> void:
	# A new client connected: spawn them. Because they're now connected,
	# the spawner will also replicate all EXISTING players to them.
	_add_player(id)

func _add_player(id: int) -> void:
	if _players.has(id):
		return
	_players[id] = true
	$PlayerSpawner.spawn(id)

func _spawn_player(data) -> Node:
	var id: int = data
	var p := player_scene.instantiate()
	p.name = str(id)
	p.set_multiplayer_authority(id)
	# Set the synchronizer authority up front too.
	var sync := p.get_node("MultiplayerSynchronizer")
	sync.set_multiplayer_authority(id)
	return p

func _remove_player(id: int) -> void:
	_players.erase(id)
	if $Players.has_node(str(id)):
		$Players.get_node(str(id)).queue_free()
