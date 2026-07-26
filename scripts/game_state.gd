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
	buildings.assign(parsed.get("buildings", []))
	army.merge(parsed.get("army", {}), true)
	last_update = int(parsed.get("last_update", Time.get_unix_time_from_system()))
	return true
