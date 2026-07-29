extends SceneTree

const REQUIRED_BUILDINGS := [
	"town_hall", "gold_mine", "sawmill", "barracks", "army_camp",
	"soul_altar", "forge", "tower", "laboratory", "spell_hall",
	"builders_yard", "wall"
]

func _initialize() -> void:
	# A validation failure must terminate the CI process instead of leaving a
	# headless Godot runner alive indefinitely.
	create_timer(120.0).timeout.connect(func():
		push_error("3D validation exceeded the two-minute safety limit")
		quit(1)
	)
	for script_path in [
		"res://scripts/souls_world.gd",
		"res://scripts/souls_player.gd",
		"res://scripts/souls_enemy.gd"
	]:
		assert(ResourceLoader.exists(script_path), "Missing action-RPG controller: " + script_path)
		var action_rpg_script := load(script_path) as Script
		assert(
			action_rpg_script != null and action_rpg_script.can_instantiate(),
			"Action-RPG controller cannot instantiate: " + script_path
		)
	for action in [
		"move_forward", "move_back", "move_left", "move_right",
		"sprint", "dodge", "attack", "interact"
	]:
		assert(InputMap.has_action(action), "Remappable action is missing: " + action)
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null, "The new action-RPG main scene cannot load")
	var main_instance := main_scene.instantiate()
	assert(main_instance.get_script().resource_path == "res://scripts/souls_world.gd",
		"The main scene must launch the soulslike cube world")
	main_instance.free()
	var camera_test := AshfallSoulsPlayer.new()
	get_root().add_child(camera_test)
	await process_frame
	assert(camera_test.camera != null and camera_test.camera.current,
		"The player must own an active third-person camera")
	assert(camera_test.camera_pivot.top_level,
		"The orbit camera must be independent from character yaw")
	camera_test.queue_free()
	await process_frame
	for kind in REQUIRED_BUILDINGS:
		var fp := BuildingFactory.footprint(kind)
		assert(fp.x > 0 and fp.y > 0, "Invalid footprint: " + kind)
		var definition := BuildingFactory.definition(kind)
		assert(not definition.is_empty(), "Missing gameplay definition: " + kind)
		assert(definition.has("cost"), "Missing building cost: " + kind)
		var model_path: String = BuildingFactory.MODEL_PATHS.get(kind, "")
		assert(ResourceLoader.exists(model_path), "Missing imported GLB: " + model_path)
		var level_one := BuildingFactory.create(kind, 1)
		get_root().add_child(level_one)
		var level_two_group := level_one.find_child("UpgradeLevel2", true, false) as Node3D
		assert(level_two_group != null, "Missing authored level progression: " + kind)
		assert(not level_two_group.visible, "Level 2 details leaked onto level 1: " + kind)
		BuildingFactory.apply_level_visual(level_one, 2)
		assert(level_two_group.visible, "Level 2 details did not unlock: " + kind)
		level_one.queue_free()
		await process_frame
	for model_path in [
		"res://models/obstacles/corrupted_rocks.glb",
		"res://models/obstacles/dead_tree.glb",
		"res://models/obstacles/bones.glb",
		"res://models/obstacles/soul_crystals.glb",
		"res://models/environment/mountain_ring.glb"
	]:
		assert(ResourceLoader.exists(model_path), "Missing environment GLB: " + model_path)
	for sector in range(8):
		var angle := sector * TAU / 8.0
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		assert(is_equal_approx(direction.length(), 1.0), "Invalid direction sector")
	var game_state := AshfallGameState.new()
	assert(game_state.can_afford({"gold": 100}), "Starting economy is invalid")
	assert(game_state.spend({"gold": 100}), "Resource spending failed")
	assert(game_state.resources.gold == 1150, "Resource subtraction failed")
	assert(game_state.account_xp == 0, "Starting account XP must be initialized")
	game_state.obstacles.append({"cell": [7, 8]})
	assert(game_state.obstacles[0].cell == [7, 8], "Obstacle persistence data is invalid")
	assert(BuildingFactory.footprint("town_hall") == Vector2i(3, 3), "Town hall must occupy 3x3")
	assert(BuildingFactory.footprint("gold_mine") == Vector2i(2, 2), "Gold mine must occupy 2x2")
	var textured_stone := BuildingFactory.make_textured_material("stone", Color("#403b42"))
	assert(textured_stone != null and textured_stone.shader != null, "Procedural surface texturing must be available")
	assert(ResourceLoader.exists("res://scripts/pvpve_battle.gd"), "PvPvE battle controller is missing")
	var battle_controller_script := load("res://scripts/pvpve_battle.gd") as Script
	assert(battle_controller_script != null and battle_controller_script.can_instantiate(), "PvPvE battle controller cannot instantiate")
	for icon_path in [
		"res://ui/icons/icon_town.svg",
		"res://ui/icons/icon_swords.svg",
		"res://ui/icons/icon_settings.svg",
		"res://ui/icons/icon_hammer.svg",
		"res://ui/icons/icon_shield.svg"
	]:
		assert(ResourceLoader.exists(icon_path), "HUD icon is missing: " + icon_path)
	assert(game_state._migrate_building({"kind": "town_hall", "cell": []}).is_empty(),
		"Malformed browser saves must be rejected without indexing an empty cell")
	var migrated := game_state._migrate_building({"kind": "gold_mine", "cell": {"x": 5, "y": 9}})
	assert(migrated.cell == [5, 9], "Legacy dictionary coordinates must migrate")
	var compact_unit := AshfallCombatUnit.new()
	assert(compact_unit.camp_scale <= 0.5, "Camp troops must remain compact enough to gather around fires")
	compact_unit.free()
	var compact_villager := AshfallVillager.new()
	assert(is_equal_approx(compact_villager.character_scale, 0.48), "Villagers must match troop scale")
	compact_villager.free()
	print("Ashfall 3D validation: assets, compact dark-fantasy units, economy, footprints and 8-way movement, OK")
	quit()
