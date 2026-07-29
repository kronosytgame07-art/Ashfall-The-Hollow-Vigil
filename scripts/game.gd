extends Node3D

const GRID_SIZE := 50
const TILE_SIZE := 2.0
const BUILDABLE_HALF := GRID_SIZE * TILE_SIZE * 0.5

var state := AshfallGameState.new()
var occupied: Dictionary = {}
var building_nodes: Dictionary = {}
var selected_kind := ""
var selected_id := -1
var selected_obstacle: Node3D
var placement_ghost: Node3D
var placement_cell := Vector2i(-99, -99)
var grid_root: Node3D
var buildings_root: Node3D
var obstacles_root: Node3D
var villagers_root: Node3D
var troops_root: Node3D
var resource_label: Label
var status_label: Label
var selection_title: Label
var selection_info: Label
var action_button: Button
var train_button: Button
var raid_button: Button
var hud_root: Control
var main_menu: Control
var game_started := false
var battle_controller: Node3D
var build_panel: PanelContainer
var detail_panel: PanelContainer
var autosave_clock := 0.0
var obstacle_respawn_clock := 0.0
const OBSTACLE_RESPAWN_SECONDS := 600.0
const MAX_OBSTACLES := 24

func _ready() -> void:
	_build_environment()
	_build_grid()
	_build_interface()
	if state.load_save():
		state.tick_production(_now())
		_restore_village()
		_set_status("Village restauré — progression hors ligne calculée.")
	else:
		_create_new_village()
	_spawn_villagers()
	_resume_active_builders()
	_add_village_paths()
	_add_village_atmosphere()
	_refresh_ui()

func _process(delta: float) -> void:
	if not game_started:
		return
	var now := _now()
	state.tick_production(now)
	autosave_clock += delta
	obstacle_respawn_clock += delta
	if obstacle_respawn_clock >= OBSTACLE_RESPAWN_SECONDS:
		obstacle_respawn_clock -= OBSTACLE_RESPAWN_SECONDS
		_spawn_random_obstacle()
	if autosave_clock >= 2.0:
		autosave_clock = 0.0
		state.save()
		_refresh_ui()
		_update_building_visuals(now)
	if placement_ghost:
		_update_placement_from_pointer()
	if Input.is_action_just_pressed("cancel_placement"):
		_clear_ghost()
		_set_status("Placement annulé.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		state.save()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if placement_ghost:
			_try_place(selected_kind, placement_cell)
		else:
			_select_at_pointer(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		if placement_ghost:
			_try_place(selected_kind, placement_cell)
		else:
			_select_at_pointer(event.position)

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#09080b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6d7480")
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color("#17131b")
	env.fog_density = 0.004
	environment.environment = env
	$World.add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-54, -32, 0)
	moon.light_color = Color("#c3c8d1")
	moon.light_energy = 1.05
	moon.shadow_enabled = true
	$World.add_child(moon)
	var outer_ground := MeshInstance3D.new()
	var outer_plane := PlaneMesh.new()
	outer_plane.size = Vector2(140, 140)
	outer_ground.mesh = outer_plane
	outer_ground.material_override = _outer_terrain_material()
	$World.add_child(outer_ground)
	var village_ground := MeshInstance3D.new()
	var village_plane := PlaneMesh.new()
	village_plane.size = Vector2(GRID_SIZE * TILE_SIZE, GRID_SIZE * TILE_SIZE)
	village_ground.mesh = village_plane
	village_ground.position.y = 0.015
	village_ground.material_override = _terrain_material()
	$World.add_child(village_ground)
	_add_ground_collision()
	var mountain_scene := load("res://models/environment/mountain_ring.glb") as PackedScene
	if mountain_scene:
		var mountains := mountain_scene.instantiate()
		mountains.scale = Vector3.ONE
		$World.add_child(mountains)
	grid_root = _new_root("Grid")
	buildings_root = _new_root("Buildings")
	obstacles_root = _new_root("Obstacles")
	villagers_root = _new_root("Villagers")
	troops_root = _new_root("Troops")

func _add_ground_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(140.0, 0.4, 140.0)
	collider.shape = shape
	collider.position.y = -0.2
	body.add_child(collider)
	$World.add_child(body)

func _new_root(root_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = root_name
	$World.add_child(root)
	return root

func _material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.metallic = metallic
	return mat

func _terrain_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#262229")
	mat.roughness = 0.98
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.055
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#343037"), Color("#514740"), Color("#6b5543")])
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	texture.color_ramp = gradient
	mat.albedo_texture = texture
	mat.uv1_scale = Vector3(5.0, 5.0, 5.0)
	var normal_noise := FastNoiseLite.new()
	normal_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	normal_noise.frequency = 0.12
	normal_noise.fractal_octaves = 5
	var normal_texture := NoiseTexture2D.new()
	normal_texture.width = 512
	normal_texture.height = 512
	normal_texture.seamless = true
	normal_texture.as_normal_map = true
	normal_texture.bump_strength = 3.5
	normal_texture.noise = normal_noise
	mat.normal_enabled = true
	mat.normal_texture = normal_texture
	mat.normal_scale = 0.48
	return mat

func _outer_terrain_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#151319"), Color("#29262d"), Color("#413b43")])
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	texture.color_ramp = gradient
	mat.albedo_texture = texture
	mat.uv1_scale = Vector3(3.5, 3.5, 3.5)
	var normal_noise := FastNoiseLite.new()
	normal_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	normal_noise.frequency = 0.085
	var normal_texture := NoiseTexture2D.new()
	normal_texture.width = 512
	normal_texture.height = 512
	normal_texture.seamless = true
	normal_texture.as_normal_map = true
	normal_texture.bump_strength = 4.0
	normal_texture.noise = normal_noise
	mat.normal_enabled = true
	mat.normal_texture = normal_texture
	mat.normal_scale = 0.56
	return mat

func _apply_mountain_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mountain_mat := StandardMaterial3D.new()
		mountain_mat.albedo_color = Color("#3d3940")
		mountain_mat.roughness = 1.0
		(node as MeshInstance3D).material_override = mountain_mat
	for child in node.get_children():
		_apply_mountain_material(child)

func _build_grid() -> void:
	var line_mat := _material(Color(0.34, 0.29, 0.31, 0.19))
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(GRID_SIZE + 1):
		var offset := -BUILDABLE_HALF + i * TILE_SIZE
		_add_box(grid_root, Vector3(0, 0.012, offset), Vector3(GRID_SIZE * TILE_SIZE, 0.018, 0.035), line_mat)
		_add_box(grid_root, Vector3(offset, 0.012, 0), Vector3(0.035, 0.018, GRID_SIZE * TILE_SIZE), line_mat)

func _add_box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.028, 0.025, 0.032, 0.88)
	style.border_color = Color("#6f4729")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _build_interface() -> void:
	var hud := Control.new()
	hud_root = hud
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Interface.add_child(hud)
	var top := _panel()
	top.position = Vector2(14, 12)
	top.size = Vector2(760, 68)
	hud.add_child(top)
	var top_box := VBoxContainer.new()
	top.add_child(top_box)
	var title := Label.new()
	title.text = "ASHFALL  •  THE HOLLOW VIGIL"
	title.add_theme_font_size_override("font_size", 17)
	top_box.add_child(title)
	resource_label = Label.new()
	top_box.add_child(resource_label)
	var build_toggle := Button.new()
	build_toggle.text = "  CONSTRUIRE"
	build_toggle.icon = load("res://ui/icons/icon_hammer.svg")
	build_toggle.icon_max_width = 28
	_style_button(build_toggle, Color("#a66536"))
	build_toggle.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	build_toggle.position = Vector2(14, -64)
	build_toggle.size = Vector2(170, 46)
	build_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(build_toggle)
	build_panel = _panel()
	build_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	build_panel.position = Vector2(14, -258)
	build_panel.size = Vector2(470, 184)
	build_panel.visible = false
	hud.add_child(build_panel)
	build_toggle.pressed.connect(func(): build_panel.visible = not build_panel.visible)
	var build_box := VBoxContainer.new()
	build_panel.add_child(build_box)
	var build_title := Label.new()
	build_title.text = "CONSTRUCTION"
	build_box.add_child(build_title)
	var buttons := HFlowContainer.new()
	build_box.add_child(buttons)
	for kind in BuildingFactory.FOOTPRINTS:
		var button := Button.new()
		var fp := BuildingFactory.footprint(kind)
		button.text = "%s %d×%d" % [BuildingFactory.label(kind), fp.x, fp.y]
		button.icon = load(_building_icon_path(kind))
		button.icon_max_width = 22
		_style_button(button, Color("#72513d"))
		button.pressed.connect(_begin_placement.bind(kind))
		buttons.add_child(button)
	detail_panel = _panel()
	detail_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	detail_panel.position = Vector2(-304, 12)
	detail_panel.size = Vector2(290, 218)
	detail_panel.visible = false
	hud.add_child(detail_panel)
	var detail_box := VBoxContainer.new()
	detail_panel.add_child(detail_box)
	selection_title = Label.new()
	selection_title.text = "VILLAGE"
	selection_title.add_theme_font_size_override("font_size", 19)
	detail_box.add_child(selection_title)
	selection_info = Label.new()
	selection_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_info.custom_minimum_size.y = 72
	detail_box.add_child(selection_info)
	action_button = Button.new()
	action_button.text = "Améliorer"
	_style_button(action_button, Color("#a66536"))
	action_button.pressed.connect(_selected_action)
	detail_box.add_child(action_button)
	var army_panel := _panel()
	army_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	army_panel.offset_left = -370
	army_panel.offset_top = -116
	army_panel.offset_right = -14
	army_panel.offset_bottom = -18
	hud.add_child(army_panel)
	var army_box := VBoxContainer.new()
	army_panel.add_child(army_box)
	train_button = Button.new()
	train_button.text = "  Entraîner un guerrier"
	train_button.icon = load("res://ui/icons/icon_shield.svg")
	train_button.icon_max_width = 26
	_style_button(train_button, Color("#8e4a37"))
	train_button.pressed.connect(_train_warrior)
	army_box.add_child(train_button)
	raid_button = Button.new()
	raid_button.text = "  Lancer une expédition"
	raid_button.icon = load("res://ui/icons/icon_swords.svg")
	raid_button.icon_max_width = 26
	_style_button(raid_button, Color("#a66536"))
	raid_button.pressed.connect(_launch_raid)
	army_box.add_child(raid_button)
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.position = Vector2(200, -54)
	status_label.size = Vector2(720, 38)
	status_label.add_theme_color_override("font_color", Color("#e8c58d"))
	hud.add_child(status_label)
	_build_main_menu()

func _build_main_menu() -> void:
	main_menu = Control.new()
	main_menu.name = "MainMenu"
	main_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	main_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	$Interface.add_child(main_menu)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#08070b")
	main_menu.add_child(backdrop)
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-340, -255)
	frame.size = Vector2(680, 510)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("#17131bee")
	frame_style.border_color = Color("#7d4b2d")
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(18)
	frame.add_theme_stylebox_override("panel", frame_style)
	main_menu.add_child(frame)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(600, 440)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	frame.add_child(box)
	var title := Label.new()
	title.text = "ASHFALL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 50)
	title.add_theme_color_override("font_color", Color("#e7c28b"))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "THE HOLLOW VIGIL\nBâtissez dans les cendres. Survivez à la nuit."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color("#a79ba7"))
	box.add_child(subtitle)
	var village_button := _menu_button("  CONTINUER LE VILLAGE", "res://ui/icons/icon_town.svg")
	village_button.pressed.connect(_enter_village)
	box.add_child(village_button)
	var combat_button := _menu_button("  COMBAT PVPVE", "res://ui/icons/icon_swords.svg")
	combat_button.pressed.connect(_enter_pvpve_battle)
	box.add_child(combat_button)
	var settings_button := _menu_button("  OPTIONS", "res://ui/icons/icon_settings.svg")
	box.add_child(settings_button)
	var option_row := HBoxContainer.new()
	option_row.visible = false
	option_row.alignment = BoxContainer.ALIGNMENT_CENTER
	option_row.add_theme_constant_override("separation", 12)
	box.add_child(option_row)
	var sound_button := Button.new()
	sound_button.text = "SON : ACTIVÉ"
	sound_button.custom_minimum_size = Vector2(220, 44)
	sound_button.pressed.connect(func():
		var muted := not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
		sound_button.text = "SON : COUPÉ" if muted else "SON : ACTIVÉ"
	)
	option_row.add_child(sound_button)
	var fullscreen_button := Button.new()
	fullscreen_button.text = "PLEIN ÉCRAN"
	fullscreen_button.custom_minimum_size = Vector2(220, 44)
	fullscreen_button.pressed.connect(func():
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	)
	option_row.add_child(fullscreen_button)
	settings_button.pressed.connect(func(): option_row.visible = not option_row.visible)
	hud_root.visible = false
	$World.visible = false

func _menu_button(label: String, icon_path: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(560, 62)
	button.add_theme_font_size_override("font_size", 18)
	var icon := load(icon_path) as Texture2D
	if icon:
		button.icon = icon
		button.icon_max_width = 32
	_style_button(button, Color("#a66536"))
	return button

func _style_button(button: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#161219")
	normal.border_color = accent
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#2b2026")
	hover.border_color = accent.lightened(0.2)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#4a2922")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)

func _building_icon_path(kind: String) -> String:
	if kind in ["barracks", "army_camp", "tower", "wall"]:
		return "res://ui/icons/icon_shield.svg"
	if kind in ["sawmill", "builders_yard", "forge"]:
		return "res://ui/icons/icon_hammer.svg"
	if kind in ["laboratory", "spell_hall", "soul_altar"]:
		return "res://ui/icons/icon_settings.svg"
	return "res://ui/icons/icon_town.svg"

func _enter_village() -> void:
	game_started = true
	main_menu.visible = false
	$World.visible = true
	hud_root.visible = true

func _enter_pvpve_battle() -> void:
	game_started = true
	main_menu.visible = false
	hud_root.visible = false
	$World.visible = true
	_set_village_roots_visible(false)
	var battle_script := load("res://scripts/pvpve_battle.gd")
	battle_controller = battle_script.new()
	battle_controller.name = "PVPVEBattle"
	battle_controller.connect("exit_requested", Callable(self, "_leave_pvpve_battle"))
	$World.add_child(battle_controller)

func _leave_pvpve_battle() -> void:
	if is_instance_valid(battle_controller):
		battle_controller.queue_free()
	battle_controller = null
	_set_village_roots_visible(true)
	game_started = false
	hud_root.visible = false
	$World.visible = false
	main_menu.visible = true

func _set_village_roots_visible(value: bool) -> void:
	for root in [buildings_root, obstacles_root, villagers_root, troops_root, grid_root]:
		if is_instance_valid(root):
			root.visible = value
			root.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
			for body in root.find_children("*", "CollisionObject3D", true, false):
				var collision_object := body as CollisionObject3D
				if value:
					collision_object.collision_layer = int(collision_object.get_meta("village_collision_layer", 1))
					collision_object.collision_mask = int(collision_object.get_meta("village_collision_mask", 0))
				else:
					collision_object.set_meta("village_collision_layer", collision_object.collision_layer)
					collision_object.set_meta("village_collision_mask", collision_object.collision_mask)
					collision_object.collision_layer = 0
					collision_object.collision_mask = 0
	for root_name in ["VillagePaths", "ScorchedGroundTiles"]:
		var root := $World.get_node_or_null(root_name)
		if root:
			root.visible = value

func _create_new_village() -> void:
	_add_building_record("town_hall", Vector2i(23, 23), 1, 0)
	_add_building_record("gold_mine", Vector2i(18, 22), 1, 0)
	_add_building_record("sawmill", Vector2i(18, 26), 1, 0)
	_add_building_record("barracks", Vector2i(29, 24), 1, 0)
	_add_building_record("army_camp", Vector2i(28, 28), 1, 0)
	_add_building_record("builders_yard", Vector2i(22, 29), 1, 0)
	state.last_update = _now()
	for cell in [Vector2i(16, 17), Vector2i(33, 18), Vector2i(18, 32), Vector2i(31, 31)]:
		_spawn_obstacle(cell, true)
	state.save()

func _restore_village() -> void:
	for index in range(state.buildings.size()):
		var data := state.buildings[index]
		var cell_data: Array = data.get("cell", [0, 0])
		if cell_data.size() < 2:
			continue
		var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
		_mark_occupied(str(data.kind), cell)
		_spawn_building_node(index)
	if not state.obstacle_data_initialized:
		for cell in [Vector2i(16, 17), Vector2i(33, 18), Vector2i(18, 32), Vector2i(31, 31)]:
			if not occupied.has(cell):
				_spawn_obstacle(cell, true)
	else:
		for obstacle_data in state.obstacles:
			var obstacle_cell: Array = obstacle_data.get("cell", [])
			if obstacle_cell.size() >= 2:
				var cell := Vector2i(int(obstacle_cell[0]), int(obstacle_cell[1]))
				if not occupied.has(cell):
					_spawn_obstacle(cell)

func _add_building_record(kind: String, cell: Vector2i, level: int, finish_at: int) -> int:
	var data := {"kind": kind, "cell": [cell.x, cell.y], "level": level, "finish_at": finish_at, "stored": 0.0}
	state.buildings.append(data)
	var index := state.buildings.size() - 1
	_mark_occupied(kind, cell)
	_spawn_building_node(index)
	return index

func _mark_occupied(kind: String, cell: Vector2i) -> void:
	var fp := BuildingFactory.footprint(kind)
	for y in range(fp.y):
		for x in range(fp.x):
			occupied[cell + Vector2i(x, y)] = kind

func _spawn_building_node(index: int) -> void:
	var data := state.buildings[index]
	var kind := str(data.kind)
	var cell_data: Array = data.cell
	if cell_data.size() < 2:
		return
	var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
	var fp := BuildingFactory.footprint(kind)
	var building := BuildingFactory.create(kind, int(data.level))
	building.position = _cell_center(cell, fp)
	building.set_meta("building_id", index)
	building.set_meta("level", int(data.level))
	buildings_root.add_child(building)
	_add_footprint_base(building, fp)
	_add_building_collision(building, fp, index)
	building_nodes[index] = building
	_update_one_building_visual(index, _now())

func _add_footprint_base(building: Node3D, fp: Vector2i) -> void:
	var base := _add_box(building, Vector3(0, 0.045, 0), Vector3(fp.x * TILE_SIZE * 0.9, 0.09, fp.y * TILE_SIZE * 0.9), _material(Color("#201d22")))
	building.move_child(base, 0)

func _add_building_collision(building: Node3D, fp: Vector2i, index: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("building_id", index)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(fp.x * TILE_SIZE * 0.9, 3.0, fp.y * TILE_SIZE * 0.9)
	collision.shape = box
	collision.position.y = 1.5
	body.add_child(collision)
	building.add_child(body)

func _try_place(kind: String, cell: Vector2i) -> void:
	var fp := BuildingFactory.footprint(kind)
	if not _can_place(cell, fp):
		_set_status("Cette zone est occupée.")
		return
	var now := _now()
	if state.free_builders(now) <= 0:
		_set_status("Tous les bâtisseurs sont occupés.")
		return
	var cost := BuildingFactory.cost(kind)
	if not state.spend(cost):
		_set_status("Ressources insuffisantes : %s" % _format_cost(cost))
		return
	var finish_at := now + BuildingFactory.build_time(kind)
	var index := _add_building_record(kind, cell, 1, finish_at)
	_add_village_paths()
	_clear_ghost()
	selected_id = index
	_assign_builder(building_nodes[index].global_position)
	state.save()
	_refresh_ui()
	_set_status("%s en construction." % BuildingFactory.label(kind))

func _begin_placement(kind: String) -> void:
	selected_kind = kind
	_clear_ghost()
	placement_ghost = BuildingFactory.create(kind)
	_set_transparency(placement_ghost, 0.52)
	$World.add_child(placement_ghost)
	var fp := BuildingFactory.footprint(kind)
	_set_status("Placement %s — empreinte réelle %d×%d — Échap pour annuler." % [BuildingFactory.label(kind), fp.x, fp.y])

func _update_placement_from_pointer() -> void:
	var camera := $CameraRig/Camera3D as Camera3D
	var pointer := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(pointer)
	var direction := camera.project_ray_normal(pointer)
	if absf(direction.y) < 0.0001:
		return
	var hit := origin + direction * (-origin.y / direction.y)
	placement_cell = _world_to_cell(hit)
	var fp := BuildingFactory.footprint(selected_kind)
	placement_ghost.position = _cell_center(placement_cell, fp)
	_tint_ghost(_can_place(placement_cell, fp))

func _select_at_pointer(pointer: Vector2) -> void:
	var camera := $CameraRig/Camera3D as Camera3D
	var query := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(pointer), camera.project_ray_origin(pointer) + camera.project_ray_normal(pointer) * 200.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		selected_id = -1
		selected_obstacle = null
	else:
		var collider = hit.get("collider")
		if collider and collider.has_meta("obstacle_root"):
			selected_id = -1
			selected_obstacle = collider.get_meta("obstacle_root") as Node3D
		else:
			selected_obstacle = null
			selected_id = int(collider.get_meta("building_id", -1)) if collider else -1
	_refresh_ui()

func _selected_action() -> void:
	if is_instance_valid(selected_obstacle):
		_remove_selected_obstacle()
		return
	if selected_id < 0 or selected_id >= state.buildings.size():
		return
	var data := state.buildings[selected_id]
	var now := _now()
	if int(data.finish_at) > now:
		var gems_needed := ceili((int(data.finish_at) - now) / 10.0)
		if int(state.resources.gems) < gems_needed:
			_set_status("Il faut %d gemmes pour terminer maintenant." % gems_needed)
			return
		state.resources.gems -= gems_needed
		data.finish_at = now
		_set_status("Construction terminée.")
	elif float(data.get("stored", 0.0)) >= 1.0:
		var definition := BuildingFactory.definition(str(data.kind))
		var resource := str(definition.get("produces", ""))
		var amount := floori(float(data.stored))
		state.add_resource(resource, amount)
		data.stored = 0.0
		_set_status("+%d %s collectés." % [amount, resource])
	else:
		_upgrade_selected()
	state.save()
	_refresh_ui()
	_update_one_building_visual(selected_id, now)

func _upgrade_selected() -> void:
	var data := state.buildings[selected_id]
	var kind := str(data.kind)
	var level := int(data.level)
	var definition := BuildingFactory.definition(kind)
	if level >= int(definition.get("max_level", 10)):
		_set_status("Niveau maximum atteint.")
		return
	if state.free_builders(_now()) <= 0:
		_set_status("Aucun bâtisseur disponible.")
		return
	var cost := BuildingFactory.cost(kind, level + 1)
	if not state.spend(cost):
		_set_status("Amélioration impossible : %s" % _format_cost(cost))
		return
	data.level = level + 1
	data.finish_at = _now() + BuildingFactory.build_time(kind, level + 1)
	building_nodes[selected_id].set_meta("level", data.level)
	BuildingFactory.apply_level_visual(building_nodes[selected_id], int(data.level))
	_assign_builder(building_nodes[selected_id].global_position)
	_set_status("%s passe au niveau %d." % [BuildingFactory.label(kind), data.level])

func _train_warrior() -> void:
	var cost := {"gold": 100, "wood": 45}
	if not state.spend(cost):
		_set_status("Pas assez de ressources pour entraîner un guerrier.")
		return
	state.army.warrior = int(state.army.warrior) + 1
	if troops_root.get_child_count() < 48:
		var unit := AshfallCombatUnit.new()
		unit.kind = AshfallCombatUnit.UnitKind.WARRIOR
		var slot := troops_root.get_child_count()
		var camp_center := _army_camp_center()
		unit.position = _camp_exit_position(slot, camp_center)
		troops_root.add_child(unit)
		unit.enable_roaming(camp_center, BUILDABLE_HALF - 4.0)
	state.save()
	_refresh_ui()
	_set_status("Guerrier entraîné et déployé au camp.")

func _launch_raid() -> void:
	var strength := int(state.army.warrior) * 12 + int(state.army.archer) * 15 + int(state.army.brute) * 34
	if strength < 30:
		_set_status("Armée trop faible pour une expédition.")
		return
	var victory := strength + randi_range(0, 45) >= 65
	if victory:
		var gold := 120 + randi_range(0, strength * 3)
		var wood := 90 + randi_range(0, strength * 2)
		state.add_resource("gold", gold)
		state.add_resource("wood", wood)
		state.trophies += 12
		_set_status("Victoire ! Butin : %d or, %d bois, +12 trophées." % [gold, wood])
	else:
		state.trophies = maxi(0, state.trophies - 5)
		_set_status("Expédition repoussée. Renforcez l'armée et la forge.")
	for unit in troops_root.get_children():
		if unit is AshfallCombatUnit:
			unit.attack()
	state.save()
	_refresh_ui()

func _add_village_paths() -> void:
	if building_nodes.is_empty():
		return
	var previous := $World.get_node_or_null("VillagePaths")
	if previous:
		previous.name = "RetiredVillagePaths"
		previous.queue_free()
	var hub := Vector3.ZERO
	for index in building_nodes:
		if str(state.buildings[int(index)].kind) == "town_hall":
			hub = building_nodes[index].global_position
			break
	var path_root := _new_root("VillagePaths")
	var network_points: Array[Vector3] = [hub]
	var pending: Array[Vector3] = []
	for index in building_nodes:
		var destination: Vector3 = building_nodes[index].global_position
		if destination.distance_to(hub) >= 1.0:
			pending.append(destination)
	while not pending.is_empty():
		var best_destination_index := 0
		var best_anchor := hub
		var best_distance := INF
		for destination_index in range(pending.size()):
			for anchor in network_points:
				var distance := pending[destination_index].distance_squared_to(anchor)
				if distance < best_distance:
					best_distance = distance
					best_destination_index = destination_index
					best_anchor = anchor
		var destination := pending[best_destination_index]
		var new_points := _lay_road_segment(path_root, best_anchor, destination)
		network_points.append_array(new_points)
		network_points.append(destination)
		pending.remove_at(best_destination_index)

func _lay_road_segment(path_root: Node3D, start: Vector3, finish: Vector3) -> Array[Vector3]:
	var direction := finish - start
	direction.y = 0.0
	var length := maxf(0.0, direction.length() - 2.4)
	var samples: Array[Vector3] = []
	if length < 0.8:
		return samples
	var forward := direction.normalized()
	var count := maxi(2, ceili(length / 0.72))
	var right := Vector3(forward.z, 0.0, -forward.x)
	var phase := fmod(absf(start.x * 0.17 + start.z * 0.31 + finish.x * 0.13), TAU)
	var points: Array[Vector3] = []
	for point_index in range(count + 1):
		var distance := 1.2 + point_index * length / count
		var t := point_index / float(count)
		var wandering := sin(t * PI) * sin(t * TAU + phase) * minf(1.65, length * 0.11)
		wandering += sin(float(point_index) * 1.73 + phase) * 0.11 * sin(t * PI)
		var position := start + forward * distance + right * wandering
		position.y = 0.032
		points.append(position)
		if point_index % 3 == 0:
			samples.append(position)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment_index in range(points.size() - 1):
		var p0 := points[segment_index]
		var p1 := points[segment_index + 1]
		var tangent := (p1 - p0).normalized()
		var lateral := Vector3(tangent.z, 0.0, -tangent.x)
		var width0 := 0.72 + sin(float(segment_index) * 2.17 + phase) * 0.12
		var width1 := 0.72 + sin(float(segment_index + 1) * 2.17 + phase) * 0.12
		var a := p0 - lateral * width0
		var b := p0 + lateral * width0
		var c := p1 + lateral * width1
		var d := p1 - lateral * width1
		for vertex in [a, b, c, a, c, d]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(vertex)
	var road := MeshInstance3D.new()
	road.name = "IrregularAshRoad"
	road.mesh = surface.commit()
	road.material_override = BuildingFactory.make_textured_material("earth", Color("#45372e"))
	path_root.add_child(road)
	return samples

func _spawn_random_obstacle() -> void:
	if obstacles_root == null or obstacles_root.get_child_count() >= MAX_OBSTACLES:
		return
	for attempt in range(120):
		var cell := Vector2i(randi_range(1, GRID_SIZE - 2), randi_range(1, GRID_SIZE - 2))
		if not occupied.has(cell):
			_spawn_obstacle(cell, true)
			_set_status("Un nouvel obstacle est apparu dans le village.")
			return

func _add_village_atmosphere() -> void:
	var patches := _new_root("AshAndEarthPatches")
	for i in range(26):
		var angle := float(i) * 2.399
		var radius := 5.0 + float((i * 7) % 17)
		var patch := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.7 + float(i % 4) * 0.38
		disc.bottom_radius = disc.top_radius * 1.08
		disc.height = 0.025
		disc.radial_segments = 9
		patch.mesh = disc
		patch.position = Vector3(cos(angle) * radius, 0.018, sin(angle) * radius)
		patch.scale.z = 0.55 + float(i % 3) * 0.17
		patch.rotation.y = angle
		patch.material_override = _material(Color("#58483b") if i % 4 == 0 else Color("#29262b"))
		patches.add_child(patch)
	for index in building_nodes:
		var kind := str(state.buildings[int(index)].kind)
		if kind != "town_hall" and kind != "army_camp" and kind != "forge":
			continue
		var light := OmniLight3D.new()
		light.name = kind.to_pascal_case() + "WarmLight"
		light.position = building_nodes[index].global_position + Vector3(0, 2.2 if kind == "town_hall" else 1.1, 0)
		light.light_color = Color("#ff7a2f")
		light.light_energy = 3.2 if kind == "town_hall" else 2.1
		light.omni_range = 8.0 if kind == "town_hall" else 5.0
		light.shadow_enabled = true
		$World.add_child(light)

func _spawn_villagers() -> void:
	for i in range(state.builders_total + 3):
		var villager := AshfallVillager.new()
		villager.position = Vector3(-5.0 + i * 2.0, 0.0, 6.0 + (i % 2) * 1.8)
		villager.stride_phase = i * 1.1
		villagers_root.add_child(villager)
	var camp_center := _army_camp_center()
	for i in range(mini(int(state.army.warrior), 48)):
		var unit := AshfallCombatUnit.new()
		unit.kind = AshfallCombatUnit.UnitKind.WARRIOR if i % 3 else AshfallCombatUnit.UnitKind.ARCHER
		unit.position = _camp_exit_position(i, camp_center)
		troops_root.add_child(unit)
		unit.enable_roaming(camp_center, BUILDABLE_HALF - 4.0)

func _army_camp_center() -> Vector3:
	for index in building_nodes:
		if str(state.buildings[int(index)].kind) == "army_camp":
			return building_nodes[index].global_position
	return Vector3(9.0, 0.0, 9.0)

func _camp_exit_position(slot: int, center: Vector3) -> Vector3:
	var angle := TAU * float(posmod(slot, 12)) / 12.0
	var radius := 3.8 + float(slot % 3) * 0.35
	return center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func _assign_builder(target: Vector3) -> void:
	for villager in villagers_root.get_children():
		if villager is AshfallVillager and (villager.state == AshfallVillager.State.WALK or villager.state == AshfallVillager.State.IDLE):
			villager.set_work_target(target + Vector3(3.4, 0, 0.6))
			return

func _resume_active_builders() -> void:
	var now := _now()
	for index in building_nodes:
		if int(state.buildings[int(index)].finish_at) > now:
			_assign_builder(building_nodes[index].global_position)

func _spawn_obstacle(cell: Vector2i, record := false) -> void:
	occupied[cell] = "obstacle"
	if record:
		state.obstacles.append({"cell": [cell.x, cell.y]})
	var root := Node3D.new()
	root.position = _cell_center(cell, Vector2i.ONE)
	root.set_meta("cell", cell)
	obstacles_root.add_child(root)
	_add_box(root, Vector3(0, 0.06, 0), Vector3(TILE_SIZE * 0.96, 0.12, TILE_SIZE * 0.96), _material(Color("#302b31")))
	var paths := ["corrupted_rocks", "dead_tree", "bones", "soul_crystals"]
	var scene := load("res://models/obstacles/%s.glb" % paths[posmod(cell.x + cell.y, paths.size())]) as PackedScene
	if scene:
		var obstacle_model := scene.instantiate()
		BuildingFactory.apply_art_direction(obstacle_model)
		root.add_child(obstacle_model)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("obstacle_root", root)
	body.set_meta("obstacle_cell", cell)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(TILE_SIZE * 0.92, 1.8, TILE_SIZE * 0.92)
	collision.shape = shape
	collision.position.y = 0.9
	body.add_child(collision)
	root.add_child(body)

func _remove_selected_obstacle() -> void:
	const REMOVAL_COST := 75
	if int(state.resources.gold) < REMOVAL_COST:
		_set_status("Il faut %d or pour détruire cet obstacle." % REMOVAL_COST)
		return
	state.resources.gold -= REMOVAL_COST
	var cell: Vector2i = selected_obstacle.get_meta("cell", _world_to_cell(selected_obstacle.global_position))
	occupied.erase(cell)
	for obstacle_index in range(state.obstacles.size() - 1, -1, -1):
		var stored_cell: Array = state.obstacles[obstacle_index].get("cell", [])
		if stored_cell.size() >= 2 and int(stored_cell[0]) == cell.x and int(stored_cell[1]) == cell.y:
			state.obstacles.remove_at(obstacle_index)
			break
	var reward_gems := randi_range(1, 3) if randf() < 0.35 else 0
	if reward_gems > 0:
		state.resources.gems += reward_gems
		_set_status("Obstacle détruit : -%d or, +%d gemme%s." % [REMOVAL_COST, reward_gems, "s" if reward_gems > 1 else ""])
	else:
		var reward_xp := randi_range(8, 20)
		state.account_xp += reward_xp
		_set_status("Obstacle détruit : -%d or, +%d XP." % [REMOVAL_COST, reward_xp])
	selected_obstacle.queue_free()
	selected_obstacle = null
	state.save()
	_refresh_ui()

func _update_building_visuals(now: int) -> void:
	var has_active_construction := false
	for index in building_nodes:
		if int(state.buildings[int(index)].finish_at) > now:
			has_active_construction = true
		_update_one_building_visual(int(index), now)
	if not has_active_construction:
		for villager in villagers_root.get_children() if villagers_root else []:
			if villager is AshfallVillager and villager.state == AshfallVillager.State.WORK:
				villager.stop_work()

func _update_one_building_visual(index: int, now: int) -> void:
	if not building_nodes.has(index):
		return
	var data := state.buildings[index]
	var node: Node3D = building_nodes[index]
	var constructing := int(data.finish_at) > now
	BuildingFactory.apply_level_visual(node, int(data.get("level", 1)))
	if constructing:
		node.scale *= 0.82
	if constructing:
		for villager in villagers_root.get_children() if villagers_root else []:
			if villager is AshfallVillager and villager.state == AshfallVillager.State.RUN and villager.target.distance_to(node.global_position) < 4.0:
				villager.start_work()

func _refresh_ui() -> void:
	var now := _now()
	resource_label.text = "OR  %d     BOIS  %d     ÂMES  %d     GEMMES  %d     XP  %d     🏆 %d     BÂTISSEURS  %d/%d" % [
		state.resources.gold, state.resources.wood, state.resources.souls, state.resources.gems,
		state.account_xp, state.trophies, state.free_builders(now), state.builders_total
	]
	train_button.text = "Entraîner guerrier (100 or / 45 bois)  •  Armée %d" % int(state.army.warrior)
	if is_instance_valid(selected_obstacle):
		detail_panel.visible = true
		selection_title.text = "OBSTACLE"
		selection_info.text = "Détruire cet obstacle coûte 75 or.\nRécompense : gemmes ou expérience."
		action_button.visible = true
		action_button.text = "Détruire — 75 or"
		return
	if selected_id < 0 or selected_id >= state.buildings.size():
		detail_panel.visible = false
		selection_title.text = "VILLAGE"
		selection_info.text = "Sélectionnez un bâtiment pour collecter sa production ou l'améliorer.\nLa progression est sauvegardée automatiquement."
		action_button.visible = false
		return
	detail_panel.visible = true
	var data := state.buildings[selected_id]
	var kind := str(data.kind)
	var remaining := maxi(0, int(data.finish_at) - now)
	selection_title.text = "%s  •  NIV. %d" % [BuildingFactory.label(kind).to_upper(), int(data.level)]
	var definition := BuildingFactory.definition(kind)
	if remaining > 0:
		selection_info.text = "Construction : %d s restantes\nEmpreinte : %d×%d cases" % [remaining, BuildingFactory.footprint(kind).x, BuildingFactory.footprint(kind).y]
		action_button.text = "Terminer maintenant (%d gemmes)" % ceili(remaining / 10.0)
	elif definition.has("produces"):
		var stored := floori(float(data.get("stored", 0.0)))
		selection_info.text = "Production : %s\nStock : %d / %d\nCliquez pour collecter, puis améliorez lorsque le stock est vide." % [str(definition.produces).capitalize(), stored, int(float(definition.capacity) * (1.0 + (int(data.level) - 1) * 0.5))]
		action_button.text = "Collecter %d" % stored if stored > 0 else "Améliorer — %s" % _format_cost(BuildingFactory.cost(kind, int(data.level) + 1))
	else:
		selection_info.text = "Empreinte : %d×%d cases\nÉtat : opérationnel\nPuissance renforcée à chaque niveau." % [BuildingFactory.footprint(kind).x, BuildingFactory.footprint(kind).y]
		action_button.text = "Améliorer — %s" % _format_cost(BuildingFactory.cost(kind, int(data.level) + 1))
	action_button.visible = true

func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource in cost:
		if int(cost[resource]) > 0:
			parts.append("%d %s" % [int(cost[resource]), str(resource)])
	return " / ".join(parts)

func _set_status(message: String) -> void:
	status_label.text = message

func _can_place(cell: Vector2i, fp: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x + fp.x > GRID_SIZE or cell.y + fp.y > GRID_SIZE:
		return false
	for y in range(fp.y):
		for x in range(fp.x):
			if occupied.has(cell + Vector2i(x, y)):
				return false
	return true

func _cell_center(cell: Vector2i, fp: Vector2i) -> Vector3:
	return Vector3(-BUILDABLE_HALF + (cell.x + fp.x * 0.5) * TILE_SIZE, 0.0, -BUILDABLE_HALF + (cell.y + fp.y * 0.5) * TILE_SIZE)

func _world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(floori((world.x + BUILDABLE_HALF) / TILE_SIZE), floori((world.z + BUILDABLE_HALF) / TILE_SIZE))

func _set_transparency(node: Node, alpha: float) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			var source := mesh.material_override as StandardMaterial3D
			if source:
				var mat := source.duplicate() as StandardMaterial3D
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = alpha
				mesh.material_override = mat
		_set_transparency(child, alpha)

func _tint_ghost(valid: bool) -> void:
	for child in placement_ghost.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var mat := mesh.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(0.34, 0.92, 0.48, 0.52) if valid else Color(0.95, 0.2, 0.16, 0.52)

func _clear_ghost() -> void:
	if is_instance_valid(placement_ghost):
		placement_ghost.queue_free()
	placement_ghost = null
