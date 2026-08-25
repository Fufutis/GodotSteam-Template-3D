extends CharacterBody3D

# Synced so remote players know when to wobble.
@export var is_moving := false

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var tilt_upper_limit := PI / 3.0
@export var tilt_lower_limit := -PI / 8.0

@export_group("Movement")
@export var move_speed := 8.0
@export var acceleration := 20.0
@export var jump_velocity := 6.0

@export_group("Wobble")
@export var wobble_amount := 0.20     # 20% stretch/squash
@export var wobble_speed := 10.0      # how fast it eases in/out when starting/stopping
@export var wobble_period := 0.45      # seconds for one full wobble cycle

var _camera_input_direction := Vector2.ZERO
var _wobble := 0.0                    # 0 = idle, 1 = fully moving
var _wobble_time := 0.0               # advances while moving, drives the cycle

@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D
@onready var _synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	_synchronizer.set_multiplayer_authority(get_multiplayer_authority())
	if is_multiplayer_authority():
		_camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_camera.current = false

func _input(event: InputEvent) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if not is_multiplayer_authority():
		return
	if PauseMenu.is_open:
		return
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if not is_multiplayer_authority():
		return
	if PauseMenu.is_open:
		return
	var is_camera_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity


func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if not is_multiplayer_authority():
		return

	# While paused: stop moving but still apply gravity so you don't float.
	if PauseMenu.is_open:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		return

	_camera_pivot.rotation.x -= _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, tilt_lower_limit, tilt_upper_limit)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO

	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x
	var move_direction := forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0
	move_direction = move_direction.normalized()

	var horizontal_velocity := velocity.move_toward(move_direction * move_speed, acceleration * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	# Gravity.
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	# Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()
	is_moving = raw_input.length() > 0.1


func _process(delta: float) -> void:
	if _mesh == null:
		return
	_update_wobble(delta)

func _update_wobble(delta: float) -> void:
	# Runs on ALL players (local and remote), driven by the synced is_moving flag.
	var target := 1.0 if is_moving else 0.0
	_wobble = move_toward(_wobble, target, wobble_speed * delta)

	if is_moving:
		_wobble_time += delta
	else:
		_wobble_time = 0.0

	var cycle := sin(_wobble_time * (TAU / wobble_period))
	var pulse: float = abs(cycle) * _wobble
	var stretch: float = 1.0 + wobble_amount * pulse
	var squash: float = 1.0 - wobble_amount * pulse
	_mesh.scale = Vector3(squash, stretch, squash)
