extends CharacterBody2D

# ==============================================================================
# WINDNET DEMONSTRATION SCRIPT: HYBRID ARCHITECTURE (EVENT + HEARTBEAT)
# ------------------------------------------------------------------------------
# Best for: The "Gold Standard" for standard WindNet multiplayer games.
# Mechanics: Sends an HTTP update INSTANTLY when a key is pressed or released 
#            (Event-Driven). If the player holds the key down, it falls back to 
#            a slow 2Hz "Heartbeat" (Fixed-Tick) to guarantee the remote clients 
#            stay perfectly synced even if a packet is dropped by the internet.
# ==============================================================================

@export var is_local_authority: bool = false
@export var player_id: String = "Player123"

var speed = 200.0

# --- NETWORK SYNC VARIABLES ---
var current_input_dir: Vector2 = Vector2.ZERO
var local_sequence: int = 0

# --- THE HEARTBEAT (Safety Net) ---
const HEARTBEAT_RATE: float = 0.5 # 2 updates per second (very cheap!)
var heartbeat_timer: float = 0.0

# --- REMOTE STATE TRACKING ---
var last_received_sequence: int = -1
var remote_target_pos: Vector2 = Vector2.ZERO
var remote_input_dir: Vector2 = Vector2.ZERO
var has_remote_pos: bool = false

func _ready():
	if not is_local_authority:
		Subscriber.player_state_updated.connect(_on_server_update)

func _physics_process(delta):
	if is_local_authority:
		_process_local_hybrid(delta)
	else:
		_process_remote_extrapolation(delta)

func _process_local_hybrid(delta):
	var new_input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var is_moving = new_input_dir != Vector2.ZERO
	
	# Apply local Godot movement
	velocity = new_input_dir * speed
	move_and_slide()
	
	heartbeat_timer += delta
	var force_network_send = false
	
	# TRIGGER 1: THE EVENT (Instant Responsiveness)
	# If they changed direction, or pressed/released a key, send data IMMEDIATELY.
	if new_input_dir != current_input_dir:
		current_input_dir = new_input_dir
		force_network_send = true
		
	# TRIGGER 2: THE HEARTBEAT (Reliability / Anti-Desync)
	# If they are holding a direction for a long time, ping the server twice a second 
	# just in case the initial "Event" packet was lost in the mail.
	elif is_moving and heartbeat_timer >= HEARTBEAT_RATE:
		force_network_send = true
		
	# EXECUTE NETWORK FIRE
	if force_network_send:
		local_sequence += 1
		heartbeat_timer = 0.0 # Reset the heartbeat timer so it doesn't fire too soon
		
		# Broadcast to AWS via WindNet Subscriber
		Subscriber.send_player_move(player_id, position.x, position.y, current_input_dir.x, current_input_dir.y, local_sequence)

func _process_remote_extrapolation(delta):
	if not has_remote_pos:
		return
		
	# 1. EXTRAPOLATE: Walk the puppet forward using the last known input
	remote_target_pos += remote_input_dir * speed * delta
	
	# 2. INTERPOLATE: Smoothly glide towards the extrapolated target
	var distance = position.distance_to(remote_target_pos)
	var dynamic_weight = clamp(distance * 0.5, 15.0, 40.0)
	
	position = position.lerp(remote_target_pos, dynamic_weight * delta)
	
	# 3. ANTI-DRAG: Snap to absolute precision when stopped
	if distance < 1.0 and remote_input_dir == Vector2.ZERO:
		position = remote_target_pos

func _on_server_update(server_data: Dictionary):
	if server_data.get("playerId") != player_id:
		return
		
	var incoming_seq = server_data.get("sequence", 0)
	
	# Reject older packets to prevent rubber-banding
	if incoming_seq <= last_received_sequence:
		return 
		
	last_received_sequence = incoming_seq
	
	# Apply incoming data
	remote_target_pos = Vector2(server_data.get("posX", position.x), server_data.get("posY", position.y))
	remote_input_dir = Vector2(server_data.get("dirX", 0.0), server_data.get("dirY", 0.0))
	
	if not has_remote_pos:
		position = remote_target_pos
		has_remote_pos = true
