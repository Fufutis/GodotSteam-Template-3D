extends Node

func become_host() -> void:
	var peer := SteamMultiplayerPeer.new()
	peer.create_host(0)
	peer.server_relay = true          # route clients through host, not peer-to-peer
	multiplayer.multiplayer_peer = peer
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func become_client(host_steam_id: int) -> void:
	var peer := SteamMultiplayerPeer.new()
	peer.create_client(host_steam_id, 0)   # connect by Steam ID → SDR relayed
	peer.server_relay = true
	multiplayer.multiplayer_peer = peer
	get_tree().change_scene_to_file("res://scenes/game.tscn")
