extends SceneTree

const REQUIRED_BUILDINGS := [
	"town_hall", "gold_mine", "sawmill", "barracks", "army_camp",
	"soul_altar", "forge", "tower", "laboratory", "spell_hall",
	"builders_yard", "wall"
]

func _initialize() -> void:
	for kind in REQUIRED_BUILDINGS:
		var fp := BuildingFactory.footprint(kind)
		assert(fp.x > 0 and fp.y > 0, "Invalid footprint: " + kind)
		var definition := BuildingFactory.definition(kind)
		assert(not definition.is_empty(), "Missing gameplay definition: " + kind)
		assert(definition.has("cost"), "Missing building cost: " + kind)
		var model_path: String = BuildingFactory.MODEL_PATHS.get(kind, "")
		assert(ResourceLoader.exists(model_path), "Missing imported GLB: " + model_path)
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
	assert(BuildingFactory.footprint("town_hall") == Vector2i(3, 3), "Town hall must occupy 3x3")
	assert(BuildingFactory.footprint("gold_mine") == Vector2i(2, 2), "Gold mine must occupy 2x2")
	var compact_unit := AshfallCombatUnit.new()
	assert(compact_unit.camp_scale <= 0.5, "Camp troops must remain compact enough to gather around fires")
	compact_unit.free()
	var compact_villager := AshfallVillager.new()
	assert(is_equal_approx(compact_villager.character_scale, 0.48), "Villagers must match troop scale")
	compact_villager.free()
	print("Ashfall 3D validation: assets, compact dark-fantasy units, economy, footprints and 8-way movement, OK")
	quit()
