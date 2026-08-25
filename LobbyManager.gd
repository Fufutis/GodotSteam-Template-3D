extends Node

const MAX_PLAYERS: int = 4
var lobby_id: int = 0

func _ready() -> void:
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.join_requested.connect(_on_join_requested)

# --- Host a session ---
func host_game() -> void:
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_PLAYERS)

func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	print(">>> LOBBY CREATED. result=", result, " id=", new_lobby_id)
	if result != 1:
		return
	lobby_id = new_lobby_id
	Steam.setLobbyData(lobby_id, "name", "%s's game" % Steam.getPersonaName())
	Steam.setLobbyJoinable(lobby_id, true)
	NetworkManager.become_host()

# Fired when a friend accepts your Steam invite / clicks "Join Game"
func _on_join_requested(this_lobby_id: int, _friend_id: int) -> void:
	Steam.joinLobby(this_lobby_id)
	
# --- Join an existing session ---
func join_lobby(target_lobby_id: int) -> void:
	Steam.joinLobby(target_lobby_id)

func _on_lobby_joined(this_lobby_id: int, _perm: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		return
	lobby_id = this_lobby_id
	var owner_id: int = Steam.getLobbyOwner(this_lobby_id)
	if owner_id != Steam.getSteamID():
		NetworkManager.become_client(owner_id)
