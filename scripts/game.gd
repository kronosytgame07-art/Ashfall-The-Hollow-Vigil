extends Node3D

const GRID_SIZE := 24
const TILE_SIZE := 2.0
const BUILDABLE_HALF := GRID_SIZE * TILE_SIZE * 0.5

var occupied: Dictionary = {}
var selected_kind := "gold_mine"
var placement_ghost: Node3D
var placement_cell := Vector2i(-99, -99)
var grid_root: Node3D
var buildings_root: Node3D
var obstacles_root: Node3D
var villagers_root: Node3D
var status_label: Label
var selection_label: Label

func _ready() -> void:
	_build_environment()
	_build_grid()
	_build_interface()
	_spawn_initial_village()
	_spawn_villagers()
	_select_building("gold_mine")

func _process(_delta: float) -> void:
	if placement_ghost:
		_update_placement_from_pointer()
	if Input.is_action_just_pressed("cancel_placement"):
		_clear_ghost()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if placement_ghost and _can_place(placement_cell, BuildingFactory.footprint(selected_kind)):
			_place(selected_kind, placement_cell)
	elif event is InputEventScreenTouch and event.pressed:
		if placement_ghost and _can_place(placement_cell, BuildingFactory.footprint(selected_kind)):
			_place(selected_kind, placement_cell)

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0b090d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#666079")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color("#23202b")
	env.fog_density = 0.008
	environment.environment = env
	$World.add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-54, -32, 0)
	moon.light_color = Color("#9caad1")
	moon.light_energy = 1.25
	moon.shadow_enabled = true
	$World.add_child(moon)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(74, 74)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("#24232a")
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	$World.add_child(ground)
	grid_root = Node3D.new()
	grid_root.name = "Grid"
	$World.add_child(grid_root)
	buildings_root = Node3D.new()
	buildings_root.name = "Buildings"
	$World.add_child(buildings_root)
	obstacles_root = Node3D.new()
	obstacles_root.name = "Obstacles"
	$World.add_child(obstacles_root)
	villagers_root = Node3D.new()
	villagers_root.name = "Villagers"
	$World.add_child(villagers_root)

func _build_grid() -> void:
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.25, 0.23, 0.29, 0.42)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(GRID_SIZE + 1):
		var offset := -BUILDABLE_HALF + i * TILE_SIZE
		_add_grid_line(Vector3(0, 0.012, offset), Vector3(GRID_SIZE * TILE_SIZE, 0.018, 0.035), line_mat)
		_add_grid_line(Vector3(offset, 0.012, 0), Vector3(0.035, 0.018, GRID_SIZE * TILE_SIZE), line_mat)

func _add_grid_line(pos: Vector3, size: Vector3, mat: Material) -> void:
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	line.mesh = mesh
	line.position = pos
	line.material_override = mat
	grid_root.add_child(line)

func _build_interface() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	$Interface.add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var title := Label.new()
	title.text = "ASHFALL  •  GODOT 3D"
	title.add_theme_font_size_override("font_size", 24)
	layout.add_child(title)
	status_label = Label.new()
	status_label.text = "Village 3D — clic gauche pour construire, clic droit pour déplacer la caméra"
	layout.add_child(status_label)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	layout.add_child(spacer)
	var buttons := HBoxContainer.new()
	layout.add_child(buttons)
	for data in [
		["HDV 3×3", "town_hall"],
		["Mine 2×2", "gold_mine"],
		["Caserne 2×2", "barracks"],
		["Forge 2×2", "forge"],
		["Tour 2×2", "tower"],
		["Mur 1×1", "wall"]
	]:
		var button := Button.new()
		button.text = data[0]
		button.pressed.connect(_select_building.bind(data[1]))
		buttons.add_child(button)
	selection_label = Label.new()
	selection_label.text = ""
	layout.add_child(selection_label)

func _spawn_initial_village() -> void:
	_place("town_hall", Vector2i(10, 10), false)
	_place("gold_mine", Vector2i(5, 9), false)
	_place("barracks", Vector2i(16, 11), false)
	for cell in [Vector2i(3, 4), Vector2i(20, 5), Vector2i(5, 19), Vector2i(18, 18)]:
		_spawn_obstacle(cell)

func _spawn_villagers() -> void:
	for i in range(5):
		var villager := AshfallVillager.new()
		villager.position = Vector3(-5.0 + i * 2.2, 0.0, 6.0 + (i % 2) * 1.8)
		villager.stride_phase = i * 1.1
		villagers_root.add_child(villager)

func _spawn_obstacle(cell: Vector2i) -> void:
	occupied[cell] = "obstacle"
	var root := Node3D.new()
	root.position = _cell_center(cell, Vector2i.ONE)
	obstacles_root.add_child(root)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(TILE_SIZE * 0.94, 0.12, TILE_SIZE * 0.94)
	base.mesh = base_mesh
	base.position.y = 0.06
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#302b31")
	base.material_override = mat
	root.add_child(base)
	for j in range(3):
		var rock := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.42 + j * 0.09
		mesh.height = mesh.radius * 1.45
		rock.mesh = mesh
		rock.position = Vector3((j - 1) * 0.42, 0.35 + j * 0.09, (j % 2) * 0.22)
		rock.scale = Vector3(1.0, 0.8, 0.85)
		rock.material_override = mat
		root.add_child(rock)

func _select_building(kind: String) -> void:
	selected_kind = kind
	_clear_ghost()
	placement_ghost = BuildingFactory.create(kind)
	_set_transparency(placement_ghost, 0.52)
	$World.add_child(placement_ghost)
	var fp := BuildingFactory.footprint(kind)
	selection_label.text = "Placement : %s — empreinte %d×%d" % [kind.replace("_", " ").capitalize(), fp.x, fp.y]

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

func _place(kind: String, cell: Vector2i, renew_ghost := true) -> void:
	var fp := BuildingFactory.footprint(kind)
	if not _can_place(cell, fp):
		return
	for y in range(fp.y):
		for x in range(fp.x):
			occupied[cell + Vector2i(x, y)] = kind
	var building := BuildingFactory.create(kind)
	building.position = _cell_center(cell, fp)
	buildings_root.add_child(building)
	if renew_ghost:
		_select_building(kind)

func _can_place(cell: Vector2i, fp: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x + fp.x > GRID_SIZE or cell.y + fp.y > GRID_SIZE:
		return false
	for y in range(fp.y):
		for x in range(fp.x):
			if occupied.has(cell + Vector2i(x, y)):
				return false
	return true

func _cell_center(cell: Vector2i, fp: Vector2i) -> Vector3:
	return Vector3(
		-BUILDABLE_HALF + (cell.x + fp.x * 0.5) * TILE_SIZE,
		0.0,
		-BUILDABLE_HALF + (cell.y + fp.y * 0.5) * TILE_SIZE
	)

func _world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(
		floori((world.x + BUILDABLE_HALF) / TILE_SIZE),
		floori((world.z + BUILDABLE_HALF) / TILE_SIZE)
	)

func _set_transparency(node: Node, alpha: float) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var source := child.material_override as StandardMaterial3D
			if source:
				var mat := source.duplicate() as StandardMaterial3D
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = alpha
				child.material_override = mat
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
