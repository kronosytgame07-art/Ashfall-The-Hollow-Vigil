class_name AshfallGameState
extends RefCounted

const SAVE_PATH := "user://ashfall_save.json"

var resources := {"gold": 1250, "wood": 1250, "souls": 120, "gems": 75}
var trophies := 0
var builders_total := 2
var buildings: Array[Dictionary] = []
var army := {"warrior": 4, "archer": 2, "brute": 0}
var last_update := 0

func can_afford(cost: Dictionary) -> bool:
	for resource in cost:
		if int(resources.get(resource, 0)) < int(cost[resource]):
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for resource in cost:
		resources[resource] = int(resources.get(resource, 0)) - int(cost[resource])
	return true

func add_resource(resource: String, amount: int) -> void:
	resources[resource] = int(resources.get(resource, 0)) + amount

func busy_builders(now: int) -> int:
	var count := 0
	for data in buildings:
		if int(data.get("finish_at", 0)) > now:
			count += 1
	return count

func free_builders(now: int) -> int:
	return maxi(0, builders_total - busy_builders(now))

func tick_production(now: int) -> void:
	if last_update <= 0:
		last_update = now
		return
	var elapsed := clampi(now - last_update, 0, 12 * 60 * 60)
	if elapsed <= 0:
		return
	for data in buildings:
		if int(data.get("finish_at", 0)) > now:
			continue
		var definition := BuildingFactory.definition(str(data.kind))
		var resource := str(definition.get("produces", ""))
		if resource.is_empty():
			continue
		var level := int(data.get("level", 1))
		var rate := float(definition.get("rate", 0)) * (1.0 + (level - 1) * 0.35)
		var capacity := float(definition.get("capacity", 0)) * (1.0 + (level - 1) * 0.5)
		data.stored = minf(capacity, float(data.get("stored", 0.0)) + rate * elapsed / 60.0)
	last_update = now

func save() -> void:
	var payload := {
		"version": 2,
		"resources": resources,
		"trophies": trophies,
		"builders_total": builders_total,
		"buildings": buildings,
		"army": army,
		"last_update": last_update
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))

func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	resources.merge(parsed.get("resources", {}), true)
	trophies = int(parsed.get("trophies", 0))
	builders_total = int(parsed.get("builders_total", 2))
	buildings.clear()
	var saved_buildings = parsed.get("buildings", [])
	if saved_buildings is Array:
		for raw_building in saved_buildings:
			var migrated := _migrate_building(raw_building)
			if not migrated.is_empty():
				buildings.append(migrated)
	army.merge(parsed.get("army", {}), true)
	last_update = int(parsed.get("last_update", Time.get_unix_time_from_system()))
	# An obsolete or corrupted browser save must create a fresh village instead
	# of crashing before the first rendered frame.
	return not buildings.is_empty()

func _migrate_building(raw_building: Variant) -> Dictionary:
	if not raw_building is Dictionary:
		return {}
	var data: Dictionary = raw_building
	var kind := str(data.get("kind", ""))
	if kind.is_empty() or BuildingFactory.definition(kind).is_empty():
		return {}
	var raw_cell = data.get("cell", [])
	var x := 0
	var y := 0
	if raw_cell is Array and raw_cell.size() >= 2:
		x = int(raw_cell[0])
		y = int(raw_cell[1])
	elif raw_cell is Dictionary and raw_cell.has("x") and raw_cell.has("y"):
		x = int(raw_cell.x)
		y = int(raw_cell.y)
	else:
		return {}
	var footprint := BuildingFactory.footprint(kind)
	x = clampi(x, 0, 24 - footprint.x)
	y = clampi(y, 0, 24 - footprint.y)
	return {
		"kind": kind,
		"cell": [x, y],
		"level": maxi(1, int(data.get("level", 1))),
		"finish_at": maxi(0, int(data.get("finish_at", 0))),
		"stored": maxf(0.0, float(data.get("stored", 0.0))),
	}
