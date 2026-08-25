extends Node

var is_online: bool = false

func _init() -> void:
	# Spacewar test app id; replace 480 with your real app id later.
	OS.set_environment("SteamAppID", "480")
	OS.set_environment("SteamGameID", "480")

func _ready() -> void:
	var response: Dictionary = Steam.steamInitEx()
	if response.status != Steam.STEAM_API_INIT_RESULT_OK:
		push_error("Steam failed to init: %s" % response.verbal)
		return
	is_online = true
	# THIS is the line that warms up the SDR relay network.
	Steam.initRelayNetworkAccess()

func _process(_delta: float) -> void:
	Steam.run_callbacks()
