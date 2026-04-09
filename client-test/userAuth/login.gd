extends Control

@onready var http = $HTTPRequest

@onready var signup_button = $pages/SIGNUP/HBoxContainer/signup
@onready var login_button = $pages/LOGIN/HBoxContainer/login
@onready var verify_button = $pages/CONFIRMSIGNUP/HBoxContainer/verification

@onready var log_link = $pages/SIGNUP/HBoxContainer/logpage
@onready var sign_link = $pages/LOGIN/HBoxContainer/signpage
@onready var back_to_sign = $pages/CONFIRMSIGNUP/HBoxContainer/back
@onready var verify_link = $pages/SIGNUP/HBoxContainer/verify

@onready var error_back = $pages/ERROR/HBoxContainer/back

const aws_region = 'YOUR AWS REGION HERE' #Example: us-east-1
const client_id = 'COGNITO CLIENT ID HERE' #Found in your "App Clients" tab in Cognito
const endpoint = 'https://cognito-idp.' + aws_region + '.amazonaws.com/' #URL for contacting AWS Cognito

var request_type = "SIGNUP" #Tracking process state

var user: String = ""

func _ready() -> void:
	signup_button.pressed.connect(sign_up)
	
	login_button.pressed.connect(log_in)
	
	verify_button.pressed.connect(verify_code)
	
	error_back.pressed.connect(func():
		$pages.current_tab = 0
		request_type = "SIGNUP"
		)
	sign_link.pressed.connect(func(): 
		$pages.current_tab = 0
		request_type = "SIGNUP"
		)
	back_to_sign.pressed.connect(func(): 
		$pages.current_tab = 0
		request_type = "SIGNUP"
	)
	verify_link.pressed.connect(func():
		$pages/CONFIRMSIGNUP/instruct.text = ""
		$pages.current_tab = 1
		request_type = "VERIFY"
		)
	log_link.pressed.connect(func():
		$pages.current_tab = 2
		request_type = "LOGIN"
		)
		
	http.request_completed.connect(http_result)

func sign_up():
	user = $pages/SIGNUP/email.text
	var email = user
	var password = $pages/SIGNUP/pass.text
	var confirm_pass = $pages/SIGNUP/conpass.text
	
	if password != confirm_pass:
		show_error("Passwords do not match.")
		return
		
	if password  == "" or confirm_pass == "" or user == "":
		show_error("One or more fields are empty.")
		return
	
	var headers = ["Content-Type: application/x-amz-json-1.1",
	"X-Amz-Target: AWSCognitoIdentityProviderService.SignUp"]
	
	var payload = {
		"ClientId": client_id,
		"Username": email,
		"Password": password,
		"UserAttributes": [{"Name": "email", "Value": email}]
	}
	
	$pages.current_tab = 3
	
	http.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	
func verify_code():
	var verification_code = $pages/CONFIRMSIGNUP/confirmation.text
	
	var headers = ["Content-Type: application/x-amz-json-1.1",
	"X-Amz-Target: AWSCognitoIdentityProviderService.ConfirmSignUp"]
	
	var payload = {
		"ClientId": client_id,
		"Username": user,
		"ConfirmationCode": verification_code
	}
	
	$pages.current_tab = 3
	
	http.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	
func log_in():
	var email = $pages/LOGIN/email.text
	var password = $pages/LOGIN/pass.text
	
	var headers = ["Content-Type: application/x-amz-json-1.1",
	"X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth"]
	
	var payload = {
		"ClientId": client_id,
		"AuthFlow": "USER_PASSWORD_AUTH",
		"AuthParameters": {"USERNAME": email, "PASSWORD": password}
	}
	
	$pages.current_tab = 3
	
	http.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	
func show_error(text: String):
	$pages.current_tab = 4
	$pages/ERROR/errorcode.text = text
	
func http_result(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response == null:
		show_error("Network Error: Could not connect to AWS.")
		return
	
	if response_code == 200:
		if request_type == "SIGNUP":
			$pages.current_tab = 1
			request_type = "VERIFY"
			$pages/CONFIRMSIGNUP/instruct.text = "A verification email has been sent to you."
			$pages/SIGNUP/email.text = ""
			$pages/SIGNUP/pass.text = ""
			$pages/SIGNUP/conpass.text = ""
		elif request_type == "LOGIN":
			var id_token = response["AuthenticationResult"]["IdToken"]
			UserGlobal.user_token = id_token
			#In a normal setup, save the ID_token in a protected file in order
			#to preserve user login. In this project this is just for demonstration.
			$pages.current_tab = 5
		elif request_type == "VERIFY":
			$pages.current_tab = 1
			$pages/CONFIRMSIGNUP/confirmation.text = ""
			$pages/CONFIRMSIGNUP/instruct.text = "Your account was verified! you can now log in."
	else:
		var raw_error_name = response.get("__type", "UnknownError")
		var raw_error_msg = response.get("message", "No message provided by AWS")
		var full_error = raw_error_name + ": " + raw_error_msg
		show_error(full_error)
