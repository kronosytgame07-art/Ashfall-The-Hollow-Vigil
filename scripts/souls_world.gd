extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/souls_player.gd")
const ENEMY_SCRIPT := preload("res://scripts/souls_enemy.gd")
const WORLD_HALF := 30

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
var fire_light: OmniLight3D

func _ready() -> void:
	_ensure_input_actions()
	_build_environment()
	_build_voxel_world()
	_build_ruins()
	_build_checkpoint()
	_spawn_player()
	_spawn_enemies()
	_build_interface()
	_show_title_menu()

func _process(delta: float) -> void:
	if fire_light:
		fire_light.light_energy = 2.7 + sin(Time.get_ticks_msec() * 0.012) * 0.42
	if not is_instance_valid(player) or player.is_dead:
		return
	var distance_to_fire := player.global_position.distance_to(checkpoint_position)
	prompt_label.visible = distance_to_fire < 3.0
	if distance_to_fire < 3.0 and Input.is_action_just_pressed("interact"):
		player.rest_at(checkpoint_position)
		_respawn_enemies()
		_flash_message("REPOS ACCORDÉ  •  LES OMBRES REVIENNENT")
	if player.global_position.y < -8.0:
		player.take_damage(999.0)

func _ensure_input_actions() -> void:
	var actions := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"sprint": KEY_SHIFT,
		"dodge": KEY_SPACE,
		"attack": KEY_F,
		"interact": KEY_E,
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var event := InputEventKey.new()
			event.physical_keycode = actions[action]
			InputMap.action_add_event(action, event)
	if InputMap.action_get_events("attack").size() == 1:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", click)

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
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
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 1.25
	environment.fog_enabled = true
	environment.fog_light_color = Color("#17131d")
	environment.fog_density = 0.018
	environment.fog_height = 1.2
	environment.fog_height_density = 0.16
	world_environment.environment = environment
	$World.add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48, -28, 0)
	moon.light_color = Color("#9ca9c7")
	moon.light_energy = 1.05
	moon.shadow_enabled = true
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
	for x in range(-WORLD_HALF, WORLD_HALF, 2):
		for z in range(-WORLD_HALF, WORLD_HALF, 2):
			var distance := Vector2(x, z).length()
			if distance > WORLD_HALF + rng.randf_range(-2.0, 2.0):
				continue
			var height := rng.randf_range(0.16, 0.34)
			if distance > 24.0:
				height += rng.randf_range(0.0, 2.8) * pow((distance - 24.0) / 7.0, 1.8)
			var region_materials: Array = ground_materials
			if x <= -12:
				region_materials = snow_materials
			elif x >= 12:
				region_materials = volcanic_materials
			var tile := _static_box(
				$World,
				Vector3(2.03, height, 2.03),
				Vector3(x, -height * 0.5, z),
				region_materials[rng.randi_range(0, region_materials.size() - 1)]
			)
			tile.rotation.y = rng.randf_range(-0.025, 0.025)
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
	player.position = checkpoint_position
	$Actors.add_child(player)
	player.configure_race(selected_race)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.health_changed.connect(_on_health_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	player.died.connect(_on_player_died)

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
		if not game_started:
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemies_alive += 1

func _respawn_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
	enemies_alive = 0
	call_deferred("_spawn_enemies")

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
	souls_label.text = "NIV. 1  •  %s     ÂMES  0     OMBRES  %d" % [selected_race.upper(), enemies_alive]
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
	_build_death_overlay(hud)

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
	var play := Button.new()
	play.text = "ENTRER DANS LE MONDE"
	play.position = Vector2(490, 430)
	play.size = Vector2(300, 58)
	play.pressed.connect(func():
		game_started = true
		menu.queue_free()
		player.process_mode = Node.PROCESS_MODE_INHERIT
		for enemy in get_tree().get_nodes_in_group("enemy"):
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)
	_style_button(play)
	menu.add_child(play)
	var direction := Label.new()
	direction.text = "ACTION-RPG CUBIQUE  •  PROTOTYPE JOUABLE"
	direction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	direction.position = Vector2(0, 600)
	direction.size = Vector2(1280, 30)
	direction.add_theme_color_override("font_color", Color("#554d54"))
	menu.add_child(direction)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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
	death_overlay.visible = true

func _revive_player() -> void:
	player.revive()
	death_overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_enemy_defeated(_enemy: AshfallSoulsEnemy) -> void:
	enemies_alive = maxi(0, enemies_alive - 1)
	souls += 45
	if souls_label:
		souls_label.text = "NIV. 1  •  %s     ÂMES  %d     OMBRES  %d" % [
			selected_race.upper(), souls, enemies_alive
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
	ALBEDO *= 1.0 - edge * 0.18;
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
