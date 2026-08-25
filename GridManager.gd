extends Node
# GridManager.gd (autoload)

var cell_size: float = 1.0
var occupied: Dictionary = {}   # Vector3i -> node name, server-only truth

# Whitelist of furniture the client is allowed to place.
const ALLOWED := {
	"res://furniture/Chair.tscn": true,
	"res://furniture/table.tscn": true,
	"res://furniture/lamp.tscn": true,
}

@rpc("any_peer", "reliable")
func request_place(scene_path: String, cell: Vector3i, rot_steps: int) -> void:
	if not multiplayer.is_server():
		return
	# --- validation: never trust the client ---
	if not ALLOWED.has(scene_path):
		return
	if occupied.has(cell):
		return                                  # cell already taken
	if abs(cell.x) > 100 or abs(cell.z) > 100:  # sane world bounds
		return

	var furniture: Node3D = (load(scene_path) as PackedScene).instantiate()
	furniture.name = "f_%d_%d" % [cell.x, cell.z]
	furniture.position = cell_to_world(cell, cell_size)
	furniture.rotation.y = deg_to_rad(90 * rot_steps)
	# MultiplayerSpawner replicates this to every client automatically.
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
