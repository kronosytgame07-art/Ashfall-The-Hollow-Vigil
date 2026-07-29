extends Node3D

const GRID_SIZE := 24
const TILE_SIZE := 2.0
const BUILDABLE_HALF := GRID_SIZE * TILE_SIZE * 0.5
const CAMP_UNIT_SPACING := 0.62

var state := AshfallGameState.new()
var occupied: Dictionary = {}
var building_nodes: Dictionary = {}
var selected_kind := ""
var selected_id := -1
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
var build_panel: PanelContainer
var detail_panel: PanelContainer
var autosave_clock := 0.0

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
	_add_village_paths()
	_add_village_atmosphere()
	_refresh_ui()

func _process(delta: float) -> void:
	var now := _now()
	state.tick_production(now)
	autosave_clock += delta
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
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(74, 74)
	ground.mesh = plane
	ground.material_override = _terrain_material()
	$World.add_child(ground)
	var mountain_scene := load("res://models/environment/mountain_ring.glb") as PackedScene
	if mountain_scene:
		var mountains := mountain_scene.instantiate()
		mountains.scale = Vector3(0.9, 0.72, 0.9)
		$World.add_child(mountains)
	grid_root = _new_root("Grid")
	buildings_root = _new_root("Buildings")
	obstacles_root = _new_root("Obstacles")
	villagers_root = _new_root("Villagers")
	troops_root = _new_root("Troops")

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
	gradient.colors = PackedColorArray([Color("#151419"), Color("#2d292e"), Color("#49382e")])
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	texture.color_ramp = gradient
	mat.albedo_texture = texture
	mat.uv1_scale = Vector3(5.0, 5.0, 5.0)
	return mat

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
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Interface.add_child(hud)
	var top := _panel()
	top.position = Vector2(14, 12)
	top.size = Vector2(570, 62)
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
	build_toggle.text = "⚒  CONSTRUIRE"
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
	action_button.pressed.connect(_selected_action)
	detail_box.add_child(action_button)
	var army_panel := _panel()
	army_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	army_panel.position = Vector2(-288, -116)
	army_panel.size = Vector2(274, 98)
	hud.add_child(army_panel)
	var army_box := VBoxContainer.new()
	army_panel.add_child(army_box)
	train_button = Button.new()
	train_button.text = "Entraîner un guerrier"
	train_button.pressed.connect(_train_warrior)
	army_box.add_child(train_button)
	raid_button = Button.new()
	raid_button.text = "Lancer une expédition"
	raid_button.pressed.connect(_launch_raid)
	army_box.add_child(raid_button)
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.position = Vector2(200, -54)
	status_label.size = Vector2(720, 38)
	status_label.add_theme_color_override("font_color", Color("#e8c58d"))
	hud.add_child(status_label)

func _create_new_village() -> void:
	_add_building_record("town_hall", Vector2i(10, 10), 1, 0)
	_add_building_record("gold_mine", Vector2i(5, 9), 1, 0)
	_add_building_record("sawmill", Vector2i(5, 13), 1, 0)
	_add_building_record("barracks", Vector2i(16, 11), 1, 0)
	_add_building_record("army_camp", Vector2i(15, 15), 1, 0)
	_add_building_record("builders_yard", Vector2i(9, 16), 1, 0)
	state.last_update = _now()
	for cell in [Vector2i(3, 4), Vector2i(20, 5), Vector2i(5, 19), Vector2i(18, 18)]:
		_spawn_obstacle(cell)
	state.save()

func _restore_village() -> void:
	for index in range(state.buildings.size()):
		var data := state.buildings[index]
		var cell_data: Array = data.get("cell", [0, 0])
		var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
		_mark_occupied(str(data.kind), cell)
		_spawn_building_node(index)
	for cell in [Vector2i(3, 4), Vector2i(20, 5), Vector2i(5, 19), Vector2i(18, 18)]:
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
	var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
	var fp := BuildingFactory.footprint(kind)
	var building := BuildingFactory.create(kind)
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
	else:
		var collider = hit.get("collider")
		selected_id = int(collider.get_meta("building_id", -1)) if collider else -1
	_refresh_ui()

func _selected_action() -> void:
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
	_assign_builder(building_nodes[selected_id].global_position)
	_set_status("%s passe au niveau %d." % [BuildingFactory.label(kind), data.level])

func _train_warrior() -> void:
	var cost := {"gold": 100, "wood": 45}
	if not state.spend(cost):
		_set_status("Pas assez de ressources pour entraîner un guerrier.")
		return
	state.army.warrior = int(state.army.warrior) + 1
	var unit := AshfallCombatUnit.new()
	unit.kind = AshfallCombatUnit.UnitKind.WARRIOR
	var slot := troops_root.get_child_count()
	var camp_center := _army_camp_center()
	unit.position = camp_center + Vector3(-2.8, 0, -2.4)
	troops_root.add_child(unit)
	unit.move_to(_camp_unit_position(slot, camp_center))
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
	var hub := Vector3.ZERO
	for index in building_nodes:
		if str(state.buildings[int(index)].kind) == "town_hall":
			hub = building_nodes[index].global_position
			break
	var path_root := _new_root("VillagePaths")
	var path_mat := _material(Color("#40342d"))
	for index in building_nodes:
		var destination: Vector3 = building_nodes[index].global_position
		if destination.distance_to(hub) < 1.0:
			continue
		var direction := destination - hub
		direction.y = 0.0
		var length := maxf(0.0, direction.length() - 3.0)
		if length < 1.0:
			continue
		var midpoint := hub + direction.normalized() * (length * 0.5 + 1.5)
		var strip := _add_box(path_root, midpoint + Vector3(0, 0.025, 0), Vector3(1.05, 0.045, length), path_mat)
		strip.rotation.y = atan2(direction.x, direction.z)
		for stone_index in range(floori(length / 1.25)):
			var t := (stone_index + 0.5) / maxf(1.0, length / 1.25)
			var stone_position := hub.lerp(destination, t)
			var side := sin(float(stone_index * 17 + index * 3)) * 0.34
			var right := Vector3(direction.z, 0, -direction.x).normalized()
			_add_box(path_root, stone_position + right * side + Vector3(0, 0.055, 0), Vector3(0.72, 0.075, 0.5), _material(Color("#574b43")))

func _add_village_atmosphere() -> void:
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
	for i in range(mini(int(state.army.warrior), 24)):
		var unit := AshfallCombatUnit.new()
		unit.kind = AshfallCombatUnit.UnitKind.WARRIOR if i % 3 else AshfallCombatUnit.UnitKind.ARCHER
		unit.position = _camp_unit_position(i, camp_center)
		unit.rotation.y = atan2(camp_center.x - unit.position.x, camp_center.z - unit.position.z)
		troops_root.add_child(unit)

func _army_camp_center() -> Vector3:
	for index in building_nodes:
		if str(state.buildings[int(index)].kind) == "army_camp":
			return building_nodes[index].global_position
	return Vector3(9.0, 0.0, 9.0)

func _camp_unit_position(slot: int, center: Vector3) -> Vector3:
	# Anneaux serrés autour du brasero : 8, puis 16 unités, sans ligne infinie.
	var ring := 0 if slot < 8 else 1 + (slot - 8) / 16
	var ring_slot := slot if ring == 0 else posmod(slot - 8, 16)
	var ring_count := 8 if ring == 0 else 16
	var organic_offset := sin(float(slot * 19 + 7)) * 0.15
	var angle := TAU * float(ring_slot) / float(ring_count) + ring * 0.16 + organic_offset
	var radius := 1.25 + ring * CAMP_UNIT_SPACING + cos(float(slot * 11)) * 0.16
	return center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func _assign_builder(target: Vector3) -> void:
	for villager in villagers_root.get_children():
		if villager is AshfallVillager and villager.state != AshfallVillager.State.WORK:
			villager.set_work_target(target + Vector3(2.4, 0, 1.0))
			return

func _spawn_obstacle(cell: Vector2i) -> void:
	occupied[cell] = "obstacle"
	var root := Node3D.new()
	root.position = _cell_center(cell, Vector2i.ONE)
	obstacles_root.add_child(root)
	_add_box(root, Vector3(0, 0.06, 0), Vector3(TILE_SIZE * 0.96, 0.12, TILE_SIZE * 0.96), _material(Color("#302b31")))
	var paths := ["corrupted_rocks", "dead_tree", "bones", "soul_crystals"]
	var scene := load("res://models/obstacles/%s.glb" % paths[posmod(cell.x + cell.y, paths.size())]) as PackedScene
	if scene:
		root.add_child(scene.instantiate())
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(TILE_SIZE * 0.92, 1.8, TILE_SIZE * 0.92)
	collision.shape = shape
	collision.position.y = 0.9
	body.add_child(collision)
	root.add_child(body)

func _update_building_visuals(now: int) -> void:
	for index in building_nodes:
		_update_one_building_visual(int(index), now)

func _update_one_building_visual(index: int, now: int) -> void:
	if not building_nodes.has(index):
		return
	var data := state.buildings[index]
	var node: Node3D = building_nodes[index]
	var constructing := int(data.finish_at) > now
	node.scale = Vector3.ONE * (0.82 if constructing else 1.0)
	if not constructing:
		for villager in villagers_root.get_children() if villagers_root else []:
			if villager is AshfallVillager and villager.state == AshfallVillager.State.RUN and villager.target.distance_to(node.global_position) < 4.0:
				villager.start_work()

func _refresh_ui() -> void:
	var now := _now()
	resource_label.text = "OR  %d     BOIS  %d     ÂMES  %d     GEMMES  %d     🏆 %d     BÂTISSEURS  %d/%d" % [
		state.resources.gold, state.resources.wood, state.resources.souls, state.resources.gems,
		state.trophies, state.free_builders(now), state.builders_total
	]
	train_button.text = "Entraîner guerrier (100 or / 45 bois)  •  Armée %d" % int(state.army.warrior)
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
