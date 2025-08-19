extends CharacterBody3D

# ------------------------------------------------------------------------------
# CONSTANTS AND CONFIGURATION
# ------------------------------------------------------------------------------
const WALK_SPEED: float = 5.0          # Base movement speed
const SPRINT_SPEED: float = 8.0         # Sprint movement speed  
const JUMP_VELOCITY: float = 4.5        # Upward velocity for jumping
const MOUSE_SENSITIVITY: float = 0.002  # Mouse look sensitivity
const GRAVITY: float = 9.8              # Gravity acceleration

# Ball throwing constants
const MAX_HOLD_TIME: float = 1.5        # Maximum hold time in seconds
const MAX_FORCE: float = 35.0           # Maximum force to apply
const MIN_FORCE: float = 3.0            # Minimum force to apply

# ------------------------------------------------------------------------------
# VARIABLES
# ------------------------------------------------------------------------------
var direction: Vector3 = Vector3.ZERO   # Current movement direction
var lerp_speed: float = 10.0            # Speed of movement interpolation
var is_mouse_captured: bool = true      # Whether mouse is captured for look

# Ball throwing variables
var is_holding_mouse: bool = false      # Whether left mouse is being held
var mouse_hold_start_time: float = 0.0  # When mouse hold started
var ball_in_range: RigidBody3D = null   # Reference to ball in Area3D

var display_name = ""
var network_manager
var is_server = false

# Node references
@onready var head = $Head               # Camera head node for mouse look
@onready var label: Label = $Control/Label
@onready var name_label: Label3D = $Label3D
@onready var camera_3d: Camera3D = $Head/Camera3D
@onready var area_3d: Area3D = $Area3D
@onready var audio_node: Node3D = $AudioNode
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var mesh: MeshInstance3D = $CollisionShape3D/MeshInstance3D

@onready var kick_force_bar: TextureProgressBar = $TextureProgressBar
@onready var ball_there: MeshInstance2D = $TextureProgressBar/BallThere

# ------------------------------------------------------------------------------
# INITIALIZATION
# ------------------------------------------------------------------------------
func _ready() -> void:
	sync.set_multiplayer_authority(name.to_int())  # Match your player authority

	print("READY")
	# Add to players group for voice chat system
	add_to_group("players")
	
	audio_node.setupAudio(multiplayer.get_unique_id())
	
	if not is_multiplayer_authority():
		kick_force_bar.queue_free()
		label.queue_free()
		return
	
	kick_force_bar.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_3d.current = true
	print("READY2")

func _set_name(name):
	name_label.text = name

func _enter_tree():
	print("ENTER TREE")
	set_multiplayer_authority(name.to_int())
	
	if name == "1":
		is_server = true
		
	network_manager = get_node("../../../NetworkManager")

# ------------------------------------------------------------------------------
# INPUT HANDLING
# ------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
		
	_handle_mouse_look(event)
	_handle_ball_interaction(event)
	_handle_pause_input(event)

func _handle_mouse_look(event: InputEvent) -> void:
	"""Process mouse movement for camera rotation."""
	if event is InputEventMouseMotion and is_mouse_captured:
		# Horizontal rotation (body)
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		# Vertical rotation (head) with clamping
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))

func _handle_ball_interaction(event: InputEvent) -> void:
	"""Process ball kicking input with charge-up mechanic."""
	if Input.is_action_just_pressed("l_click"):
		kick_force_bar.visible = true
		is_holding_mouse = true
		mouse_hold_start_time = Time.get_unix_time_from_system()
	
	elif Input.is_action_just_released("l_click"):
		
		if is_holding_mouse and ball_in_range != null:
			_throw_ball()
		
		kick_force_bar.visible = false
		kick_force_bar.value = 0
		
		is_holding_mouse = false
		ball_in_range = null

func _handle_pause_input(event: InputEvent) -> void:
	"""Toggle pause state on pause button press."""
	if Input.is_action_just_pressed("pause"):
		toggle_pause()

# ------------------------------------------------------------------------------
# BALL THROWING FUNCTIONS
# ------------------------------------------------------------------------------
func _check_ball_in_range() -> void:
	"""Check if ball is in range using physics process."""
	var overlapping_bodies = area_3d.get_overlapping_bodies()
	var found_ball = null
	
	for body in overlapping_bodies:
		if body is RigidBody3D and body.name == "Ball":
			found_ball = body
			break
	
	# Update ball_in_range reference
	if found_ball != ball_in_range:
		if found_ball != null:
			label.text = "BALL IN RANGE: TRUE"
		else:
			label.text = "BALL IN RANGE: FALSE"
		ball_in_range = found_ball
	
	if kick_force_bar.visible:
		if found_ball:
			ball_there.visible = true
		else:
			ball_there.visible = false

func _throw_ball() -> void:
	"""Apply force to the ball based on hold time."""
	if ball_in_range == null:
		return
	
	# Calculate hold time (capped at maximum)
	var current_time = Time.get_unix_time_from_system()
	var hold_time = min(current_time - mouse_hold_start_time, MAX_HOLD_TIME)
	
	# Calculate force based on hold time (0 to 1 ratio)
	var force_ratio = hold_time / MAX_HOLD_TIME
	var force_magnitude = lerp(MIN_FORCE, MAX_FORCE, force_ratio)
	
	# Get the direction the player is looking (forward direction)
	var throw_direction = -head.global_transform.basis.z
	
	if is_server: # Host
		# Host can directly apply force
		ball_in_range.apply_central_impulse(throw_direction * force_magnitude)
	else:
		# Clients request the host to throw the ball
		request_throw_ball.rpc_id(1, force_magnitude, throw_direction, ball_in_range.get_path())
	
	# Reset hold state
	is_holding_mouse = false
	ball_in_range = null

@rpc("any_peer", "call_local", "reliable")
func request_throw_ball(force_magnitude: float, direction: Vector3, ball_ref):
	print(force_magnitude, direction, ball_ref)
	if multiplayer.get_unique_id() == 1:
		if ball_ref != null:
			get_node(ball_ref).apply_central_impulse(direction * force_magnitude)

# ------------------------------------------------------------------------------
# PHYSICS AND MOVEMENT
# ------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	"""Handle physics-based movement, gravity, and jumping."""
	
	# Check for ball in range
	_check_ball_in_range()
	
		
	if kick_force_bar.visible:
		var prog_value = (Time.get_unix_time_from_system() - mouse_hold_start_time) / MAX_HOLD_TIME * 100
		kick_force_bar.value = prog_value
	
	# Apply gravity when not on ground
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	
	# Handle jumping - only when on ground
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Determine movement speed (sprint only works on ground)
	var current_speed = SPRINT_SPEED if Input.is_action_pressed("sprint") and is_on_floor() else WALK_SPEED
	
	# Get input direction from WASD/arrow keys
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Convert input to world space direction relative to player rotation
	var target_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Smoothly interpolate current direction toward target for responsive feel
	direction = lerp(direction, target_direction, delta * lerp_speed)
	
	# Apply movement or deceleration
	if direction.length() > 0.01:  # Small threshold to avoid jitter
		# Moving - apply direction and speed
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		# Not moving - smoothly decelerate to stop
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	# Apply movement with collision detection
	move_and_slide()

# ------------------------------------------------------------------------------
# MOUSE CONTROL FUNCTIONS
# ------------------------------------------------------------------------------
func capture_mouse() -> void:
	"""Capture mouse for first-person look control."""
	is_mouse_captured = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func release_mouse() -> void:
	"""Release mouse to show cursor (for menus, etc.)."""
	is_mouse_captured = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func toggle_pause() -> void:
	"""Toggle between captured and released mouse states."""
	if is_mouse_captured:
		release_mouse()
	else:
		capture_mouse()
