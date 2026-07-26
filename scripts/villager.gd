class_name AshfallVillager
extends CharacterBody3D

enum State { IDLE, WALK, RUN, WORK }

@export var walk_speed := 1.75
@export var run_speed := 4.15
@export var acceleration := 7.5
@export var turn_speed := 9.0
@export var roam_radius := 18.0

var state := State.WALK
var target := Vector3.ZERO
var stride_phase := 0.0
var facing_sector := 0
var _idle_time := 0.0
var _rng := RandomNumberGenerator.new()
var _root_visual: Node3D
var _torso: Node3D
var _left_hip: Node3D
var _right_hip: Node3D
var _left_knee: Node3D
var _right_knee: Node3D
var _left_shoulder: Node3D
var _right_shoulder: Node3D
var _left_elbow: Node3D
var _right_elbow: Node3D
var _tool_pivot: Node3D

func _ready() -> void:
	_rng.randomize()
	collision_layer = 2
	collision_mask = 3
	add_to_group("moving_units")
	_build_collision()
	_build_character()
	_pick_target()

func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			_idle_time -= delta
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
			if _idle_time <= 0.0:
				state = State.WALK
				_pick_target()
		State.WALK, State.RUN:
			_update_locomotion(delta)
		State.WORK:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * 2.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * 2.0 * delta)
			stride_phase = fmod(stride_phase + delta * 4.8, TAU)
	velocity.y = -0.4
	move_and_slide()
	_animate(delta)

func set_work_target(world_target: Vector3) -> void:
	target = world_target
	state = State.RUN

func start_work() -> void:
	state = State.WORK
	stride_phase = 0.0

func stop_work() -> void:
	state = State.WALK
	_pick_target()

func _update_locomotion(delta: float) -> void:
	var offset := target - global_position
	offset.y = 0.0
	if offset.length() < 0.48:
		state = State.IDLE
		_idle_time = _rng.randf_range(0.5, 2.1)
		return
	var desired_direction := offset.normalized()
	var desired_speed := run_speed if state == State.RUN else walk_speed
	var desired_velocity := desired_direction * desired_speed
	# Séparation douce : les PNJ évitent de se superposer sans vibrer.
	var separation := Vector3.ZERO
	for unit in get_tree().get_nodes_in_group("moving_units"):
		if unit == self:
			continue
		var away: Vector3 = global_position - unit.global_position
		away.y = 0.0
		var distance := away.length()
		if distance > 0.001 and distance < 1.05:
			separation += away.normalized() * (1.05 - distance) * 2.4
	desired_velocity += separation
	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if planar_velocity.length() > 0.08:
		var desired_yaw := atan2(planar_velocity.x, planar_velocity.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-turn_speed * delta))
		# Secteur 0..7 utile aux futurs équipements directionnels, sans cassure visuelle :
		# le modèle 3D continue de tourner de façon parfaitement continue.
		facing_sector = posmod(roundi((desired_yaw / TAU) * 8.0), 8)
		stride_phase = fmod(stride_phase + delta * planar_velocity.length() * 4.6, TAU)

func _pick_target() -> void:
	target = Vector3(
		_rng.randf_range(-roam_radius, roam_radius),
		0.0,
		_rng.randf_range(-roam_radius, roam_radius)
	)

func _animate(delta: float) -> void:
	if state == State.WORK:
		_animate_work()
		return
	var speed_ratio := clampf(Vector2(velocity.x, velocity.z).length() / run_speed, 0.0, 1.0)
	var blend := clampf(speed_ratio * 1.35, 0.0, 1.0)
	var stride := sin(stride_phase)
	var opposite := sin(stride_phase + PI)
	var compression := maxf(0.0, -cos(stride_phase * 2.0))
	var lift_left := maxf(0.0, -stride)
	var lift_right := maxf(0.0, -opposite)
	# Hanches, genoux et chevilles sont animés séparément : le pied se lève,
	# passe sous le bassin puis reprend contact au lieu de glisser sur le sol.
	_left_hip.rotation.x = stride * lerpf(0.38, 0.72, blend)
	_right_hip.rotation.x = opposite * lerpf(0.38, 0.72, blend)
	_left_knee.rotation.x = lift_left * lerpf(0.42, 0.82, blend)
	_right_knee.rotation.x = lift_right * lerpf(0.42, 0.82, blend)
	_left_shoulder.rotation.x = opposite * lerpf(0.28, 0.58, blend)
	_right_shoulder.rotation.x = stride * lerpf(0.28, 0.58, blend)
	_left_elbow.rotation.x = -0.16 - lift_right * 0.24
	_right_elbow.rotation.x = -0.16 - lift_left * 0.24
	_root_visual.position.y = -compression * lerpf(0.025, 0.07, blend)
	_torso.rotation.z = stride * 0.025
	_torso.rotation.y = opposite * 0.035
	if speed_ratio < 0.025:
		var settle := 1.0 - exp(-10.0 * delta)
		_left_hip.rotation.x = lerpf(_left_hip.rotation.x, 0.0, settle)
		_right_hip.rotation.x = lerpf(_right_hip.rotation.x, 0.0, settle)
		_left_knee.rotation.x = lerpf(_left_knee.rotation.x, 0.0, settle)
		_right_knee.rotation.x = lerpf(_right_knee.rotation.x, 0.0, settle)

func _animate_work() -> void:
	var strike := (sin(stride_phase) + 1.0) * 0.5
	var backswing := sin(stride_phase - 0.65)
	_left_shoulder.rotation.x = -1.05 + backswing * 0.5
	_right_shoulder.rotation.x = -1.05 + backswing * 0.5
	_left_elbow.rotation.x = -0.72
	_right_elbow.rotation.x = -0.72
	_tool_pivot.rotation.x = -0.35 + strike * 1.65
	_torso.rotation.x = 0.08 + strike * 0.16
	_left_hip.rotation.x = -0.12
	_right_hip.rotation.x = 0.12
	_left_knee.rotation.x = 0.24
	_right_knee.rotation.x = 0.12

func _build_collision() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 2.35
	collider.shape = capsule
	collider.position.y = 1.18
	add_child(collider)

func _mat(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	mat.metallic = metallic
	return mat

func _mesh_part(parent: Node3D, name_: String, mesh: Mesh, position_: Vector3, color: Color, metallic := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = mesh
	node.position = position_
	node.material_override = _mat(color, metallic)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node

func _box_part(parent: Node3D, name_: String, size: Vector3, position_: Vector3, color: Color, metallic := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh_part(parent, name_, mesh, position_, color, metallic)

func _limb_chain(name_: String, x: float, y: float, arm := false) -> Array[Node3D]:
	var upper_pivot := Node3D.new()
	upper_pivot.name = name_ + "Upper"
	upper_pivot.position = Vector3(x, y, 0.0)
	_root_visual.add_child(upper_pivot)
	var upper_size := Vector3(0.23, 0.55, 0.26) if arm else Vector3(0.32, 0.55, 0.38)
	_box_part(upper_pivot, "UpperMesh", upper_size, Vector3(0, -upper_size.y * 0.5, 0), Color("#3a2921") if arm else Color("#25242a"))
	var joint := Node3D.new()
	joint.name = name_ + ("Elbow" if arm else "Knee")
	joint.position = Vector3(0, -upper_size.y, 0)
	upper_pivot.add_child(joint)
	var lower_size := Vector3(0.21, 0.5, 0.24) if arm else Vector3(0.29, 0.52, 0.35)
	_box_part(joint, "LowerMesh", lower_size, Vector3(0, -lower_size.y * 0.5, 0), Color("#34241f") if arm else Color("#202026"))
	if not arm:
		_box_part(joint, "Boot", Vector3(0.38, 0.22, 0.58), Vector3(0, -0.57, 0.12), Color("#141116"))
	return [upper_pivot, joint]

func _build_character() -> void:
	_root_visual = Node3D.new()
	_root_visual.name = "CharacterVisual"
	add_child(_root_visual)
	_torso = Node3D.new()
	_torso.name = "Torso"
	_torso.position = Vector3(0, 1.78, 0)
	_root_visual.add_child(_torso)
	_box_part(_torso, "Body", Vector3(1.02, 1.08, 0.62), Vector3.ZERO, Color("#3b2921"))
	_box_part(_torso, "Belt", Vector3(1.12, 0.15, 0.69), Vector3(0, -0.42, 0), Color("#171316"))
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.34
	head_mesh.height = 0.68
	_mesh_part(_torso, "Head", head_mesh, Vector3(0, 0.82, 0.04), Color("#9b6446"))
	var hood_mesh := SphereMesh.new()
	hood_mesh.radius = 0.46
	hood_mesh.height = 0.78
	var hood := _mesh_part(_torso, "Hood", hood_mesh, Vector3(0, 0.9, -0.08), Color("#2a201f"))
	hood.scale = Vector3(1.0, 1.06, 0.88)
	var left_leg := _limb_chain("Left", -0.27, 1.27)
	var right_leg := _limb_chain("Right", 0.27, 1.27)
	var left_arm := _limb_chain("Left", -0.64, 2.18, true)
	var right_arm := _limb_chain("Right", 0.64, 2.18, true)
	_left_hip = left_leg[0]
	_left_knee = left_leg[1]
	_right_hip = right_leg[0]
	_right_knee = right_leg[1]
	_left_shoulder = left_arm[0]
	_left_elbow = left_arm[1]
	_right_shoulder = right_arm[0]
	_right_elbow = right_arm[1]
	_tool_pivot = Node3D.new()
	_tool_pivot.name = "ToolPivot"
	_tool_pivot.position = Vector3(0.42, -0.48, -0.03)
	_right_elbow.add_child(_tool_pivot)
	_box_part(_tool_pivot, "HammerHandle", Vector3(0.1, 0.82, 0.1), Vector3(0, -0.36, 0), Color("#5a351d"))
	_box_part(_tool_pivot, "HammerHead", Vector3(0.5, 0.2, 0.22), Vector3(0, -0.78, 0), Color("#626067"), 0.6)
