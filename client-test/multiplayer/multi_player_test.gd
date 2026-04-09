extends Node2D

# ==========================================
# WINDNET: MULTIPLAYER EXTRAPOLATION CONTROLLER
# ==========================================
# This script demonstrates a production-ready HTTP/WebSocket hybrid networking model.
# Instead of flooding the network with 60 updates per second, it uses a highly efficient 
# 10Hz "Tick Rate" combined with Native Vector Extrapolation. 
# 
# It sends the player's position AND their current input direction. The receiving client 
# then takes over, flawlessly "guessing" where the player is walking at 60 FPS natively, 
# resulting in buttery-smooth movement over a low-cost, low-bandwidth HTTP connection.

@onready var local_player = $local_player
@onready var remote_player = $remote_player

# --- YOUR AWS CONFIGURATION ---
# For this particular test, it is assumed you have "API KEY" as the authorization mode in your appsync settings tab
# Replace with your specific AppSync GraphQL endpoint and API Key.
var appsync_url = "FULL GraphQL ENDPOINT HERE"
var api_key = "API KEY HERE" 

# Generate a random ID for this session so the network knows who is who.
var player_id = str(randi() % 10000) 
var speed = 400.0

# --- NETWORK THROTTLING (TICK RATE) ---
# 0.1 seconds = 10 updates per second. 
# This is incredibly cheap for AWS AppSync and prevents HTTP traffic jams.
var network_tick_rate = 0.1 
var time_since_last_update = 0.0

# --- THE CHRONOLOGICAL GATEKEEPER (SEQUENCE NUMBERS) ---
# The internet is chaotic. Sometimes Packet #3 arrives before Packet #2.
# These sequence numbers guarantee that the remote sprite never jerks backwards 
# to an old, delayed coordinate.
var local_sequence = 0
var last_received_sequence = -1

# --- SYNC STATE TRACKING ---
var was_moving = false
var needs_final_sync = false

# --- NATIVE EXTRAPOLATION VARIABLES ---
var remote_target_pos = Vector2.ZERO
var remote_input_dir = Vector2.ZERO
var has_remote_pos = false

func _ready():
	# Listen to the WindNet Autoload for any incoming WebSocket data
	Subscriber.player_state_updated.connect(_on_windnet_subscription_received)

func _process(delta):
	time_since_last_update += delta
	
	# ==========================================
	# 1. HANDLE LOCAL MOVEMENT
	# ==========================================
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var is_moving = input_dir != Vector2.ZERO
	
	if is_moving:
		local_player.position += input_dir * speed * delta
		was_moving = true
		
	# If the player just let go of the keys, flag a mandatory "Final Sync"
	# so we can tell AWS exactly where they came to a complete stop.
	if not is_moving and was_moving:
		needs_final_sync = true
		was_moving = false
		
	# ==========================================
	# 2. TRIGGER NETWORK SEND
	# ==========================================
	# Only send data if the 0.1s timer has popped, OR if we need to send a final stop packet.
	if (is_moving and time_since_last_update >= network_tick_rate) or needs_final_sync:
		local_sequence += 1 # Increment the chronological ID!
		
		# Send the position, the direction they are holding, and the sequence ID
		send_position_to_appsync(local_player.position, input_dir, local_sequence)
		
		time_since_last_update = 0.0
		needs_final_sync = false

	# ==========================================
	# 3. THE MAGIC: NATIVE EXTRAPOLATION PLAYBACK
	# ==========================================
	if has_remote_pos:
		# EXTRAPOLATE: Manually walk the "ghost target" forward based on the last keys the remote player was holding.
		# If the internet lags, the engine just keeps walking them forward flawlessly.
		remote_target_pos += remote_input_dir * speed * delta
		
		# INTERPOLATE: Smoothly chase that extrapolated ghost target.
		var distance = remote_player.position.distance_to(remote_target_pos)
		
		# DYNAMIC WEIGHT: If the network hiccuped and the sprite fell far behind, 
		# crank the lerp weight up to 40.0 to snap them back into place instantly. 
		# If they are close, ease it down to 15.0 for a buttery smooth glide.
		var dynamic_weight = clamp(distance * 0.5, 15.0, 40.0)
		
		remote_player.position = remote_player.position.lerp(remote_target_pos, dynamic_weight * delta)
		
		# ANTI-DRAG: lerp() mathematically slows down at the very end of a movement. 
		# If they are less than 1 pixel away and no longer holding any keys, snap them to absolute precision.
		if distance < 1.0 and remote_input_dir == Vector2.ZERO:
			remote_player.position = remote_target_pos

func send_position_to_appsync(pos: Vector2, dir: Vector2, seq: int):
	# "FIRE AND FORGET" HTTP REQUESTS
	# Instead of using one blocked HTTP node, we dynamically spawn a temporary node 
	# for every single request. This prevents the engine from bottlenecking if AWS takes 100ms to reply.
	var temp_request = HTTPRequest.new()
	add_child(temp_request)
	
	# The GraphQL Mutation string
	var query = """
    mutation UpdatePlayerState($playerId: ID!, $posX: Float!, $posY: Float!, $dirX: Float!, $dirY: Float!, $sequence: Int!) {
        updatePlayerState(playerId: $playerId, posX: $posX, posY: $posY, dirX: $dirX, dirY: $dirY, sequence: $sequence) {
            playerId
            posX
            posY
            dirX
            dirY
            sequence
        }
    }
    """
	var variables = { 
		"playerId": player_id, 
		"posX": pos.x, 
		"posY": pos.y, 
		"dirX": dir.x, 
		"dirY": dir.y, 
		"sequence": seq 
	}
	var body = JSON.stringify({"query": query, "variables": variables})
	var headers = [ "Content-Type: application/json", "x-api-key: " + api_key ]
	
	# Godot 4 Lambda Function: Cleanly destroy the temporary node the moment AWS replies
	temp_request.request_completed.connect(func(_result, _response_code, _headers, _body):
		temp_request.queue_free()
	)
	
	# Fire the request
	temp_request.request(appsync_url, headers, HTTPClient.METHOD_POST, body)


# ==========================================
# 4. INCOMING WEBSOCKET RECEIVER
# ==========================================
func _on_windnet_subscription_received(payload):
	# Make sure we don't process our own movement data!
	if payload.playerId != player_id:
		
		var incoming_seq = payload.sequence
		
		# THE GATEKEEPER: If this packet is older than or equal to our newest packet, 
		# throw it in the trash. This makes rubber-banding impossible.
		if incoming_seq <= last_received_sequence:
			return 
			
		last_received_sequence = incoming_seq
		
		# Update the absolute position AND the direction they are currently moving
		remote_target_pos = Vector2(payload.posX, payload.posY)
		remote_input_dir = Vector2(payload.dirX, payload.dirY)
		
		# If this is the very first packet we've seen from this player, snap them directly 
		# to the coordinate so they don't slowly slide across the entire screen.
		if not has_remote_pos:
			remote_player.position = remote_target_pos
			has_remote_pos = true
