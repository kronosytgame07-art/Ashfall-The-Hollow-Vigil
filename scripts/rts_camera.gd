class_name RTSCamera
extends Node3D

@export var target := Vector3.ZERO
@export_range(12.0, 55.0) var distance := 25.0
@export_range(25.0, 70.0) var pitch_degrees := 51.0
@export var yaw_degrees := 45.0
@export var pan_speed := 18.0
@export var zoom_speed := 2.4

var _dragging := false
var _last_pointer := Vector2.ZERO
var _touches: Dictionary = {}
var _last_pinch_distance := 0.0

func _ready() -> void:
	_update_camera()

func _process(delta: float) -> void:
	var input := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if input.length_squared() > 0.0:
		var forward := Vector3(-sin(deg_to_rad(yaw_degrees)), 0.0, -cos(deg_to_rad(yaw_degrees)))
		var right := Vector3(forward.z, 0.0, -forward.x)
		target += (right * input.x + forward * input.y) * pan_speed * delta
	if Input.is_action_pressed("rotate_left"):
		yaw_degrees -= 65.0 * delta
	if Input.is_action_pressed("rotate_right"):
		yaw_degrees += 65.0 * delta
	target.x = clampf(target.x, -24.0, 24.0)
	target.z = clampf(target.z, -24.0, 24.0)
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			_last_pointer = event.position
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - zoom_speed, 12.0, 55.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + zoom_speed, 12.0, 55.0)
	elif event is InputEventMouseMotion and _dragging:
		_pan_screen_delta(event.position - _last_pointer)
		_last_pointer = event.position
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_last_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_pan_screen_delta(event.relative)
		elif _touches.size() == 2:
			var points := _touches.values()
			var pinch: float = points[0].distance_to(points[1])
			if _last_pinch_distance > 0.0:
				distance = clampf(distance - (pinch - _last_pinch_distance) * 0.025, 12.0, 55.0)
			_last_pinch_distance = pinch

func _pan_screen_delta(delta: Vector2) -> void:
	var scale := distance * 0.0016
	var yaw := deg_to_rad(yaw_degrees)
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	target += (-right * delta.x - forward * delta.y) * scale

func _update_camera() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	var yaw := deg_to_rad(yaw_degrees)
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)
	) * distance
	global_position = target + offset
	$Camera3D.look_at(target, Vector3.UP)
