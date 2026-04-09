extends CharacterBody2D

# ==============================================================================
# WINDNET DEMONSTRATION SCRIPT: STRICT FIXED-TICK ARCHITECTURE
# ------------------------------------------------------------------------------
# Best for: Turn-based games, Grid-based movement, or slow-paced strategy.
# Mechanics: This script intentionally DOES NOT calculate physics or movement 
#            every frame. Even though the Godot engine runs at 60 physics ticks 
#            per second, this node only polls input, updates its position, and 
#            sends data exactly 10 times a second (10Hz). 
#
# NOTE: This creates a rigid, "stepped" movement style. If you need smooth, 
# frame-by-frame action movement, refer to the Event-Driven / Extrapolation script!
# ==============================================================================

@export var is_local_authority: bool = false # True if THIS client controls this node
@export var player_id: String = "Player123"

var speed = 200.0

# --- NETWORK THROTTLING (TICK RATE) ---
const TICK_RATE: float = 0.1 # 10 updates per second
var tick_timer: float = 0.0

# --- FIXED TICK VARIABLES ---
var remote_target_pos: Vector2 = Vector2.ZERO

func _ready():
	# We only want remote "puppets" listening to the server broadcasts.
	if not is_local_authority:
		Subscriber.player_state_updated.connect(_on_server_update)

func _physics_process(delta):
	# We accumulate time every engine frame, but we DO NOT process movement here.
	tick_timer += delta
	
	# The Gatekeeper: We only execute game logic when the 0.1s tick "pops"
	if tick_timer >= TICK_RATE:
		# Subtract the tick rate to keep timing perfectly mathematically accurate
		tick_timer -= TICK_RATE 
		
		if is_local_authority:
			_process_local_tick()
		else:
			_process_remote_tick()

func _process_local_tick():
	# 1. Poll input ONLY on the tick, ignoring what happens between ticks
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_dir != Vector2.ZERO:
		# 2. Apply movement instantly for this specific tick duration.
		# Because we only move 10 times a second, we multiply by TICK_RATE, not delta.
		var step_velocity = input_dir * speed
		position += step_velocity * TICK_RATE
		
		# 3. Broadcast to the WindNet Subscriber
		Subscriber.send_player_move(player_id, position.x, position.y)

func _process_remote_tick():
	# In a strict fixed-tick architecture, we do not interpolate smoothly every frame.
	# We simply update the position when the new server tick data is ready to process.
	if remote_target_pos != Vector2.ZERO:
		position = remote_target_pos

func _on_server_update(server_data: Dictionary):
	# Ignore updates for other players
	if server_data.get("playerId") != player_id:
		return
		
	# Store the incoming position. It will be applied on the next fixed _process_remote_tick
	remote_target_pos = Vector2(server_data.get("posX", position.x), server_data.get("posY", position.y))
