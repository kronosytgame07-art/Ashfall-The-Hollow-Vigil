class_name AshfallPVPVEBattle
extends Node3D

signal exit_requested

const TEAM_PLAYER := 0
const TEAM_RIVAL := 1
const STARTING_UNITS := 12
const FORT_MAX_HEALTH := 1800.0

var units: Array[Dictionary] = []
var fort_health := FORT_MAX_HEALTH
var fort_root: Node3D
var battle_over := false
var fort_attack_clock := 1.0
var player_power_used := false
var status_label: Label
var player_label: Label
var rival_label: Label
var fort_bar: ProgressBar
var power_button: Button

func _ready() -> void:
	_build_fort()
	_spawn_army(TEAM_PLAYER, Vector3(-19.0, 0.0, 12.0))
	_spawn_army(TEAM_RIVAL, Vector3(19.0, 0.0, -12.0))
	_build_battle_hud()
	_update_hud("Les deux armées convergent vers le bastion cendré.")

func _process(delta: float) -> void:
	if battle_over:
		return
	fort_attack_clock -= delta
	for data in units:
		if not bool(data.alive) or not is_instance_valid(data.node):
			continue
		data.cooldown = maxf(0.0, float(data.cooldown) - delta)
		var enemy := _nearest_enemy(data)
		if not enemy.is_empty() and data.node.global_position.distance_to(enemy.node.global_position) < 2.25:
			_attack_unit(data, enemy)
		elif fort_health > 0.0:
			var approach := _fort_approach_position(int(data.team), int(data.slot))
			if data.node.global_position.distance_to(approach) > 1.7:
				data.node.move_to(approach)
			else:
				_attack_fort(data)
		elif not enemy.is_empty():
			data.node.move_to(enemy.node.global_position)
	if fort_health > 0.0 and fort_attack_clock <= 0.0:
		fort_attack_clock = 1.25
		_fort_counterattack()
	_remove_defeated_units()
	_check_victory()
	_refresh_bars()

func _build_fort() -> void:
	fort_root = Node3D.new()
	fort_root.name = "PVEAshFort"
	add_child(fort_root)
	var hall := BuildingFactory.create("town_hall", 4)
	hall.scale *= 0.92
	fort_root.add_child(hall)
	for wall_index in range(12):
		var angle := TAU * wall_index / 12.0
		var wall := BuildingFactory.create("wall", 4)
		wall.position = Vector3(cos(angle) * 6.0, 0.0, sin(angle) * 6.0)
		wall.rotation.y = -angle
		fort_root.add_child(wall)
	for tower_index in range(4):
		var angle := TAU * tower_index / 4.0 + PI * 0.25
		var tower := BuildingFactory.create("tower", 2)
		tower.position = Vector3(cos(angle) * 5.2, 0.0, sin(angle) * 5.2)
		tower.scale *= 0.62
		fort_root.add_child(tower)

func _spawn_army(team: int, origin: Vector3) -> void:
	for slot in range(STARTING_UNITS):
		var unit := AshfallCombatUnit.new()
		unit.kind = AshfallCombatUnit.UnitKind.WARRIOR if slot % 4 else AshfallCombatUnit.UnitKind.ARCHER
		unit.position = origin + Vector3((slot % 4) * 0.9, 0.0, (slot / 4) * 0.9)
		add_child(unit)
		_add_team_marker(unit, team)
		units.append({
			"node": unit,
			"team": team,
			"slot": slot,
			"health": 105.0 if unit.kind == AshfallCombatUnit.UnitKind.WARRIOR else 78.0,
			"damage": 18.0 if unit.kind == AshfallCombatUnit.UnitKind.WARRIOR else 14.0,
			"cooldown": randf_range(0.0, 0.8),
			"alive": true
		})
		unit.move_to(_fort_approach_position(team, slot))

func _add_team_marker(unit: Node3D, team: int) -> void:
	var marker := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.55
	ring.bottom_radius = 0.55
	ring.height = 0.025
	ring.radial_segments = 24
	marker.mesh = ring
	marker.position.y = 0.025
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.45, 1.0, 0.72) if team == TEAM_PLAYER else Color(0.95, 0.16, 0.12, 0.72)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 1.25
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = material
	unit.add_child(marker)

func _fort_approach_position(team: int, slot: int) -> Vector3:
	var base_angle := 2.45 if team == TEAM_PLAYER else -0.7
	var angle := base_angle + (float(slot % 7) - 3.0) * 0.13
	var radius := 7.2 + float(slot % 3) * 0.42
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func _nearest_enemy(data: Dictionary) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for candidate in units:
		if not bool(candidate.alive) or int(candidate.team) == int(data.team):
			continue
		var distance: float = data.node.global_position.distance_squared_to(candidate.node.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest

func _attack_unit(attacker: Dictionary, victim: Dictionary) -> void:
	if float(attacker.cooldown) > 0.0:
		return
	attacker.cooldown = 0.82
	attacker.node.attack()
	victim.health = float(victim.health) - float(attacker.damage)
	if float(victim.health) <= 0.0:
		victim.alive = false

func _attack_fort(attacker: Dictionary) -> void:
	if float(attacker.cooldown) > 0.0:
		return
	attacker.cooldown = 0.92
	attacker.node.attack()
	fort_health = maxf(0.0, fort_health - float(attacker.damage))
	if fort_health <= 0.0 and fort_root.visible:
		fort_root.visible = false
		_update_hud("Le bastion est détruit — les deux armées se battent jusqu’au dernier survivant.")

func _fort_counterattack() -> void:
	var living: Array[Dictionary] = []
	for data in units:
		if bool(data.alive) and data.node.global_position.length() < 10.0:
			living.append(data)
	if living.is_empty():
		return
	var victim := living[randi_range(0, living.size() - 1)]
	victim.health = float(victim.health) - randf_range(9.0, 17.0)
	if float(victim.health) <= 0.0:
		victim.alive = false

func _remove_defeated_units() -> void:
	for data in units:
		if not bool(data.alive) and is_instance_valid(data.node):
			data.node.queue_free()

func _living_count(team: int) -> int:
	var count := 0
	for data in units:
		if bool(data.alive) and int(data.team) == team:
			count += 1
	return count

func _check_victory() -> void:
	var player_alive := _living_count(TEAM_PLAYER)
	var rival_alive := _living_count(TEAM_RIVAL)
	if player_alive > 0 and rival_alive > 0:
		return
	battle_over = true
	if player_alive > rival_alive:
		_update_hud("VICTOIRE — ton armée est la dernière survivante.")
	elif rival_alive > player_alive:
		_update_hud("DÉFAITE — l’armée rivale contrôle les ruines.")
	else:
		_update_hud("ÉGALITÉ — aucune armée n’a survécu aux cendres.")
	power_button.disabled = true

func _build_battle_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BattleInterface"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var header := PanelContainer.new()
	header.position = Vector2(24, 18)
	header.size = Vector2(680, 112)
	root.add_child(header)
	var header_box := VBoxContainer.new()
	header.add_child(header_box)
	var title := Label.new()
	title.text = "COMBAT PVPVE  •  LE BASTION CENDRÉ"
	title.add_theme_font_size_override("font_size", 20)
	header_box.add_child(title)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("#e2bc82"))
	header_box.add_child(status_label)
	fort_bar = ProgressBar.new()
	fort_bar.max_value = FORT_MAX_HEALTH
	fort_bar.value = fort_health
	fort_bar.show_percentage = false
	header_box.add_child(fort_bar)
	var teams := HBoxContainer.new()
	header_box.add_child(teams)
	player_label = Label.new()
	player_label.add_theme_color_override("font_color", Color("#72a7ff"))
	teams.add_child(player_label)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 80
	teams.add_child(spacer)
	rival_label = Label.new()
	rival_label.add_theme_color_override("font_color", Color("#ff6a5e"))
	teams.add_child(rival_label)
	var actions := VBoxContainer.new()
	actions.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.position = Vector2(-310, -150)
	actions.size = Vector2(286, 126)
	root.add_child(actions)
	power_button = Button.new()
	power_button.text = "  CRI DE GUERRE  +25% dégâts"
	power_button.icon = load("res://assets/ui/icon_swords.svg")
	power_button.icon_max_width = 26
	power_button.pressed.connect(_use_player_power)
	actions.add_child(power_button)
	var exit_button := Button.new()
	exit_button.text = "  RETOUR AU MENU"
	exit_button.icon = load("res://assets/ui/icon_town.svg")
	exit_button.icon_max_width = 24
	exit_button.pressed.connect(func(): exit_requested.emit())
	actions.add_child(exit_button)
	_refresh_bars()

func _use_player_power() -> void:
	if player_power_used or battle_over:
		return
	player_power_used = true
	for data in units:
		if int(data.team) == TEAM_PLAYER and bool(data.alive):
			data.damage = float(data.damage) * 1.25
	power_button.disabled = true
	power_button.text = "CRI DE GUERRE UTILISÉ"
	_update_hud("Tes guerriers infligent 25 % de dégâts supplémentaires.")

func _refresh_bars() -> void:
	if fort_bar:
		fort_bar.value = fort_health
	if player_label:
		player_label.text = "VIGIE  %d survivants" % _living_count(TEAM_PLAYER)
	if rival_label:
		rival_label.text = "RIVAL  %d survivants" % _living_count(TEAM_RIVAL)

func _update_hud(message: String) -> void:
	if status_label:
		status_label.text = message
