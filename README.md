# GodotSteam-Template-3D
A template that jumpstarts the GodotSteam addon to a playable state 

A minimal 3D multiplayer template for Godot 4 that lets up to 4 players join a shared
world through Steam. Networking runs over Steam Datagram Relay (SDR), so players connect
to each other by Steam ID instead of raw IP addresses. Real IP addresses are never
exchanged between players, which protects them from IP-based attacks such as DDoS.

The template includes first person movement with mouse look and WASD, player spawning
and position synchronization, a Steam lobby capped at 4 players, an in game pause menu
with an invite button, and a server authoritative grid based system for placing furniture.

## What you need before running

1. Godot 4.7 stable (or a close 4.x version).
2. The GodotSteam GDExtension installed in the project (the `addons/godotsteam` folder).
3. The Steam client installed, running, and logged in on every machine that will play.
4. A `steam_appid.txt` file in the project root containing a valid Steam App ID. During
   development this is `480`, which is Valve's public Spacewar test ID.

## Important notes about the test App ID (480)

The template ships configured for App ID 480 so you can test without paying anything.
Two limitations come with that test ID, and both disappear once you own a real App ID:

The in game Steam overlay (used by the "Invite Friend" button) does not reliably appear
when you launch from the Godot editor or by double clicking the executable. The overlay
only injects when the game is launched through the Steam client. To make it work, export
the game, add the exported executable to Steam as a Non Steam Game, and launch it from
your Steam library. Selecting the Compatibility renderer instead of Forward Plus also
raises the chance the overlay appears.

Because of the overlay limitation, the most reliable way to invite someone while testing
on 480 is Steam's own friends list. Have your friend right click your name in their Steam
friends list and choose Join Game. That path does not depend on the in game overlay and
works where the invite button may not.

A real App ID (obtained through Steam Direct) removes both quirks. Buy it when you are
ready to ship, not merely to test.

## How to run and play

You cannot run this through the Godot editor and expect the Steam overlay to work, and the
overlay is what you need to invite and join. The reliable way to play is to export the game
and launch it through Steam as a Non Steam Game.

What you need to test with two players. Steam allows only one active session per account, so
you need two Steam accounts. That means either two separate devices each logged into a
different Steam account, or one device plus a virtual machine, with a different account on
each. One account on one machine cannot join itself.

Setup steps.

1. Export the game. In Godot open Project, Export, add a Windows Desktop preset if you do
   not have one, and export the project to a folder. Copy steam_appid.txt (containing 480)
   into that same folder next to the executable.
2. Add the exported executable to Steam. In Steam open Games, Add a Non Steam Game to My
   Library, Browse, and select your exported executable. It does not matter that the game
   still runs under App ID 480 (Spacewar) or that the name in Steam looks different. What
   matters is that launching it through the Non Steam Games entry makes the Steam overlay
   appear, and the overlay is what you need to invite and join.
3. Do the same on the second account's machine or virtual machine, so both sides launch
   through Steam.

Playing.

1. Make sure Steam is running and logged in on both machines.
2. Launch the game from your Steam library on both machines.
3. On the host machine, click Host Game. You spawn into the world as the first player.
4. Invite the second player through Steam. Because the game was launched through Steam, the
   overlay works, so the invite reaches the other account. Pressing Tab in game opens the
   overlay for joining or switching to another lobby.
5. The joining player spawns into the same world. Both players can now move and see each
   other in real time.

## Controls

W, A, S, D move the character relative to where the camera is facing.
The mouse looks around. The body turns left and right, the camera tilts up and down.
Space bar jumps.
Escape opens and closes the pause menu. The pause menu holds Resume, Invite Friend, and
Quit to Menu. Opening the menu frees the mouse so you can click. Resuming recaptures it.

## Placing furniture (grid build system)

Furniture placement is server authoritative, which means the host validates every
placement before it appears for everyone. A client asks to place an item, and the host
checks that the item is allowed, that the target grid cell is empty, and that the cell is
within the world bounds. Only then does the host spawn the furniture and replicate it to
all players. This prevents two players from placing furniture in the same cell and stops a
modified client from spawning anything it wants.

To add your own furniture, create a scene whose root is a StaticBody3D with a mesh and a
collision shape, save it under the furniture folder, and add its path to the ALLOWED
dictionary in GridManager. Also add it to the FurnitureSpawner's spawn list so it
replicates to everyone.

## Debugging tip: the console build

When you export for Windows, Godot also produces a second executable ending in
`.console.exe`. Running that version opens a terminal window alongside the game that shows
all print output, warnings, and errors, even when the game is launched through Steam. This
is the only practical way to read logs from a second machine that is not running the Godot
editor. Enable it under Project, Export, your Windows preset, Application, Console Wrapper.
Point Steam at the `.console.exe` when adding the game as a Non Steam Game so you get the
console when launching from Steam.

## Project structure

The project is organized around a few autoload singletons and a small set of scenes.

SteamManager initializes Steam and the SDR relay network when the game starts.
NetworkManager creates the Steam multiplayer peer for hosting and joining.
LobbyManager creates and joins Steam lobbies and handles invite acceptance.
GridManager holds the server authoritative furniture placement logic.

The main menu scene is the entry point. The game scene holds the players, the furniture,
the two spawners, the floor, and the pause menu. The player scene is the character with
its camera and synchronizer. Furniture scenes are simple static bodies.

---

# How this template was built (rebuild tutorial)

This section walks through recreating the template from an empty Godot project. Follow it
in order. Every step builds on the one before it.

## Step 1: Project and Steam setup

Create a new Godot 4.7 project. Install the GodotSteam GDExtension from the Asset Library
so the `addons/godotsteam` folder is present. Create a file named `steam_appid.txt` in the
project root containing only the number 480.

In Project Settings, open the Steam section under Initialization and set the App ID to 480
for the game, demo, tools, and playtest fields. If you enable Initialize On Startup here,
do not also initialize Steam from code, because initializing twice produces a warning.
This template initializes from code, so leave Initialize On Startup turned off.

## Step 2: SteamManager autoload

Create a script called SteamManager that initializes Steam and warms up the relay network.
The relay network call is what makes SDR ready to use. Register this script as an autoload
in Project Settings under Globals, and make sure it loads first.

    extends Node

    var is_online: bool = false

    func _init() -> void:
        OS.set_environment("SteamAppID", "480")
        OS.set_environment("SteamGameID", "480")

    func _ready() -> void:
        var response: Dictionary = Steam.steamInitEx()
        if response.status != Steam.STEAM_API_INIT_RESULT_OK:
            push_error("Steam failed to init: %s" % response.verbal)
            return
        is_online = true
        Steam.initRelayNetworkAccess()

    func _process(_delta: float) -> void:
        Steam.run_callbacks()

The run_callbacks call every frame is required. Without it, lobby and connection events
never fire.

## Step 3: NetworkManager autoload

Create a script called NetworkManager that builds the Steam multiplayer peer. Hosting
creates a host peer. Joining creates a client peer that connects to the host's Steam ID,
which is what routes the traffic through SDR. Register it as an autoload after SteamManager.

    extends Node

    func become_host() -> void:
        var peer := SteamMultiplayerPeer.new()
        peer.create_host(0)
        peer.server_relay = true
        multiplayer.multiplayer_peer = peer
        get_tree().change_scene_to_file("res://scenes/game.tscn")

    func become_client(host_steam_id: int) -> void:
        var peer := SteamMultiplayerPeer.new()
        peer.create_client(host_steam_id, 0)
        peer.server_relay = true
        multiplayer.multiplayer_peer = peer
        get_tree().change_scene_to_file("res://scenes/game.tscn")

Setting server_relay to true routes clients through the host rather than directly to each
other, which keeps the topology simple and lets clients join after the host has loaded the
game scene.

## Step 4: LobbyManager autoload

Create a script called LobbyManager that creates and joins Steam lobbies. The lobby member
limit is your player cap, so set it to 4. The join_requested signal is what makes accepting
a Steam invite actually join the lobby. Register it as an autoload after NetworkManager.

    extends Node

    const MAX_PLAYERS: int = 4
    var lobby_id: int = 0

    func _ready() -> void:
        Steam.lobby_created.connect(_on_lobby_created)
        Steam.lobby_joined.connect(_on_lobby_joined)
        Steam.join_requested.connect(_on_join_requested)

    func host_game() -> void:
        Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_PLAYERS)

    func _on_lobby_created(result: int, new_lobby_id: int) -> void:
        if result != 1:
            return
        lobby_id = new_lobby_id
        Steam.setLobbyData(lobby_id, "name", "%s's game" % Steam.getPersonaName())
        Steam.setLobbyJoinable(lobby_id, true)
        NetworkManager.become_host()

    func join_lobby(target_lobby_id: int) -> void:
        Steam.joinLobby(target_lobby_id)

    func _on_lobby_joined(this_lobby_id: int, _perm: int, _locked: bool, response: int) -> void:
        if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
            return
        lobby_id = this_lobby_id
        var owner_id: int = Steam.getLobbyOwner(this_lobby_id)
        if owner_id != Steam.getSteamID():
            NetworkManager.become_client(owner_id)

    func _on_join_requested(this_lobby_id: int, _friend_id: int) -> void:
        Steam.joinLobby(this_lobby_id)

## Step 5: The player scene

Create a scene whose root is a CharacterBody3D named Player. Add these children: a
MeshInstance3D with a capsule mesh so the player is visible, a CollisionShape3D with a
matching capsule shape, a Camera3D positioned at eye height (around 0, 1.5, 0 for first
person), and a MultiplayerSynchronizer.

Select the MultiplayerSynchronizer and open the Replication panel at the bottom of the
editor (not the Inspector on the right). Add two properties to sync: the position and the
rotation. Make sure the Sync option is enabled for both so they update every frame rather
than only at spawn.

Attach this script to the Player root. The most important detail is that the synchronizer's
authority must match the player's authority, otherwise the host overwrites every client's
position every frame and clients appear frozen.

    extends CharacterBody3D

    const SPEED := 5.0
    const JUMP_VELOCITY := 4.5
    const MOUSE_SENSITIVITY := 0.003
    const GRAVITY := 9.8

    var pitch := 0.0

    func _ready() -> void:
        $MultiplayerSynchronizer.set_multiplayer_authority(get_multiplayer_authority())
        if is_multiplayer_authority():
            $Camera3D.make_current()
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

    func _unhandled_input(event: InputEvent) -> void:
        if not is_multiplayer_authority():
            return
        if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
            pitch = clamp(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.4, 1.4)
            $Camera3D.rotation.x = pitch

    func _physics_process(delta: float) -> void:
        if not is_multiplayer_authority():
            return
        if not is_on_floor():
            velocity.y -= GRAVITY * delta
        if Input.is_action_just_pressed("jump") and is_on_floor():
            velocity.y = JUMP_VELOCITY
        var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
        var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
        if direction:
            velocity.x = direction.x * SPEED
            velocity.z = direction.z * SPEED
        else:
            velocity.x = move_toward(velocity.x, 0, SPEED)
            velocity.z = move_toward(velocity.z, 0, SPEED)
        move_and_slide()

## Step 6: Input actions

In Project Settings under Input Map, create five actions and bind them: move_forward to W,
move_back to S, move_left to A, move_right to D, and jump to Space.

## Step 7: The game scene

Create a 3D scene with a Node3D root named NetworkGame. Add these children: a Node3D named
Players, a MultiplayerSpawner named PlayerSpawner, a Node3D named Furniture, a
MultiplayerSpawner named FurnitureSpawner, a StaticBody3D named Floor with a mesh and a
collision shape so players have ground to stand on, and a DirectionalLight3D so the scene
is lit.

Select PlayerSpawner and set its Spawn Path to point at the Players node. Because this
template sets authority explicitly through a custom spawn function, you do not also list
the player in the Auto Spawn List. Select FurnitureSpawner, set its Spawn Path to the
Furniture node, and add your furniture scene to its spawn list.

Attach this script to the NetworkGame root. It spawns the host immediately and spawns each
client when they connect. The custom spawn function runs on every peer and sets authority
explicitly, which avoids the timing problems that come from relying on the node name alone.

    extends Node3D

    @export var player_scene: PackedScene
    var _players := {}

    func _ready() -> void:
        $PlayerSpawner.spawn_function = _spawn_player
        if not multiplayer.is_server():
            return
        multiplayer.peer_connected.connect(_on_peer_connected)
        multiplayer.peer_disconnected.connect(_remove_player)
        _add_player(1)

    func _on_peer_connected(id: int) -> void:
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
        var sync := p.get_node("MultiplayerSynchronizer")
        sync.set_multiplayer_authority(id)
        return p

    func _remove_player(id: int) -> void:
        _players.erase(id)
        if $Players.has_node(str(id)):
            $Players.get_node(str(id)).queue_free()

After attaching the script, select the NetworkGame root and drag the player scene into the
Player Scene slot that appears at the top of the Inspector. Save the scene. If you assign
this while the game is running, the assignment is lost, so assign it while stopped.

## Step 8: The main menu

Create a User Interface scene with a Control root named MainMenu. Add a VBoxContainer with
a button named HostButton and, optionally, a button for inviting. Attach this script and
set this scene as the main scene in Project Settings under Application, Run.

    extends Control

    func _ready() -> void:
        $VBoxContainer/HostButton.pressed.connect(_on_host)

    func _on_host() -> void:
        LobbyManager.host_game()

## Step 9: The pause menu

Create a User Interface scene with a Control root named PauseMenu set to Full Rect. Add a
semi transparent ColorRect for a dimmed background and a centered VBoxContainer with three
buttons: Resume, Invite Friend, and Quit to Menu. Attach this script and instance the pause
menu as a child of the NetworkGame root in the game scene.

    extends Control

    func _ready() -> void:
        hide()
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
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

    func _on_resume() -> void:
        hide()
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

    func _on_invite() -> void:
        if LobbyManager.lobby_id != 0:
            Steam.activateGameOverlayInviteDialog(LobbyManager.lobby_id)

    func _on_quit() -> void:
        if multiplayer.multiplayer_peer:
            multiplayer.multiplayer_peer.close()
        get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

Note that this menu does not pause the game with the scene tree, because pausing only one
player's game in multiplayer causes desync. It is an overlay that frees the mouse for
clicking while the world keeps running.

## Step 10: The furniture and grid system

Create at least one furniture scene with a StaticBody3D root, a mesh, and a collision shape.
Save it under the furniture folder and add it to the FurnitureSpawner spawn list in the game
scene.

Create a GridManager script and register it as an autoload. It holds a whitelist of allowed
furniture, a dictionary of occupied cells that only the server trusts, and two RPCs for
placing and removing furniture. The server validates every request before spawning.

    extends Node

    var cell_size: float = 1.0
    var occupied: Dictionary = {}

    const ALLOWED := {
        "res://furniture/chair.tscn": true,
    }

    @rpc("any_peer", "reliable")
    func request_place(scene_path: String, cell: Vector3i, rot_steps: int) -> void:
        if not multiplayer.is_server():
            return
        if not ALLOWED.has(scene_path):
            return
        if occupied.has(cell):
            return
        if abs(cell.x) > 100 or abs(cell.z) > 100:
            return
        var furniture: Node3D = (load(scene_path) as PackedScene).instantiate()
        furniture.name = "f_%d_%d" % [cell.x, cell.z]
        furniture.position = cell_to_world(cell, cell_size)
        furniture.rotation.y = deg_to_rad(90 * rot_steps)
        get_node("/root/NetworkGame/Furniture").add_child(furniture, true)
        occupied[cell] = furniture.name

    @rpc("any_peer", "reliable")
    func request_remove(cell: Vector3i) -> void:
        if not multiplayer.is_server():
            return
        if not occupied.has(cell):
            return
        var container := get_node("/root/NetworkGame/Furniture")
        if container.has_node(occupied[cell]):
            container.get_node(occupied[cell]).queue_free()
        occupied.erase(cell)

    func world_to_cell(pos: Vector3, size: float) -> Vector3i:
        return Vector3i(round(pos.x / size), 0, round(pos.z / size))

    func cell_to_world(cell: Vector3i, size: float) -> Vector3:
        return Vector3(cell.x * size, 0.0, cell.z * size)

A build controller on the player raycasts from the camera to the floor, snaps the hit point
to a grid cell, shows a translucent ghost of the furniture, and on click sends
request_place to the server with rpc_id targeting peer 1. The client never places furniture
directly. It only asks, and the server decides.

## The core lessons from building this

Two ideas explain almost everything above.

The first is that SDR comes for free when you connect by Steam ID through the Steam
multiplayer peer, so hiding player IP addresses costs no extra work once you use lobbies
and Steam IDs instead of raw addresses.

The second is that authority must be correct at every level. The player node needs the
right authority, and so does its synchronizer child. When only the player node has correct
authority but the synchronizer does not, the server overwrites every client's position each
frame, which makes remote players appear frozen while local input seems to control the
wrong character. Setting the synchronizer's authority to match the player is the single
change that makes two way movement work.
