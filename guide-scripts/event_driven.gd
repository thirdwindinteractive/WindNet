extends CharacterBody2D

# ==============================================================================
# WINDNET DEMONSTRATION SCRIPT: EVENT-DRIVEN EXTRAPOLATION
# ------------------------------------------------------------------------------
# Best for: RPGs, Social Hubs, Co-op Puzzle Games, and standard WindNet users.
# Mechanics: The absolute most cost-effective architecture. It ONLY sends an 
#            AWS request when a player changes their input (presses or releases 
#            a key). It uses Native Godot Extrapolation to calculate 
#            the movement in between those rare events.
#
# NOTE ON FIXED-TICK: Use the Fixed-Tick script instead if your game requires 
# strict grid-based synchronization, or if you want a "self-correcting" stream 
# of data to combat high packet loss (Note: Fixed-Tick will cost more on AWS).
# ==============================================================================

@export var is_local_authority: bool = false
@export var player_id: String = "Player123"

var speed = 200.0

# --- LOCAL STATE TRACKING ---
var current_input_dir: Vector2 = Vector2.ZERO
var local_sequence: int = 0

# --- REMOTE STATE TRACKING ---
var last_received_sequence: int = -1
var remote_target_pos: Vector2 = Vector2.ZERO
var remote_input_dir: Vector2 = Vector2.ZERO
var has_remote_pos: bool = false

func _ready():
	if not is_local_authority:
		Subscriber.player_state_updated.connect(_on_server_update)

func _physics_process(delta):
	# Using _physics_process to ensure extrapolation math aligns with your physics engine
	if is_local_authority:
		_process_local_events()
	else:
		_process_remote_extrapolation(delta)

func _process_local_events():
	var new_input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Apply Godot Movement
	velocity = new_input_dir * speed
	move_and_slide()
	
	# THE EVENT TRIGGER: Only contact AWS if the input direction actually changed
	if new_input_dir != current_input_dir:
		current_input_dir = new_input_dir
		local_sequence += 1
		
		# Send Position, Direction, and Chronological Sequence
		Subscriber.send_player_move(player_id, position.x, position.y, current_input_dir.x, current_input_dir.y, local_sequence)

func _process_remote_extrapolation(delta):
	if not has_remote_pos:
		return
		
	# 1. EXTRAPOLATE: Walk the remote puppet forward based on the LAST known key they pressed
	remote_target_pos += remote_input_dir * speed * delta
	
	# 2. INTERPOLATE: Smoothly chase that extrapolated target
	var distance = position.distance_to(remote_target_pos)
	var dynamic_weight = clamp(distance * 0.5, 15.0, 40.0)
	
	position = position.lerp(remote_target_pos, dynamic_weight * delta)
	
	# 3. ANTI-DRAG: Snap to absolute precision when they stop moving
	if distance < 1.0 and remote_input_dir == Vector2.ZERO:
		position = remote_target_pos

func _on_server_update(server_data: Dictionary):
	if server_data.get("playerId") != player_id:
		return
		
	var incoming_seq = server_data.get("sequence", 0)
	
	# Reject older, delayed packets
	if incoming_seq <= last_received_sequence:
		return 
		
	last_received_sequence = incoming_seq
	
	# Update position AND the direction they are currently heading
	remote_target_pos = Vector2(server_data.get("posX", position.x), server_data.get("posY", position.y))
	remote_input_dir = Vector2(server_data.get("dirX", 0.0), server_data.get("dirY", 0.0))
	
	if not has_remote_pos:
		position = remote_target_pos
		has_remote_pos = true