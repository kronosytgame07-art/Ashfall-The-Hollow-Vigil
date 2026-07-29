extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/souls_player.gd")
const ENEMY_SCRIPT := preload("res://scripts/souls_enemy.gd")
const WORLD_HALF := 30
const CONTROL_ACTIONS := {
	"move_forward": "AVANCER",
	"move_back": "RECULER",
	"move_left": "ALLER À GAUCHE",
	"move_right": "ALLER À DROITE",
	"sprint": "COURIR",
	"dodge": "ESQUIVER",
	"attack": "ATTAQUER",
	"interact": "INTERAGIR",
}
const DEFAULT_KEYS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"sprint": KEY_SHIFT,
	"dodge": KEY_SPACE,
	"attack": KEY_F,
	"interact": KEY_E,
}

var player: AshfallSoulsPlayer
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var souls_label: Label
var prompt_label: Label
var area_label: Label
var death_overlay: Control
var menu: Control
var enemies_alive := 0
var souls := 0
var game_started := false
var selected_race := "Humain"
var checkpoint_position := Vector3(0, 1.2, 10)
var safe_spawn_position := Vector3(0, 2.4, 10)
var fire_light: OmniLight3D
var controls_panel: Control
var control_buttons: Dictionary = {}
var awaiting_action := ""
var follow_camera: Camera3D
var enemies_active := false
var world_ready := false
var play_button: Button
var boot_status: Label

func _ready() -> void:
	_ensure_input_actions()
	_load_controls()
	_spawn_player()
	_build_world_follow_camera()
	_build_interface()
	_show_title_menu()
	call_deferred("_finish_world_boot")

func _finish_world_boot() -> void:
	# Draw the title screen before constructing the procedural world. On Web,
	# a renderer-specific failure must never leave the player on a silent black
	# canvas with no indication that Godot started.
	await get_tree().process_frame
	_build_environment()
	_build_continuous_ground_collision()
	_build_voxel_world()
	_build_ruins()
	_build_checkpoint()
	_spawn_enemies()
	world_ready = true
	if is_instance_valid(play_button):
		play_button.disabled = false
		play_button.text = "ENTRER DANS LE MONDE"
	if is_instance_valid(boot_status):
		boot_status.text = "MONDE CHARGÉ  •  PRÊT"

func _process(delta: float) -> void:
	_update_world_follow_camera(delta)
	if fire_light:
		fire_light.light_energy = 2.7 + sin(Time.get_ticks_msec() * 0.012) * 0.42
	if not is_instance_valid(player) or player.is_dead:
		return
	var distance_to_fire := player.global_position.distance_to(checkpoint_position)
	prompt_label.visible = distance_to_fire < 3.0
	if distance_to_fire < 3.0 and Input.is_action_just_pressed("interact"):
		player.rest_at(safe_spawn_position)
		_respawn_enemies()
		_flash_message("REPOS ACCORDÉ  •  LES OMBRES REVIENNENT")
	if player.global_position.y < -1.5:
		_rescue_player_from_void()
	if game_started and not enemies_active and player.global_position.distance_to(safe_spawn_position) > 3.0:
		_activate_enemies()

func _ensure_input_actions() -> void:
	for action in DEFAULT_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var event := InputEventKey.new()
			event.physical_keycode = DEFAULT_KEYS[action]
			InputMap.action_add_event(action, event)
	if InputMap.action_get_events("attack").size() == 1:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", click)

func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and event.keycode == KEY_ENTER
		and is_instance_valid(menu)
		and world_ready
	):
		_start_game()
		get_viewport().set_input_as_handled()
		return
	if awaiting_action.is_empty():
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_cancel_rebinding()
			get_viewport().set_input_as_handled()
			return
		var key_event := InputEventKey.new()
		key_event.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		_apply_binding(awaiting_action, key_event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = event.button_index
		_apply_binding(awaiting_action, mouse_event)
		get_viewport().set_input_as_handled()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	if OS.has_feature("web"):
		# Keep the browser path on features guaranteed by the Compatibility
		# renderer. The native build retains the authored procedural sky.
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("#17131d")
	else:
		environment.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color("#040408")
		sky_material.sky_horizon_color = Color("#17121d")
		sky_material.ground_bottom_color = Color("#030305")
		sky_material.ground_horizon_color = Color("#130e16")
		sky_material.sun_angle_max = 1.0
		sky.sky_material = sky_material
		environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#626979")
	environment.ambient_light_energy = 0.9 if OS.has_feature("web") else 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR if OS.has_feature("web") else Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = not OS.has_feature("web")
	environment.glow_intensity = 1.25
	# Height fog is disabled in the compatibility Web renderer until its
	# visibility is calibrated; it previously swallowed the entire ground pass.
	environment.fog_enabled = false
	environment.fog_light_color = Color("#17131d")
	environment.fog_density = 0.018
	environment.fog_height = 1.2
	environment.fog_height_density = 0.16
	world_environment.environment = environment
	$World.add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48, -28, 0)
	moon.light_color = Color("#9ca9c7")
	moon.light_energy = 1.42
	moon.shadow_enabled = not OS.has_feature("web")
	$World.add_child(moon)

func _build_voxel_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var ground_materials := [
		_voxel_material(Color("#17171b"), Color("#27242a")),
		_voxel_material(Color("#1d1b20"), Color("#302a2d")),
		_voxel_material(Color("#16191a"), Color("#242b28")),
	]
	var snow_materials := [
		_voxel_material(Color("#59616b"), Color("#a4b0bc")),
		_voxel_material(Color("#424953"), Color("#7c8996")),
	]
	var volcanic_materials := [
		_voxel_material(Color("#160c0b"), Color("#48201a")),
		_voxel_material(Color("#24100c"), Color("#6c2517")),
	]
	var all_materials: Array = ground_materials + snow_materials + volcanic_materials
	var transform_groups: Array = [[], [], [], [], [], [], []]
	for x in range(-WORLD_HALF, WORLD_HALF, 2):
		for z in range(-WORLD_HALF, WORLD_HALF, 2):
			var distance := Vector2(x, z).length()
			if distance > WORLD_HALF + rng.randf_range(-2.0, 2.0):
				continue
			var height := rng.randf_range(0.16, 0.34)
			if distance > 24.0:
				height += rng.randf_range(0.0, 2.8) * pow((distance - 24.0) / 7.0, 1.8)
			var material_offset := 0
			var material_count := ground_materials.size()
			if x <= -12:
				material_offset = ground_materials.size()
				material_count = snow_materials.size()
			elif x >= 12:
				material_offset = ground_materials.size() + snow_materials.size()
				material_count = volcanic_materials.size()
			var material_index := material_offset + rng.randi_range(0, material_count - 1)
			var basis := Basis().rotated(
				Vector3.UP,
				rng.randf_range(-0.025, 0.025)
			)
			basis = basis.scaled(Vector3(1.0, height, 1.0))
			transform_groups[material_index].append(
				Transform3D(basis, Vector3(x, -height * 0.5, z))
			)
	for material_index in range(all_materials.size()):
		_add_ground_multimesh(
			transform_groups[material_index],
			all_materials[material_index],
			material_index
		)
	_build_region_landmarks()
	# Jagged basalt silhouettes make the horizon feel authored rather than flat.
	for i in range(78):
		var angle := TAU * float(i) / 78.0 + rng.randf_range(-0.045, 0.045)
		var radius := rng.randf_range(27.5, 32.0)
		var height := rng.randf_range(2.0, 8.0)
		_static_box(
			$World,
			Vector3(rng.randf_range(1.0, 2.8), height, rng.randf_range(1.0, 2.8)),
			Vector3(sin(angle) * radius, height * 0.5 - 0.2, cos(angle) * radius),
			_voxel_material(Color("#131319"), Color("#302b36")),
			Vector3(rng.randf_range(-0.08, 0.08), angle, rng.randf_range(-0.12, 0.12))
		)

func _add_ground_multimesh(transforms: Array, material: Material, index: int) -> void:
	if transforms.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3(2.03, 1.0, 2.03)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for transform_index in range(transforms.size()):
		multimesh.set_instance_transform(transform_index, transforms[transform_index])
	var instance := MultiMeshInstance3D.new()
	instance.name = "TerrainBatch%d" % index
	instance.multimesh = multimesh
	instance.material_override = material
	$World.add_child(instance)

func _build_continuous_ground_collision() -> void:
	# The terrain is rendered in seven MultiMesh batches and uses one
	# uninterrupted collider instead of hundreds of physics bodies.
	var safety_floor := StaticBody3D.new()
	safety_floor.name = "ContinuousWorldFloor"
	safety_floor.position = Vector3(0, -0.55, 0)
	safety_floor.collision_layer = 1
	safety_floor.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WORLD_HALF * 2.0, 1.0, WORLD_HALF * 2.0)
	collider.shape = shape
	safety_floor.add_child(collider)
	$World.add_child(safety_floor)
	var fallback_ground := MeshInstance3D.new()
	fallback_ground.name = "VisibleFallbackGround"
	var fallback_mesh := PlaneMesh.new()
	fallback_mesh.size = Vector2(WORLD_HALF * 2.0, WORLD_HALF * 2.0)
	fallback_ground.mesh = fallback_mesh
	fallback_ground.position.y = 0.035
	var fallback_material := StandardMaterial3D.new()
	fallback_material.albedo_color = Color("#211f25")
	fallback_material.roughness = 0.98
	fallback_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fallback_ground.material_override = fallback_material
	$World.add_child(fallback_ground)

func _build_ruins() -> void:
	var stone := _voxel_material(Color("#24242a"), Color("#4b4750"))
	var dark_stone := _voxel_material(Color("#15151a"), Color("#34313a"))
	# A broken chapel with a nave, arches and an elevated altar.
	for z in range(-14, -2, 2):
		for x in [-9, 9]:
			var height := 4.4 if z < -6 else 2.4
			_static_box($World, Vector3(1.35, height, 1.35), Vector3(x, height * 0.5, z), stone)
	for x in range(-8, 9, 2):
		if abs(x) > 2:
			_static_box($World, Vector3(1.7, 3.2, 1.1), Vector3(x, 1.6, -15), dark_stone)
	for x in [-6, -3, 3, 6]:
		_static_box($World, Vector3(0.8, 6.4, 0.8), Vector3(x, 3.2, -10), stone)
		_static_box($World, Vector3(2.2, 0.65, 0.9), Vector3(x, 6.05, -10), stone)
	_static_box($World, Vector3(7.0, 0.7, 4.0), Vector3(0, 0.35, -12), dark_stone)
	_static_box($World, Vector3(3.0, 1.2, 1.8), Vector3(0, 0.95, -13.5), stone)
	# Scattered ruined walls guide exploration without producing a square arena.
	for data in [
		[Vector3(-15, 1.5, 3), Vector3(6, 3, 1)],
		[Vector3(14, 1.1, 8), Vector3(1, 2.2, 7)],
		[Vector3(-11, 0.9, 15), Vector3(7, 1.8, 1)],
		[Vector3(12, 1.5, -10), Vector3(1, 3, 5)],
	]:
		var wall := _static_box($World, data[1], data[0], stone)
		wall.rotation.y = data[0].x * 0.017
	# Black leafless voxel trees.
	for position_ in [
		Vector3(-18, 0, -7), Vector3(17, 0, 3), Vector3(-15, 0, 17),
		Vector3(20, 0, -15), Vector3(8, 0, 18), Vector3(-22, 0, 8)
	]:
		_build_dead_tree(position_)

func _build_dead_tree(position_: Vector3) -> void:
	var wood := _voxel_material(Color("#100b0d"), Color("#302027"))
	var root := Node3D.new()
	root.position = position_
	root.rotation.y = position_.x * 0.21
	$World.add_child(root)
	_static_box(root, Vector3(0.62, 4.8, 0.62), Vector3(0, 2.4, 0), wood, Vector3(0.0, 0.0, 0.08))
	for branch in [
		[Vector3(-0.8, 4.1, 0), Vector3(1.8, 0.38, 0.38), -0.58],
		[Vector3(0.72, 3.25, 0.1), Vector3(1.6, 0.34, 0.34), 0.72],
		[Vector3(0.2, 5.0, 0), Vector3(1.25, 0.3, 0.3), 1.1],
	]:
		var limb := _static_box(root, branch[1], branch[0], wood)
		limb.rotation.z = branch[2]

func _build_region_landmarks() -> void:
	# The safe central basin opens into two distant, clearly readable biomes.
	for z in range(-24, 25, 6):
		var ice := _static_box(
			$World,
			Vector3(0.7, 2.4 + posmod(z, 5), 0.7),
			Vector3(-21.0 + sin(z) * 2.0, 1.4, z),
			_voxel_material(Color("#6f8294"), Color("#c1d5df")),
			Vector3(0.08, z * 0.04, 0.18)
		)
		ice.material_override = _emissive_material(Color("#648da8"))
	for z in range(-24, 25, 7):
		var fissure := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.4, 0.08, 0.28)
		fissure.mesh = mesh
		fissure.position = Vector3(20.0 + sin(z) * 3.0, 0.08, z)
		fissure.rotation.y = z * 0.19
		fissure.material_override = _emissive_material(Color("#d83b17"))
		$World.add_child(fissure)
	var frost_light := OmniLight3D.new()
	frost_light.position = Vector3(-23, 4, -5)
	frost_light.light_color = Color("#7db7d5")
	frost_light.light_energy = 1.6
	frost_light.omni_range = 17.0
	$World.add_child(frost_light)
	var lava_light := OmniLight3D.new()
	lava_light.position = Vector3(23, 3, -4)
	lava_light.light_color = Color("#ee3c18")
	lava_light.light_energy = 2.4
	lava_light.omni_range = 19.0
	$World.add_child(lava_light)

func _build_checkpoint() -> void:
	var root := Node3D.new()
	root.position = checkpoint_position - Vector3(0, 1.2, 0)
	$World.add_child(root)
	var stone := _voxel_material(Color("#242128"), Color("#51454a"))
	for i in range(12):
		var angle := TAU * i / 12.0
		_static_box(root, Vector3(0.65, 0.34, 0.45), Vector3(sin(angle) * 1.15, 0.18, cos(angle) * 1.15), stone, Vector3(0, -angle, 0))
	for i in range(7):
		var ember := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(0.28, 0.4 + i * 0.035, 0.28)
		ember.mesh = cube
		ember.position = Vector3(sin(i * 2.1) * 0.5, 0.35 + (i % 3) * 0.12, cos(i * 2.1) * 0.5)
		ember.material_override = _emissive_material(Color("#e74b22") if i % 2 == 0 else Color("#ff9b32"))
		root.add_child(ember)
	fire_light = OmniLight3D.new()
	fire_light.position = Vector3(0, 1.2, 0)
	fire_light.light_color = Color("#ff5b27")
	fire_light.light_energy = 3.0
	fire_light.omni_range = 11.0
	fire_light.shadow_enabled = true
	root.add_child(fire_light)

func _spawn_player() -> void:
	player = PLAYER_SCRIPT.new() as AshfallSoulsPlayer
	player.position = safe_spawn_position
	$Actors.add_child(player)
	player.checkpoint = safe_spawn_position
	player.configure_race(selected_race)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.health_changed.connect(_on_health_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	player.died.connect(_on_player_died)

func _build_world_follow_camera() -> void:
	# This is the only active camera. It lives in world space and explicitly
	# looks at the player, so no inherited CharacterBody transform can hide the
	# scene in the Web renderer.
	follow_camera = Camera3D.new()
	follow_camera.name = "WorldFollowCamera"
	follow_camera.current = true
	follow_camera.fov = 60.0
	follow_camera.near = 0.08
	$World.add_child(follow_camera)
	var camera_fill := OmniLight3D.new()
	camera_fill.light_color = Color("#8795b3")
	camera_fill.light_energy = 1.85
	camera_fill.omni_range = 12.0
	camera_fill.shadow_enabled = false
	follow_camera.add_child(camera_fill)
	var target := player.global_position + Vector3(0, 1.15, 0)
	follow_camera.global_position = target + Vector3(0.7, 4.2, 6.2)
	follow_camera.look_at(target, Vector3.UP)

func _update_world_follow_camera(delta: float) -> void:
	if not is_instance_valid(follow_camera) or not is_instance_valid(player):
		return
	var target := player.global_position + Vector3(0, 1.15, 0)
	var yaw := player.camera_pivot.rotation.y
	var pitch := player.camera_pivot.rotation.x
	var orbit_offset := Vector3(
		sin(yaw) * 6.2,
		4.2 + clampf(-pitch * 3.0, -1.4, 1.8),
		cos(yaw) * 6.2
	)
	var desired_position := target + orbit_offset
	follow_camera.global_position = follow_camera.global_position.lerp(
		desired_position,
		1.0 - exp(-14.0 * delta)
	)
	follow_camera.look_at(target, Vector3.UP)

func _rescue_player_from_void() -> void:
	player.global_position = safe_spawn_position
	player.velocity = Vector3.ZERO
	player.invulnerable_clock = 1.0
	_flash_message("REPLACÉ AU BRASIER  •  AUCUNE ÂME PERDUE")

func _spawn_enemies() -> void:
	for enemy_data in [
		[Vector3(-5, 1, 1), 1, "Errant"],
		[Vector3(6, 1, -5), 1, "Pilleur creux"],
		[Vector3(-7, 1, -10), 2, "Déchu"],
		[Vector3(8, 1, -14), 2, "Déchu"],
		[Vector3(-20, 1, 8), 5, "Revenant de givre"],
		[Vector3(-23, 1, -14), 7, "Garde boréal"],
		[Vector3(19, 1, 4), 6, "Écorché de braise"],
		[Vector3(23, 1, -15), 9, "Chevalier du magma"]
	]:
		var enemy := ENEMY_SCRIPT.new() as AshfallSoulsEnemy
		enemy.position = enemy_data[0]
		enemy.defeated.connect(_on_enemy_defeated)
		$Actors.add_child(enemy)
		enemy.configure(enemy_data[1], enemy_data[2])
		if not enemies_active:
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemies_alive += 1

func _respawn_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
	enemies_alive = 0
	call_deferred("_spawn_enemies")

func _activate_enemies() -> void:
	enemies_active = true
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.process_mode = Node.PROCESS_MODE_INHERIT
	_flash_message("LES OMBRES VOUS ONT REPÉRÉ")

func _build_interface() -> void:
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Interface.add_child(hud)
	var stats := VBoxContainer.new()
	stats.position = Vector2(34, 32)
	stats.size = Vector2(360, 120)
	hud.add_child(stats)
	var title := Label.new()
	title.text = "ASHFALL  •  LE CREUX DES CENDRES"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("#c8b8a0"))
	stats.add_child(title)
	health_bar = _hud_bar(Color("#791e23"), 100.0)
	stats.add_child(health_bar)
	stamina_bar = _hud_bar(Color("#667b3d"), 100.0)
	stats.add_child(stamina_bar)
	souls_label = Label.new()
	souls_label.text = "NIV. 1  •  %s     ÂMES  0     OMBRES  %d" % [selected_race.to_upper(), enemies_alive]
	souls_label.add_theme_font_size_override("font_size", 16)
	souls_label.add_theme_color_override("font_color", Color("#b8a78f"))
	stats.add_child(souls_label)
	area_label = Label.new()
	area_label.text = "LES RUINES DE VIGILE"
	area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area_label.position = Vector2(0, 34)
	area_label.size = Vector2(1280, 42)
	area_label.add_theme_font_size_override("font_size", 24)
	area_label.add_theme_color_override("font_color", Color("#d4c7b3"))
	hud.add_child(area_label)
	var tween := create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(area_label, "modulate:a", 0.0, 1.6)
	prompt_label = Label.new()
	prompt_label.text = "[ E ]  SE REPOSER AU BRASIER"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(390, 640)
	prompt_label.size = Vector2(500, 36)
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color("#edc89b"))
	prompt_label.visible = false
	hud.add_child(prompt_label)
	var controls := Label.new()
	controls.text = "ZQSD/WASD Déplacement   •   Souris Caméra   •   Clic/F Attaque   •   Espace Esquive   •   Maj Course"
	controls.position = Vector2(24, 684)
	controls.size = Vector2(1220, 26)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color("#837b78"))
	hud.add_child(controls)
	var controls_button := Button.new()
	controls_button.text = "COMMANDES"
	controls_button.position = Vector2(1070, 30)
	controls_button.size = Vector2(180, 42)
	controls_button.mouse_filter = Control.MOUSE_FILTER_STOP
	controls_button.pressed.connect(_open_controls_menu)
	_style_button(controls_button)
	hud.add_child(controls_button)
	_build_death_overlay(hud)
	_build_controls_menu()

func _build_death_overlay(hud: Control) -> void:
	death_overlay = ColorRect.new()
	death_overlay.color = Color(0.08, 0.0, 0.01, 0.86)
	death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	death_overlay.visible = false
	hud.add_child(death_overlay)
	var death_title := Label.new()
	death_title.text = "VOUS ÊTES TOMBÉ"
	death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_title.position = Vector2(0, 255)
	death_title.size = Vector2(1280, 70)
	death_title.add_theme_font_size_override("font_size", 42)
	death_title.add_theme_color_override("font_color", Color("#9c292b"))
	death_overlay.add_child(death_title)
	var return_button := Button.new()
	return_button.text = "REVENIR AU DERNIER BRASIER"
	return_button.position = Vector2(490, 360)
	return_button.size = Vector2(300, 52)
	return_button.pressed.connect(_revive_player)
	_style_button(return_button)
	death_overlay.add_child(return_button)

func _show_title_menu() -> void:
	menu = ColorRect.new()
	menu.color = Color(0.015, 0.012, 0.02, 0.96)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Interface.add_child(menu)
	var title := Label.new()
	title.text = "A S H F A L L"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 160)
	title.size = Vector2(1280, 82)
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("#d1c2ad"))
	menu.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "LE CREUX DES CENDRES"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 238)
	subtitle.size = Vector2(1280, 40)
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("#765e62"))
	menu.add_child(subtitle)
	var race_title := Label.new()
	race_title.text = "CHOISISSEZ VOTRE RACE"
	race_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	race_title.position = Vector2(0, 305)
	race_title.size = Vector2(1280, 28)
	race_title.add_theme_color_override("font_color", Color("#8e8176"))
	menu.add_child(race_title)
	var race_row := HBoxContainer.new()
	race_row.position = Vector2(370, 344)
	race_row.size = Vector2(540, 46)
	race_row.add_theme_constant_override("separation", 10)
	menu.add_child(race_row)
	var race_buttons: Array[Button] = []
	for race in ["Humain", "Orque", "Gobelin", "Nain"]:
		var race_button := Button.new()
		race_button.text = race.to_upper()
		race_button.custom_minimum_size = Vector2(127, 44)
		_style_button(race_button)
		race_button.pressed.connect(func():
			selected_race = race
			player.configure_race(selected_race)
			for button in race_buttons:
				button.modulate = Color.WHITE if button == race_button else Color("#6b6266")
		)
		race_row.add_child(race_button)
		race_buttons.append(race_button)
	play_button = Button.new()
	play_button.text = "CHARGEMENT DU MONDE…"
	play_button.position = Vector2(490, 430)
	play_button.size = Vector2(300, 58)
	play_button.disabled = true
	play_button.pressed.connect(_start_game)
	_style_button(play_button)
	menu.add_child(play_button)
	var settings := Button.new()
	settings.text = "COMMANDES"
	settings.position = Vector2(490, 500)
	settings.size = Vector2(300, 48)
	settings.pressed.connect(_open_controls_menu)
	_style_button(settings)
	menu.add_child(settings)
	var direction := Label.new()
	direction.text = "ACTION-RPG CUBIQUE  •  PROTOTYPE JOUABLE"
	direction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	direction.position = Vector2(0, 600)
	direction.size = Vector2(1280, 30)
	direction.add_theme_color_override("font_color", Color("#554d54"))
	menu.add_child(direction)
	boot_status = Label.new()
	boot_status.text = "INITIALISATION DU RENDU 3D…"
	boot_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_status.position = Vector2(0, 650)
	boot_status.size = Vector2(1280, 26)
	boot_status.add_theme_color_override("font_color", Color("#b79775"))
	menu.add_child(boot_status)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _start_game() -> void:
	if not world_ready or game_started:
		return
	game_started = true
	menu.queue_free()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.invulnerable_clock = 10.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_controls_menu() -> void:
	controls_panel = ColorRect.new()
	controls_panel.color = Color(0.018, 0.014, 0.023, 0.97)
	controls_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	controls_panel.visible = false
	$Interface.add_child(controls_panel)
	var title := Label.new()
	title.text = "COMMANDES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 54)
	title.size = Vector2(1280, 50)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#d3c4b0"))
	controls_panel.add_child(title)
	var hint := Label.new()
	hint.text = "Cliquez sur une commande, puis appuyez sur la touche ou le bouton de souris souhaité."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 108)
	hint.size = Vector2(1280, 32)
	hint.add_theme_color_override("font_color", Color("#8e8176"))
	controls_panel.add_child(hint)
	var list := VBoxContainer.new()
	list.position = Vector2(400, 158)
	list.size = Vector2(480, 400)
	list.add_theme_constant_override("separation", 8)
	controls_panel.add_child(list)
	for action in CONTROL_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		list.add_child(row)
		var action_label := Label.new()
		action_label.text = CONTROL_ACTIONS[action]
		action_label.custom_minimum_size = Vector2(245, 42)
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_label.add_theme_font_size_override("font_size", 16)
		action_label.add_theme_color_override("font_color", Color("#b8aa99"))
		row.add_child(action_label)
		var binding := Button.new()
		binding.custom_minimum_size = Vector2(210, 42)
		binding.text = _binding_text(action)
		binding.pressed.connect(_begin_rebinding.bind(action))
		_style_button(binding)
		row.add_child(binding)
		control_buttons[action] = binding
	var reset := Button.new()
	reset.text = "RÉTABLIR PAR DÉFAUT"
	reset.position = Vector2(400, 610)
	reset.size = Vector2(225, 44)
	reset.pressed.connect(_reset_controls)
	_style_button(reset)
	controls_panel.add_child(reset)
	var close := Button.new()
	close.text = "VALIDER ET REVENIR"
	close.position = Vector2(655, 610)
	close.size = Vector2(225, 44)
	close.pressed.connect(_close_controls_menu)
	_style_button(close)
	controls_panel.add_child(close)

func _open_controls_menu() -> void:
	controls_panel.visible = true
	controls_panel.move_to_front()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_DISABLED
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED

func _close_controls_menu() -> void:
	_cancel_rebinding()
	controls_panel.visible = false
	if game_started and is_instance_valid(player) and not player.is_dead:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		if enemies_active:
			for enemy in get_tree().get_nodes_in_group("enemy"):
				enemy.process_mode = Node.PROCESS_MODE_INHERIT
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _begin_rebinding(action: String) -> void:
	awaiting_action = action
	for action_name in control_buttons:
		control_buttons[action_name].disabled = action_name != action
	control_buttons[action].text = "APPUYEZ SUR UNE TOUCHE…"

func _cancel_rebinding() -> void:
	if not awaiting_action.is_empty() and control_buttons.has(awaiting_action):
		control_buttons[awaiting_action].text = _binding_text(awaiting_action)
	awaiting_action = ""
	for button in control_buttons.values():
		button.disabled = false

func _apply_binding(action: String, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	awaiting_action = ""
	for action_name in control_buttons:
		control_buttons[action_name].disabled = false
		control_buttons[action_name].text = _binding_text(action_name)
	_save_controls()

func _binding_text(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "NON ASSIGNÉ"
	return (events[0] as InputEvent).as_text().to_upper()

func _reset_controls() -> void:
	for action in DEFAULT_KEYS:
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = DEFAULT_KEYS[action]
		InputMap.action_add_event(action, event)
	var attack_click := InputEventMouseButton.new()
	attack_click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", attack_click)
	for action in control_buttons:
		control_buttons[action].text = _binding_text(action)
	_save_controls()

func _save_controls() -> void:
	var config := ConfigFile.new()
	for action in CONTROL_ACTIONS:
		var events := InputMap.action_get_events(action)
		if events.is_empty():
			continue
		var event := events[0]
		if event is InputEventKey:
			config.set_value(action, "type", "key")
			config.set_value(action, "code", event.physical_keycode)
		elif event is InputEventMouseButton:
			config.set_value(action, "type", "mouse")
			config.set_value(action, "code", event.button_index)
	config.save("user://controls.cfg")

func _load_controls() -> void:
	var config := ConfigFile.new()
	if config.load("user://controls.cfg") != OK:
		return
	for action in CONTROL_ACTIONS:
		if not config.has_section_key(action, "code"):
			continue
		var event_type: String = config.get_value(action, "type", "key")
		var code: int = config.get_value(action, "code", 0)
		var event: InputEvent
		if event_type == "mouse":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = code
			event = mouse_event
		else:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = code
			event = key_event
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)

func _hud_bar(color: Color, value_: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(340, 14)
	bar.max_value = 100.0
	bar.value = value_
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#0a090c")
	background.border_color = Color("#3c363d")
	background.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.border_color = color.lightened(0.16)
	fill.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#17131a")
	normal.border_color = Color("#6c4b3c")
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3
	var hover := normal.duplicate()
	hover.bg_color = Color("#2b1b1d")
	hover.border_color = Color("#b06d45")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("#d3c4b0"))

func _on_health_changed(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = maximum
		stamina_bar.value = current

func _on_player_died() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	death_overlay.visible = true

func _revive_player() -> void:
	player.revive()
	if enemies_active:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
	death_overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_enemy_defeated(_enemy: AshfallSoulsEnemy) -> void:
	enemies_alive = maxi(0, enemies_alive - 1)
	souls += 45
	if souls_label:
		souls_label.text = "NIV. 1  •  %s     ÂMES  %d     OMBRES  %d" % [
			selected_race.to_upper(), souls, enemies_alive
		]
	if enemies_alive == 0:
		_flash_message("ZONE PURIFIÉE  •  REPOSEZ-VOUS POUR RÉVEILLER LES OMBRES")

func _flash_message(text_: String) -> void:
	area_label.text = text_
	area_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(area_label, "modulate:a", 0.0, 1.2)

func _voxel_material(dark: Color, light: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform vec4 dark_color : source_color;
uniform vec4 light_color : source_color;
float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
void fragment() {
	vec3 cell = floor(VERTEX * 4.0);
	float grain = hash(cell);
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	ALBEDO = mix(dark_color.rgb, light_color.rgb, grain * 0.38);
	ROUGHNESS = 0.96;
	AO = 0.72 + grain * 0.25;
	ALBEDO *= (1.0 - edge * 0.18) * 1.34;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("dark_color", dark)
	material.set_shader_parameter("light_color", light)
	return material

func _emissive_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.6
	return material

func _static_box(
	parent: Node3D,
	size: Vector3,
	position_: Vector3,
	material: Material,
	rotation_ := Vector3.ZERO
) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.position = position_
	body.rotation = rotation_
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return mesh_instance
