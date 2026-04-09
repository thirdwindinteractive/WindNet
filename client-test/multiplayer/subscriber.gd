extends Node

# ==========================================
# WINDNET: AWS APPSYNC WEBSOCKET CLIENT
# ==========================================
# This script is designed to run as an Autoload (Singleton). 
# It runs silently in the background, maintaining a persistent WebSocket (WSS) 
# connection to AWS AppSync to catch incoming real-time multiplayer data.

# This signal acts as a global megaphone. Whenever AWS sends us new player data, 
# this script emits this signal so any scene in your game can "listen" and react.
signal player_state_updated(payload)

# --- YOUR AWS CONFIGURATION ---
# Replace these with your specific AppSync endpoints and API Key.
# Note: The 'domain' and 'realtime_domain' are slightly different URLs!

#format ex.: "kxnxxgw3ure3rlh6cgw6njstxa.appsync-api.us-east-1.amazonaws.com"
var appsync_domain = "GRAPHQL ENDPOINT HERE"

#format ex.: "kxnxxgw3ure3rlh6cgw6njstxa.appsync-realtime-api.us-east-1.amazonaws.com"
var appsync_realtime_domain = "REALTIME ENDPOINT HERE"

#format ex.: "da4-isjrrldpxnckvg3dhpzlz7b3tb"
var api_key = "API KEY HERE"

var socket := WebSocketPeer.new()
var connected := false

# A unique ID for this specific data stream. If you have multiple subscriptions 
# (e.g., one for movement, one for chat), they each need a unique ID.
var subscription_id = "windnet-sub-1" 

func _ready():
	# The moment the game launches, begin the connection process.
	connect_to_appsync()

func connect_to_appsync():
	# STEP 1: THE URL HANDSHAKE
	# AWS AppSync requires a very specific connection format. You cannot just connect 
	# to the URL; you must encode your authentication details into Base64 strings 
	# and attach them to the end of the WebSocket URL.
	
	var header_obj = {
		"host": appsync_domain,
		"x-api-key": api_key
	}
	
	# Convert our auth headers into Base64 format
	var header_b64 = Marshalls.utf8_to_base64(JSON.stringify(header_obj))
	var payload_b64 = Marshalls.utf8_to_base64(JSON.stringify({}))
	
	# Construct the final WSS URL
	var wss_url = "wss://" + appsync_realtime_domain + "/graphql?header=" + header_b64 + "&payload=" + payload_b64
	
	# AppSync strictly requires the "graphql-ws" sub-protocol to allow the connection
	socket.supported_protocols = ["graphql-ws"]
	
	var err = socket.connect_to_url(wss_url)
	if err != OK:
		print("WINDNET: Failed to initiate WebSocket connection.")

func _process(_delta):
	# _process runs every frame. socket.poll() tells the WebSocket to check 
	# the internet for new data or state changes.
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not connected:
			connected = true
			print("WINDNET: WebSocket Connected! Sending initialization...")
			# STEP 2: CONNECTION INIT
			# Just because the socket is open doesn't mean AWS is ready. 
			# We must explicitly send an initialization message first.
			send_connection_init()
			
		# Process all incoming messages from AWS currently sitting in the queue
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			var response_str = packet.get_string_from_utf8()
			handle_message(response_str)
			
	elif state == WebSocketPeer.STATE_CLOSED:
		if connected:
			print("WINDNET: WebSocket Closed. Code: ", socket.get_close_code(), " Reason: ", socket.get_close_reason())
			connected = false

func send_connection_init():
	# A standard GraphQL-WS protocol message asking the server to wake up
	var init_msg = {"type": "connection_init"}
	socket.send_text(JSON.stringify(init_msg))

func subscribe_to_movement():
	print("WINDNET: Subscribing to onUpdatePlayerState...")
	
	# STEP 3: THE SUBSCRIPTION PAYLOAD
	# This tells AWS exactly what data we want to be notified about. 
	# Ensure this matches your AWS AppSync Schema exactly.
	var query = """
	subscription OnUpdatePlayerState {
		onUpdatePlayerState {
			playerId
			posX
			posY
			dirX
			dirY
			sequence
		}
	}
	"""
	
	var auth_header = {
		"host": appsync_domain,
		"x-api-key": api_key
	}
	
	# AWS requires this exact nested JSON structure to start a subscription
	var start_msg = {
		"id": subscription_id,
		"type": "start",
		"payload": {
			"data": JSON.stringify({"query": query, "variables": {}}),
			"extensions": {
				"authorization": auth_header
			}
		}
	}
	
	socket.send_text(JSON.stringify(start_msg))

func handle_message(message_str: String):
	# STEP 4: ROUTING INCOMING TRAFFIC
	# This function acts as the traffic cop for all data coming from AWS.
	var json = JSON.new()
	if json.parse(message_str) == OK:
		var data = json.get_data()
		
		# Ensure the message is a dictionary and has a "type"
		if typeof(data) == TYPE_DICTIONARY and data.has("type"):
			match data["type"]:
				
				# AWS acknowledged our 'connection_init'. We are now cleared to subscribe!
				"connection_ack":
					print("WINDNET: Connection Acknowledged by AWS! Starting subscription...")
					subscribe_to_movement()
					
				# "ka" stands for Keep-Alive. AWS sends this empty ping every few seconds 
				# to ensure our client hasn't disconnected. We can safely ignore it.
				"ka":
					pass 
					
				# This is the actual multiplayer data we want!
				"data":
					# Drill down into the JSON to extract just the payload we care about
					var payload = data.get("payload", {}).get("data", {}).get("onUpdatePlayerState", null)
					
					if payload:
						# Blast the data out to the rest of the game using our signal
						player_state_updated.emit(payload)
						
				"error":
					print("WINDNET WS ERROR: ", data)
