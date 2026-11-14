extends Node2D

# DARK RADAR - Prototype 0.3
# Single-player vertical slice: human villain vs four AI rescuers, competing
# over five neutral villagers. All visuals are drawn in code to keep the build light.

const WORLD_SIZE := Vector2(1800.0, 1200.0)
const VIEW_SIZE := Vector2(960.0, 600.0)
const VILLAIN_BASE := Vector2(100.0, 105.0)
const RESCUE_BASE := Vector2(1700.0, 1100.0)
const VISIBILITY_RADIUS := 132.0 # Prototype-scale equivalent of the GDD's ~5 m.
const PLAYER_WALK_SPEED := 158.0
const PLAYER_CARRY_SPEED := 112.0
const RESCUER_SPEED := 54.0
const RESCUER_CARRY_SPEED := 54.0
const VILLAGER_SPEED := 27.0
const ATTACK_RANGE := 47.0
const PICKUP_RANGE := 31.0
const MATCH_CYCLE_SECONDS := 140.0

# Villain power-ups: three active map pickups, each respawning after a cooldown.
const VILLAIN_POWERUP_SLOT_COUNT := 3
const POWERUP_PICKUP_RANGE := 30.0
const POWERUP_RESPAWN_MIN := 28.0
const POWERUP_RESPAWN_MAX := 42.0
const RADAR_DURATION := 4.0
const RADAR_RADIUS := 390.0
const ADRENALINE_DURATION := 6.0
const ADRENALINE_SPEED_MULTIPLIER := 1.28
const DECOY_DURATION := 8.0
const DECOY_ATTRACTION_RADIUS := 420.0

# Rare rescuer counter-power: one possible HUNTER MODE event per match.
const HUNTER_MODE_DURATION := 20.0
const HUNTER_MODE_SPAWN_CHANCE := 0.12
const HUNTER_MODE_FIRST_CHECK := 58.0
const HUNTER_MODE_CHECK_MIN := 42.0
const HUNTER_MODE_CHECK_MAX := 62.0
const HUNTER_PICKUP_LIFETIME := 42.0
const HUNTER_RESCUER_SPEED := 174.0
const HUNTER_KILL_RANGE := 25.0
const PLAYER_HUNTER_ESCAPE_SPEED := 168.0

var player_pos := Vector2(145.0, 195.0)
var camera_offset := Vector2.ZERO
var player_carrying := -1
var attack_cooldown := 0.0
var game_time := 0.0
var rescued_count := 0
var kidnapped_count := 0
var game_over := false
var winner_text := ""
var message_text := "Find the five innocents. Deliver them to your base."
var message_timer := 5.0
var demo_view := false
var villagers: Array[Dictionary] = []
var rescuers: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

var player_powerup := ""
var radar_timer := 0.0
var adrenaline_timer := 0.0
var decoy_timer := 0.0
var decoy_pos := Vector2.ZERO
var powerup_slots: Array[Dictionary] = []

var hunter_pickup_active := false
var hunter_pickup_pos := Vector2.ZERO
var hunter_spawn_timer := HUNTER_MODE_FIRST_CHECK
var hunter_pickup_lifetime := 0.0
var hunter_powerup_used := false

var houses := [
	Rect2(330, 170, 120, 88),
	Rect2(650, 230, 138, 96),
	Rect2(1120, 160, 140, 100),
	Rect2(1470, 430, 135, 92),
	Rect2(260, 760, 124, 86),
	Rect2(720, 860, 140, 100),
	Rect2(1180, 880, 145, 105),
	Rect2(1520, 980, 110, 80),
]

var grass_areas := [
	Rect2(165, 325, 165, 92),
	Rect2(505, 105, 145, 92),
	Rect2(925, 255, 175, 105),
	Rect2(1350, 190, 185, 105),
	Rect2(1550, 600, 155, 105),
	Rect2(295, 925, 185, 105),
	Rect2(900, 1035, 205, 105),
	Rect2(1120, 625, 195, 105),
	Rect2(565, 565, 150, 100),
	Rect2(1450, 760, 175, 95),
]

var patrol_points := [
	Vector2(420, 360), Vector2(830, 345), Vector2(1390, 390),
	Vector2(610, 900), Vector2(1080, 700), Vector2(1510, 820),
	Vector2(950, 1040), Vector2(350, 650), Vector2(1470, 580)
]

var powerup_spawn_points := [
	Vector2(225, 455), Vector2(545, 335), Vector2(535, 685),
	Vector2(920, 185), Vector2(1035, 430), Vector2(1080, 735),
	Vector2(1390, 365), Vector2(1400, 700), Vector2(1710, 355),
	Vector2(1700, 790), Vector2(500, 1080), Vector2(1110, 1080),
	Vector2(250, 620), Vector2(950, 760), Vector2(1355, 640)
]

func _ready() -> void:
	rng.randomize()
	_reset_match()

func _reset_match() -> void:
	player_pos = VILLAIN_BASE + Vector2(45, 90)
	camera_offset = Vector2.ZERO
	player_carrying = -1
	attack_cooldown = 0.0
	game_time = 0.0
	rescued_count = 0
	kidnapped_count = 0
	game_over = false
	winner_text = ""
	message_text = "Find the five innocents. Deliver them to your base."
	message_timer = 5.0
	player_powerup = ""
	radar_timer = 0.0
	adrenaline_timer = 0.0
	decoy_timer = 0.0
	decoy_pos = Vector2.ZERO
	powerup_slots.clear()
	hunter_pickup_active = false
	hunter_pickup_pos = Vector2.ZERO
	hunter_spawn_timer = HUNTER_MODE_FIRST_CHECK + rng.randf_range(0.0, 18.0)
	hunter_pickup_lifetime = 0.0
	hunter_powerup_used = false
	villagers.clear()
	rescuers.clear()
	_initialize_villain_powerups()

	# Every innocent starts outdoors. Keep these points clear of all house footprints.
	var villager_spawns := [
		Vector2(285, 315), Vector2(850, 265), Vector2(1320, 310),
		Vector2(500, 965), Vector2(1420, 835)
	]
	for i in range(5):
		var start: Vector2 = _find_safe_outdoor_point(villager_spawns[i], 14.0)
		villagers.append({
			"pos": start,
			"target": _random_village_point(),
			"state": "free",
			"carrier": -1,
			"hide_timer": rng.randf_range(3.0, 8.0),
			"flee_timer": 0.0
		})

	var rescuer_spawns := [
		Vector2(390, 365), Vector2(870, 345),
		Vector2(1390, 390), Vector2(610, 900)
	]
	for i in range(4):
		rescuers.append({
			"pos": _find_safe_outdoor_point(rescuer_spawns[i], 14.0),
			"active": true,
			"state": "searching",
			"target": -1,
			"carrying": -1,
			"search_index": i,
			"patrol_target": patrol_points[i],
			"patrol_timer": 20.0,
			"evade_timer": 0.0,
			"hunter_timer": 0.0
		})
	queue_redraw()

func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer = maxf(0.0, message_timer - delta)
	if not game_over:
		game_time += delta
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
		_update_player(delta)
		_update_powerups(delta)
		_update_villagers(delta)
		_update_rescuers(delta)
		if not game_over:
			_check_player_delivery()
	_update_camera(delta)
	queue_redraw()

func _update_camera(delta: float) -> void:
	var desired_offset := VIEW_SIZE * 0.5 - player_pos
	desired_offset.x = clampf(desired_offset.x, VIEW_SIZE.x - WORLD_SIZE.x, 0.0)
	desired_offset.y = clampf(desired_offset.y, VIEW_SIZE.y - WORLD_SIZE.y, 0.0)
	camera_offset = camera_offset.lerp(desired_offset, 1.0 - exp(-delta * 7.0))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				if not game_over:
					_player_interact()
			KEY_SPACE:
				if not game_over:
					_player_attack()
			KEY_F:
				if not game_over:
					_player_collect_powerup()
			KEY_Q:
				if not game_over:
					_player_use_powerup()
			KEY_R:
				_reset_match()
			KEY_V:
				demo_view = not demo_view
				_show_message("Investor view: both bases " + ("revealed" if demo_view else "hidden from villain"))
			KEY_ESCAPE:
				get_tree().quit()

func _update_player(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		var speed := PLAYER_CARRY_SPEED if player_carrying >= 0 else PLAYER_WALK_SPEED
		if _hunter_mode_active() and player_carrying < 0:
			speed = maxf(speed, PLAYER_HUNTER_ESCAPE_SPEED)
		if adrenaline_timer > 0.0:
			speed *= ADRENALINE_SPEED_MULTIPLIER
		player_pos = _move_actor(player_pos, direction * speed * delta, 12.0, player_pos + direction * 40.0)
	if player_carrying >= 0:
		villagers[player_carrying]["pos"] = player_pos + Vector2(10, -18)

func _initialize_villain_powerups() -> void:
	powerup_slots.clear()
	for i in range(VILLAIN_POWERUP_SLOT_COUNT):
		powerup_slots.append({"active": false, "pos": Vector2.ZERO, "type": "", "respawn_timer": 0.0})
		_spawn_villain_powerup(i)

func _spawn_villain_powerup(slot_index: int) -> void:
	var chosen := Vector2.ZERO
	var found := false
	var available_points: Array[Vector2] = []
	for point in powerup_spawn_points:
		if _is_blocked(point, 15.0) or _is_in_grass(point):
			continue
		if point.distance_to(VILLAIN_BASE) < 105.0 or point.distance_to(RESCUE_BASE) < 105.0:
			continue
		var overlaps := false
		for slot in powerup_slots:
			if bool(slot["active"]) and point.distance_to(slot["pos"]) < 115.0:
				overlaps = true
				break
		if not overlaps:
			available_points.append(point)
	if not available_points.is_empty():
		var picked_index := rng.randi_range(0, available_points.size() - 1)
		chosen = available_points[picked_index]
		found = true
	if not found:
		chosen = _random_powerup_spawn_position()
	var types := ["radar", "adrenaline", "decoy"]
	var selected_type: String = types[rng.randi_range(0, types.size() - 1)]
	var slot_data: Dictionary = powerup_slots[slot_index]
	slot_data["active"] = true
	slot_data["pos"] = chosen
	slot_data["type"] = selected_type
	slot_data["respawn_timer"] = 0.0
	powerup_slots[slot_index] = slot_data

func _random_powerup_spawn_position() -> Vector2:
	for attempt in range(70):
		var point := _random_village_point()
		if _is_in_grass(point):
			continue
		if point.distance_to(VILLAIN_BASE) < 105.0 or point.distance_to(RESCUE_BASE) < 105.0:
			continue
		var overlaps := false
		for slot in powerup_slots:
			if bool(slot["active"]) and point.distance_to(slot["pos"]) < 100.0:
				overlaps = true
				break
		if not overlaps:
			return point
	return Vector2(900.0, 650.0)

func _update_powerups(delta: float) -> void:
	radar_timer = maxf(0.0, radar_timer - delta)
	adrenaline_timer = maxf(0.0, adrenaline_timer - delta)
	decoy_timer = maxf(0.0, decoy_timer - delta)
	for i in range(powerup_slots.size()):
		var slot: Dictionary = powerup_slots[i]
		if not bool(slot["active"]):
			slot["respawn_timer"] = maxf(0.0, float(slot["respawn_timer"]) - delta)
			if float(slot["respawn_timer"]) <= 0.0:
				powerup_slots[i] = slot
				_spawn_villain_powerup(i)
			else:
				powerup_slots[i] = slot
	if hunter_powerup_used:
		return
	if hunter_pickup_active:
		hunter_pickup_lifetime = maxf(0.0, hunter_pickup_lifetime - delta)
		if hunter_pickup_lifetime <= 0.0:
			hunter_pickup_active = false
			hunter_spawn_timer = rng.randf_range(HUNTER_MODE_CHECK_MIN, HUNTER_MODE_CHECK_MAX)
	else:
		hunter_spawn_timer = maxf(0.0, hunter_spawn_timer - delta)
		if hunter_spawn_timer <= 0.0:
			if rng.randf() <= HUNTER_MODE_SPAWN_CHANCE:
				hunter_pickup_pos = _random_powerup_spawn_position()
				hunter_pickup_active = true
				hunter_pickup_lifetime = HUNTER_PICKUP_LIFETIME
				_show_message("A rare rescuer cache has appeared somewhere in the village!")
			else:
				hunter_spawn_timer = rng.randf_range(HUNTER_MODE_CHECK_MIN, HUNTER_MODE_CHECK_MAX)

func _player_collect_powerup() -> void:
	if player_powerup != "":
		_show_message("You can carry only one unused power-up. Press Q to use it first.")
		return
	var nearest := -1
	var nearest_distance := POWERUP_PICKUP_RANGE + 1.0
	for i in range(powerup_slots.size()):
		var slot: Dictionary = powerup_slots[i]
		if not bool(slot["active"]):
			continue
		var distance: float = player_pos.distance_to(slot["pos"])
		if distance < nearest_distance:
			nearest = i
			nearest_distance = distance
	if nearest < 0:
		_show_message("No power-up close enough. Search the village for a glowing pickup.")
		return
	var slot: Dictionary = powerup_slots[nearest]
	player_powerup = str(slot["type"])
	slot["active"] = false
	slot["respawn_timer"] = rng.randf_range(POWERUP_RESPAWN_MIN, POWERUP_RESPAWN_MAX)
	powerup_slots[nearest] = slot
	_show_message(_powerup_display_name(player_powerup) + " collected. Press Q to activate it.")

func _player_use_powerup() -> void:
	if player_powerup == "":
		_show_message("No power-up in inventory. Press F near a glowing pickup.")
		return
	match player_powerup:
		"radar":
			radar_timer = RADAR_DURATION
			_show_message("RADAR PULSE active. Nearby rescuers and innocents are revealed!")
		"adrenaline":
			adrenaline_timer = ADRENALINE_DURATION
			_show_message("ADRENALINE active. Movement speed increased for 6 seconds!")
		"decoy":
			decoy_pos = player_pos
			decoy_timer = DECOY_DURATION
			_show_message("DECOY deployed. Nearby unladen rescuers will investigate the sound!")
	player_powerup = ""

func _powerup_display_name(powerup_type: String) -> String:
	match powerup_type:
		"radar":
			return "RADAR PULSE"
		"adrenaline":
			return "ADRENALINE"
		"decoy":
			return "DECOY"
	return "NONE"

func _closest_rescuer_for_hunter_pickup() -> int:
	var best_index := -1
	var best_distance := INF
	for i in range(rescuers.size()):
		var rescuer: Dictionary = rescuers[i]
		if not bool(rescuer["active"]) or int(rescuer["carrying"]) >= 0 or float(rescuer.get("hunter_timer", 0.0)) > 0.0:
			continue
		var rescuer_pos: Vector2 = rescuer["pos"]
		var distance: float = rescuer_pos.distance_to(hunter_pickup_pos)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

func _hunter_mode_active() -> bool:
	for rescuer in rescuers:
		if bool(rescuer["active"]) and float(rescuer.get("hunter_timer", 0.0)) > 0.0:
			return true
	return false

func _hunter_mode_remaining() -> float:
	var remaining := 0.0
	for rescuer in rescuers:
		if bool(rescuer["active"]):
			remaining = maxf(remaining, float(rescuer.get("hunter_timer", 0.0)))
	return remaining

func _villain_caught() -> void:
	if game_over:
		return
	game_over = true
	winner_text = "RESCUERS WIN"
	message_text = "The empowered rescuer caught the villain."
	message_timer = 999.0
	_show_message("The empowered rescuer caught the villain. Rescuers win!")

func _update_villagers(delta: float) -> void:
	for i in range(villagers.size()):
		var villager: Dictionary = villagers[i]
		if villager["state"] != "free":
			continue
		var pos: Vector2 = villager["pos"]
		# Safety correction: an innocent can never remain inside a house, even if
		# an older save or a bad spawn point placed them there.
		if _is_blocked(pos, 8.0):
			pos = _find_safe_outdoor_point(pos, 12.0)
			villager["pos"] = pos
		villager["hide_timer"] = float(villager["hide_timer"]) - delta
		villager["flee_timer"] = maxf(0.0, float(villager["flee_timer"]) - delta)
		var target: Vector2 = villager["target"]
		if _is_blocked(target, 8.0):
			target = _random_village_point()
			villager["target"] = target
		if pos.distance_to(target) < 9.0 or float(villager["hide_timer"]) <= 0.0:
			target = _random_village_point()
			villager["target"] = target
			villager["hide_timer"] = rng.randf_range(4.0, 9.0)
		var speed := VILLAGER_SPEED
		if float(villager["flee_timer"]) > 0.0:
			speed *= 1.55
		var step := minf(speed * delta, pos.distance_to(target))
		if step > 0.0:
			var next_pos := _move_actor(pos, pos.direction_to(target) * step, 8.0, target)
			if not _is_blocked(next_pos, 8.0):
				villager["pos"] = next_pos
		villagers[i] = villager

func _update_rescuers(delta: float) -> void:
	var hunter_collector := _closest_rescuer_for_hunter_pickup() if hunter_pickup_active else -1
	for i in range(rescuers.size()):
		var rescuer: Dictionary = rescuers[i]
		if not bool(rescuer["active"]):
			continue
		var pos: Vector2 = rescuer["pos"]
		var carrying := int(rescuer["carrying"])
		var target_id := int(rescuer["target"])

		# A powered rescuer abandons all other objectives and hunts the villain.
		var hunter_time := float(rescuer.get("hunter_timer", 0.0))
		if hunter_time > 0.0:
			hunter_time = maxf(0.0, hunter_time - delta)
			rescuer["hunter_timer"] = hunter_time
			if hunter_time <= 0.0:
				rescuer["state"] = "searching"
				rescuer["target"] = -1
				rescuer["patrol_timer"] = 0.0
				rescuer["pos"] = pos
				rescuers[i] = rescuer
				_show_message("HUNTER MODE expired. The rescuer has returned to the search.")
				continue
			rescuer["state"] = "hunting"
			var hunt_direction := (player_pos - pos).normalized()
			var hunt_step := minf(HUNTER_RESCUER_SPEED * delta, pos.distance_to(player_pos))
			if hunt_step > 0.0:
				pos = _move_actor(pos, hunt_direction * hunt_step, 13.0, player_pos)
			rescuer["pos"] = pos
			rescuers[i] = rescuer
			if pos.distance_to(player_pos) <= HUNTER_KILL_RANGE:
				_villain_caught()
				return
			continue

		# Carriers prioritise the rescue base. The rare power-up is not offered
		# to a rescuer while they are already transporting an innocent.
		if carrying >= 0:
			rescuer["state"] = "returning"
			var destination: Vector2 = RESCUE_BASE
			if pos.distance_to(player_pos) < 92.0:
				destination = pos + pos.direction_to(player_pos) * -115.0
			var step := minf(RESCUER_CARRY_SPEED * delta, pos.distance_to(destination))
			if step > 0.0:
				pos = _move_actor(pos, pos.direction_to(destination) * step, 10.0, destination)
			rescuer["pos"] = pos
			villagers[carrying]["pos"] = pos + Vector2(-8, -16)
			if pos.distance_to(RESCUE_BASE) < 28.0:
				rescuer["pos"] = pos
				rescuers[i] = rescuer
				_complete_rescue(i)
				continue
			rescuers[i] = rescuer
			continue

		# Rescuers evade the villain unless they are in HUNTER MODE.
		if pos.distance_to(player_pos) < 105.0:
			rescuer["evade_timer"] = 1.6
		else:
			rescuer["evade_timer"] = maxf(0.0, float(rescuer["evade_timer"]) - delta)
		if float(rescuer["evade_timer"]) > 0.0:
			rescuer["state"] = "evading"
			var flee_direction := (pos - player_pos).normalized()
			if flee_direction == Vector2.ZERO:
				flee_direction = Vector2.UP
			pos = _move_actor(pos, flee_direction * RESCUER_SPEED * 1.35 * delta, 10.0, pos + flee_direction * 100.0)
			rescuer["pos"] = pos
			rescuers[i] = rescuer
			continue

		# The nearest available rescuer investigates the extremely rare hunter cache.
		if hunter_pickup_active and i == hunter_collector:
			rescuer["state"] = "seeking_hunter_powerup"
			var cache_distance: float = pos.distance_to(hunter_pickup_pos)
			if cache_distance <= 22.0:
				hunter_pickup_active = false
				hunter_pickup_lifetime = 0.0
				hunter_powerup_used = true
				rescuer["hunter_timer"] = HUNTER_MODE_DURATION
				rescuer["state"] = "hunting"
				rescuer["target"] = -1
				rescuer["evade_timer"] = 0.0
				_show_message("WARNING! A RESCUER ACTIVATED HUNTER MODE. SURVIVE 20 SECONDS!")
			else:
				var cache_step := minf(RESCUER_SPEED * 1.05 * delta, cache_distance)
				if cache_step > 0.0:
					pos = _move_actor(pos, pos.direction_to(hunter_pickup_pos) * cache_step, 10.0, hunter_pickup_pos)
				rescuer["pos"] = pos
			rescuers[i] = rescuer
			continue

		# The decoy temporarily draws unladen rescuers away from their current search.
		if decoy_timer > 0.0 and pos.distance_to(decoy_pos) <= DECOY_ATTRACTION_RADIUS:
			rescuer["state"] = "investigating_decoy"
			var decoy_distance: float = pos.distance_to(decoy_pos)
			if decoy_distance > 24.0:
				var decoy_step := minf(RESCUER_SPEED * 1.08 * delta, decoy_distance)
				if decoy_step > 0.0:
					pos = _move_actor(pos, pos.direction_to(decoy_pos) * decoy_step, 10.0, decoy_pos)
			rescuer["pos"] = pos
			rescuers[i] = rescuer
			continue

		rescuer["state"] = "searching"
		if target_id < 0 or target_id >= villagers.size() or villagers[target_id]["state"] != "free" or not _rescuer_can_see(pos, villagers[target_id]["pos"]):
			target_id = _choose_villager_target(i, pos)
			rescuer["target"] = target_id

		if target_id >= 0:
			rescuer["state"] = "pursuing"
			var target_pos: Vector2 = villagers[target_id]["pos"]
			if pos.distance_to(target_pos) < 20.0:
				villagers[target_id]["state"] = "rescuer"
				villagers[target_id]["carrier"] = i
				rescuer["carrying"] = target_id
				rescuer["target"] = -1
				rescuer["state"] = "returning"
				_show_message("A rescuer found an innocent person!")
			else:
				var step := minf(RESCUER_SPEED * delta, pos.distance_to(target_pos))
				if step > 0.0:
					pos = _move_actor(pos, pos.direction_to(target_pos) * step, 10.0, target_pos)
		else:
			# Continue searching by visiting distributed outdoor patrol points.
			rescuer["state"] = "searching"
			rescuer["patrol_timer"] = float(rescuer["patrol_timer"]) - delta
			var patrol_target: Vector2 = rescuer["patrol_target"]
			if pos.distance_to(patrol_target) < 18.0 or float(rescuer["patrol_timer"]) <= 0.0:
				rescuer["pos"] = pos
				rescuers[i] = rescuer
				_advance_rescuer_search(i)
				rescuer = rescuers[i]
				patrol_target = rescuer["patrol_target"]
				rescuer["patrol_timer"] = 20.0
			var patrol_step := minf((RESCUER_SPEED * 0.82) * delta, pos.distance_to(patrol_target))
			if patrol_step > 0.0:
				pos = _move_actor(pos, pos.direction_to(patrol_target) * patrol_step, 10.0, patrol_target)
		rescuer["pos"] = pos
		rescuers[i] = rescuer

func _advance_rescuer_search(rescuer_index: int) -> void:
	var rescuer: Dictionary = rescuers[rescuer_index]
	var start_index: int = (int(rescuer.get("search_index", rescuer_index)) + 1) % patrol_points.size()
	var chosen_index: int = start_index
	var best_score: float = INF
	for offset in range(patrol_points.size()):
		var candidate_index := (start_index + offset) % patrol_points.size()
		var candidate: Vector2 = patrol_points[candidate_index]
		var separation_score: float = 0.0
		for other_index in range(rescuers.size()):
			if other_index == rescuer_index or not bool(rescuers[other_index]["active"]):
				continue
			var other_target: Vector2 = rescuers[other_index]["patrol_target"]
			if candidate.distance_to(other_target) < 170.0:
				separation_score += 1000.0
		separation_score += candidate.distance_to(rescuer["pos"]) * 0.001
		if separation_score < best_score:
			best_score = separation_score
			chosen_index = candidate_index
	rescuer["search_index"] = chosen_index
	rescuer["patrol_target"] = patrol_points[chosen_index]
	rescuer["patrol_timer"] = 20.0
	rescuer["target"] = -1
	rescuer["state"] = "searching"
	rescuers[rescuer_index] = rescuer

func _choose_villager_target(rescuer_index: int, from_pos: Vector2) -> int:
	var best_id := -1
	var best_distance := INF
	for i in range(villagers.size()):
		if villagers[i]["state"] != "free":
			continue
		if _is_reserved_by_other_rescuer(i, rescuer_index):
			continue
		var target_pos: Vector2 = villagers[i]["pos"]
		if not _rescuer_can_see(from_pos, target_pos):
			continue
		var distance: float = from_pos.distance_to(target_pos)
		if distance < best_distance:
			best_distance = distance
			best_id = i
	return best_id

func _is_reserved_by_other_rescuer(villager_id: int, rescuer_index: int) -> bool:
	for i in range(rescuers.size()):
		if i == rescuer_index:
			continue
		if bool(rescuers[i]["active"]) and int(rescuers[i]["target"]) == villager_id:
			return true
	return false

func _rescuer_can_see(from_pos: Vector2, target_pos: Vector2) -> bool:
	if _is_in_grass(target_pos) and from_pos.distance_to(target_pos) > 22.0:
		return false
	if _is_night() and from_pos.distance_to(target_pos) > VISIBILITY_RADIUS:
		return false
	return true

func _player_interact() -> void:
	if player_carrying >= 0:
		_drop_player_villager()
		return
	var best_id := -1
	var best_distance := PICKUP_RANGE + 1.0
	for i in range(villagers.size()):
		if villagers[i]["state"] != "free":
			continue
		var pos: Vector2 = villagers[i]["pos"]
		var distance := player_pos.distance_to(pos)
		if _is_in_grass(pos) and distance > 21.0:
			continue
		if _is_night() and distance > VISIBILITY_RADIUS:
			continue
		if distance < best_distance:
			best_distance = distance
			best_id = i
	if best_id >= 0:
		player_carrying = best_id
		villagers[best_id]["state"] = "player"
		villagers[best_id]["carrier"] = -1
		_show_message("Innocent secured. Return to your villain base.")
	else:
		_show_message("No innocent close enough to pick up.")

func _drop_player_villager() -> void:
	if player_carrying < 0:
		return
	var id := player_carrying
	villagers[id]["state"] = "free"
	villagers[id]["carrier"] = -1
	villagers[id]["pos"] = player_pos + Vector2(rng.randf_range(-24, 24), rng.randf_range(-24, 24))
	villagers[id]["target"] = _flee_destination(villagers[id]["pos"], player_pos)
	villagers[id]["flee_timer"] = 4.0
	villagers[id]["hide_timer"] = 4.0
	player_carrying = -1
	_show_message("You dropped the innocent. They are fleeing!")

func _player_attack() -> void:
	if _hunter_mode_active():
		_show_message("HUNTER MODE ACTIVE! Run and survive; your attacks cannot stop the powered rescuer.")
		return
	if player_carrying >= 0:
		_show_message("You cannot attack while carrying an innocent person.")
		return
	if attack_cooldown > 0.0:
		return
	var nearest := -1
	var nearest_distance := ATTACK_RANGE + 1.0
	for i in range(rescuers.size()):
		if not bool(rescuers[i]["active"]):
			continue
		var distance: float = player_pos.distance_to(rescuers[i]["pos"])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = i
	attack_cooldown = 0.85
	if nearest < 0:
		_show_message("No rescuer within attack range.")
		return
	var rescuer: Dictionary = rescuers[nearest]
	var carried := int(rescuer["carrying"])
	if carried >= 0:
		villagers[carried]["state"] = "free"
		villagers[carried]["carrier"] = -1
		villagers[carried]["pos"] = rescuer["pos"] + Vector2(16, 12)
		villagers[carried]["target"] = _flee_destination(villagers[carried]["pos"], rescuer["pos"])
		villagers[carried]["flee_timer"] = 4.0
		villagers[carried]["hide_timer"] = 4.0
	rescuer["active"] = false
	rescuer["carrying"] = -1
	rescuer["target"] = -1
	rescuers[nearest] = rescuer
	_show_message("Rescuer eliminated. " + str(_active_rescuer_count()) + " remain.")

func _check_player_delivery() -> void:
	if player_carrying < 0:
		return
	if player_pos.distance_to(VILLAIN_BASE) < 34.0:
		var id := player_carrying
		villagers[id]["state"] = "kidnapped"
		villagers[id]["carrier"] = -1
		player_carrying = -1
		kidnapped_count += 1
		_show_message("Kidnapping secured! " + str(kidnapped_count) + "/5")
		_check_match_end()

func _complete_rescue(rescuer_index: int) -> void:
	var id := int(rescuers[rescuer_index]["carrying"])
	if id < 0 or villagers[id]["state"] == "rescued":
		return
	villagers[id]["state"] = "rescued"
	villagers[id]["carrier"] = -1
	rescuers[rescuer_index]["carrying"] = -1
	rescuers[rescuer_index]["target"] = -1
	rescuers[rescuer_index]["state"] = "searching"
	rescued_count += 1
	_advance_rescuer_search(rescuer_index)
	_show_message("Rescue completed! Rescuer is returning to search for another innocent.")
	_check_match_end()

func _check_match_end() -> void:
	if rescued_count + kidnapped_count < 5:
		return
	game_over = true
	if kidnapped_count > rescued_count:
		winner_text = "VILLAIN WINS"
	else:
		winner_text = "RESCUERS WIN"
	message_text = "All five innocents have been secured. Press R to play again."
	message_timer = 999.0

func _active_rescuer_count() -> int:
	var count := 0
	for rescuer in rescuers:
		if bool(rescuer["active"]):
			count += 1
	return count

func _random_village_point() -> Vector2:
	for attempt in range(60):
		var point := Vector2(rng.randf_range(95.0, WORLD_SIZE.x - 95.0), rng.randf_range(105.0, WORLD_SIZE.y - 65.0))
		if not _is_blocked(point, 14.0):
			return point
	return _find_safe_outdoor_point(Vector2(WORLD_SIZE.x * 0.5, WORLD_SIZE.y * 0.5), 14.0)

func _find_safe_outdoor_point(preferred: Vector2, radius: float) -> Vector2:
	if not _is_blocked(preferred, radius):
		return preferred
	# Search outward in rings so a villager or rescuer is moved out of a house
	# instead of being left stuck inside its collision footprint.
	for ring in range(1, 15):
		var distance: float = float(ring) * 18.0
		for sample in range(20):
			var angle: float = TAU * float(sample) / 20.0
			var candidate: Vector2 = preferred + Vector2.RIGHT.rotated(angle) * distance
			if candidate.x < 30.0 or candidate.y < 30.0 or candidate.x > WORLD_SIZE.x - 30.0 or candidate.y > WORLD_SIZE.y - 30.0:
				continue
			if not _is_blocked(candidate, radius):
				return candidate
	# This central field is an explicit safe fallback outside every house.
	return Vector2(900.0, 650.0)

func _flee_destination(from_pos: Vector2, threat_pos: Vector2) -> Vector2:
	var away := (from_pos - threat_pos).normalized()
	if away.length_squared() < 0.01:
		away = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
	for attempt in range(12):
		var direction := away.rotated(rng.randf_range(-0.8, 0.8))
		var destination := from_pos + direction * rng.randf_range(145.0, 215.0)
		destination.x = clampf(destination.x, 45.0, WORLD_SIZE.x - 45.0)
		destination.y = clampf(destination.y, 95.0, WORLD_SIZE.y - 40.0)
		if not _is_blocked(destination, 10.0):
			return destination
	return _random_village_point()

func _move_actor(pos: Vector2, motion: Vector2, radius: float, desired_target: Vector2) -> Vector2:
	if motion.length_squared() <= 0.0001:
		return pos
	var candidates := [
		pos + motion,
		pos + Vector2(motion.x, 0),
		pos + Vector2(0, motion.y),
		pos + Vector2(-motion.y, motion.x),
		pos + Vector2(motion.y, -motion.x)
	]
	var best_pos: Vector2 = pos
	var best_distance: float = pos.distance_to(desired_target)
	for candidate in candidates:
		if candidate == pos or _is_blocked(candidate, radius):
			continue
		var distance: float = candidate.distance_to(desired_target)
		if distance < best_distance:
			best_distance = distance
			best_pos = candidate
	return best_pos

func _is_blocked(pos: Vector2, radius: float) -> bool:
	if pos.x < radius or pos.y < radius or pos.x > WORLD_SIZE.x - radius or pos.y > WORLD_SIZE.y - radius:
		return true
	for house in houses:
		if house.grow(radius).has_point(pos):
			return true
	return false

func _is_in_grass(pos: Vector2) -> bool:
	for area in grass_areas:
		if area.has_point(pos):
			return true
	return false

func _is_night() -> bool:
	var phase := _phase_name()
	return phase == "NIGHT" or phase == "SUNSET"

func _phase_name() -> String:
	var t := fposmod(game_time, MATCH_CYCLE_SECONDS)
	if t < 55.0:
		return "NIGHT"
	if t < 65.0:
		return "SUNRISE"
	if t < 125.0:
		return "DAYLIGHT"
	return "SUNSET"

func _show_message(text: String) -> void:
	message_text = text
	message_timer = 3.0

func _draw() -> void:
	draw_set_transform(camera_offset)
	_draw_world()
	_draw_bases()
	_draw_pickups()
	_draw_characters()
	draw_set_transform(Vector2.ZERO)
	_draw_hud()
	if game_over:
		_draw_game_over()

func _draw_world() -> void:
	var phase := _phase_name()
	var night := _is_night()
	var ground := Color("24352c") if night else Color("52744c")
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), ground)

	# Main dirt roads connect the village districts.
	var road := Color("36372f") if night else Color("a08b68")
	draw_rect(Rect2(0, 520, WORLD_SIZE.x, 74), road)
	draw_rect(Rect2(825, 0, 74, WORLD_SIZE.y), road)
	draw_rect(Rect2(0, 900, WORLD_SIZE.x, 58), road)
	draw_rect(Rect2(1320, 0, 62, WORLD_SIZE.y), road)
	draw_rect(Rect2(0, 555, WORLD_SIZE.x, 3), Color("6a604b"))
	draw_rect(Rect2(860, 0, 3, WORLD_SIZE.y), Color("6a604b"))
	draw_rect(Rect2(0, 927, WORLD_SIZE.x, 3), Color("6a604b"))
	draw_rect(Rect2(1350, 0, 3, WORLD_SIZE.y), Color("6a604b"))

	# Tall grass patches conceal free innocents.
	for area in grass_areas:
		draw_rect(area, Color("294b32") if night else Color("456c3b"))
		for j in range(8):
			var x: float = float(area.position.x) + 8.0 + float(j) * (float(area.size.x) - 16.0) / 8.0
			draw_line(Vector2(x, area.position.y + area.size.y - 3), Vector2(x - 4, area.position.y + area.size.y - 16), Color("6e8a4b"), 2.0)

	# Trees and vegetation landmarks.
	var tree_points := [
		Vector2(150, 170), Vector2(210, 205), Vector2(560, 420),
		Vector2(700, 430), Vector2(1040, 180), Vector2(1190, 420),
		Vector2(1570, 320), Vector2(1650, 720), Vector2(1080, 800),
		Vector2(220, 700), Vector2(430, 1080), Vector2(1000, 1110),
		Vector2(1420, 1030), Vector2(1680, 470)
	]
	for point in tree_points:
		draw_circle(point + Vector2(0, 5), 16.0, Color(0, 0, 0, 0.18))
		draw_circle(point, 14.0, Color("314a32"))
		draw_circle(point + Vector2(-4, -5), 8.0, Color("54764a"))

	# Fences and farm boundaries.
	for fence_x in [235.0, 590.0, 1050.0, 1540.0]:
		draw_line(Vector2(fence_x, 445), Vector2(fence_x + 90, 445), Color("96815d"), 4.0)
		draw_line(Vector2(fence_x, 458), Vector2(fence_x + 90, 458), Color("96815d"), 3.0)
		for post in range(4):
			var px: float = fence_x + float(post) * 30.0
			draw_line(Vector2(px, 438), Vector2(px, 465), Color("96815d"), 3.0)

	# Houses are solid obstacles.
	for i in range(houses.size()):
		var house: Rect2 = houses[i]
		draw_rect(Rect2(house.position + Vector2(5, 7), house.size), Color(0, 0, 0, 0.23))
		draw_rect(house, Color("665747") if night else Color("9b8062"))
		var roof := PackedVector2Array([
			house.position + Vector2(-8, 8),
			house.position + Vector2(house.size.x * 0.5, -22),
			house.position + Vector2(house.size.x + 8, 8)
		])
		draw_colored_polygon(roof, Color("493d38") if night else Color("674840"))
		draw_rect(Rect2(house.position.x + house.size.x * 0.43, house.position.y + house.size.y * 0.45, 22, house.size.y * 0.55), Color("302c27"))

	# Scarecrows mark the farming districts.
	for point in [Vector2(470, 410), Vector2(1010, 680), Vector2(1600, 190), Vector2(330, 1080)]:
		draw_line(point + Vector2(0, -18), point + Vector2(0, 18), Color("796647"), 4.0)
		draw_line(point + Vector2(-12, -8), point + Vector2(12, -8), Color("796647"), 4.0)
		draw_circle(point + Vector2(0, -17), 5.0, Color("b79a66"))

	if night:
		# Lightweight visibility-radius ring; detection uses the same radius.
		draw_circle(player_pos, VISIBILITY_RADIUS, Color(0.91, 0.83, 0.59, 0.055))
		draw_arc(player_pos, VISIBILITY_RADIUS, 0, TAU, 64, Color("d2c58e"), 1.5)

func _draw_bases() -> void:
	# Villain knows and sees their own base at all times.
	draw_rect(Rect2(VILLAIN_BASE - Vector2(22, 17), Vector2(44, 34)), Color("533c3b"))
	draw_rect(Rect2(VILLAIN_BASE - Vector2(17, 12), Vector2(34, 24)), Color("7d4a43"))
	draw_string(ThemeDB.fallback_font, VILLAIN_BASE + Vector2(-32, 35), "YOUR BASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("f0c2a9"))

	# The rescue base is concealed from the human villain in normal play.
	if demo_view:
		draw_rect(Rect2(RESCUE_BASE - Vector2(24, 18), Vector2(48, 36)), Color("315b69"))
		draw_rect(Rect2(RESCUE_BASE - Vector2(18, 12), Vector2(36, 24)), Color("4e8995"))
		draw_string(ThemeDB.fallback_font, RESCUE_BASE + Vector2(-39, 34), "RESCUE BASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("c4f0ef"))

func _draw_pickups() -> void:
	for slot in powerup_slots:
		if not bool(slot["active"]):
			continue
		var pos: Vector2 = slot["pos"]
		var powerup_type := str(slot["type"])
		var tint := Color("e1c65f")
		var letter := "R"
		match powerup_type:
			"adrenaline":
				tint = Color("ee8846")
				letter = "A"
			"decoy":
				tint = Color("ac8be6")
				letter = "D"
		draw_circle(pos, 15.0, Color(tint.r, tint.g, tint.b, 0.18))
		draw_arc(pos, 13.0, 0.0, TAU, 24, tint, 2.0)
		draw_circle(pos, 8.0, tint)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-3, 4), letter, HORIZONTAL_ALIGNMENT_LEFT, 8, 9, Color("24231d"))
	if hunter_pickup_active:
		draw_circle(hunter_pickup_pos, 22.0, Color(1.0, 0.18, 0.62, 0.18))
		draw_arc(hunter_pickup_pos, 19.0, 0.0, TAU, 32, Color("ff79ca"), 3.0)
		var star := PackedVector2Array()
		for point_index in range(10):
			var angle := -PI * 0.5 + TAU * float(point_index) / 10.0
			var radius := 12.0 if point_index % 2 == 0 else 5.5
			star.append(hunter_pickup_pos + Vector2.RIGHT.rotated(angle) * radius)
		draw_colored_polygon(star, Color("ffb5e0"))
		draw_string(ThemeDB.fallback_font, hunter_pickup_pos + Vector2(-15, -25), "RARE", HORIZONTAL_ALIGNMENT_LEFT, 34, 9, Color("ffd5eb"))
	if radar_timer > 0.0:
		var pulse_radius := RADAR_RADIUS * (1.0 - radar_timer / RADAR_DURATION * 0.25)
		draw_arc(player_pos, pulse_radius, 0.0, TAU, 64, Color(0.92, 0.82, 0.34, 0.75), 2.0)
	if decoy_timer > 0.0:
		draw_circle(decoy_pos, 13.0, Color(0.65, 0.50, 0.92, 0.22))
		draw_arc(decoy_pos, 17.0, 0.0, TAU, 24, Color("b59bea"), 2.0)

func _draw_characters() -> void:
	var night := _is_night()
	for i in range(villagers.size()):
		var villager: Dictionary = villagers[i]
		if villager["state"] in ["rescued", "kidnapped"]:
			continue
		var pos: Vector2 = villager["pos"]
		var visible := true
		var radar_revealed := radar_timer > 0.0 and pos.distance_to(player_pos) <= RADAR_RADIUS
		if _is_in_grass(pos) and pos.distance_to(player_pos) > 23.0 and not radar_revealed:
			visible = false
		if night and pos.distance_to(player_pos) > VISIBILITY_RADIUS and not radar_revealed:
			visible = false
		if villager["state"] == "player":
			visible = true
		if villager["state"] == "rescuer":
			visible = not night or pos.distance_to(player_pos) <= VISIBILITY_RADIUS
		if visible:
			draw_circle(pos + Vector2(0, 3), 8.0, Color(0, 0, 0, 0.22))
			draw_circle(pos, 7.0, Color("dfc58a"))
			draw_circle(pos + Vector2(-2, -2), 2.0, Color("fff0c7"))
			if radar_timer > 0.0 and pos.distance_to(player_pos) <= RADAR_RADIUS:
				draw_arc(pos, 13.0, 0.0, TAU, 20, Color("e9d46c"), 1.5)

	for i in range(rescuers.size()):
		var rescuer: Dictionary = rescuers[i]
		if not bool(rescuer["active"]):
			continue
		var pos: Vector2 = rescuer["pos"]
		var hunter_active := float(rescuer.get("hunter_timer", 0.0)) > 0.0
		var radar_revealed := radar_timer > 0.0 and pos.distance_to(player_pos) <= RADAR_RADIUS
		if night and pos.distance_to(player_pos) > VISIBILITY_RADIUS and not hunter_active and not radar_revealed:
			continue
		if hunter_active:
			# Larger, high-contrast silhouette makes the temporary threat unmistakable.
			draw_circle(pos, 23.0, Color(1.0, 0.12, 0.56, 0.22))
			draw_arc(pos, 22.0, 0.0, TAU, 32, Color("ff70c8"), 3.0)
			draw_circle(pos + Vector2(0, 5), 17.0, Color(0, 0, 0, 0.28))
			draw_circle(pos, 15.0, Color("f02e91"))
			draw_circle(pos + Vector2(-3, -5), 5.0, Color("ffe4f3"))
			draw_string(ThemeDB.fallback_font, pos + Vector2(-24, -25), "HUNTER", HORIZONTAL_ALIGNMENT_LEFT, 54, 9, Color("ffd4ec"))
		else:
			draw_circle(pos + Vector2(0, 4), 11.0, Color(0, 0, 0, 0.25))
			draw_circle(pos, 9.0, Color("65b8c5"))
			draw_circle(pos + Vector2(-2, -3), 3.0, Color("d9ffff"))
		if int(rescuer["carrying"]) >= 0:
			draw_circle(pos + Vector2(-8, -15), 5.0, Color("dfc58a"))

	draw_circle(player_pos + Vector2(0, 5), 13.0, Color(0, 0, 0, 0.28))
	draw_circle(player_pos, 12.0, Color("a83f38"))
	draw_circle(player_pos + Vector2(-3, -4), 4.0, Color("f0b19a"))
	if player_carrying >= 0:
		draw_circle(player_pos + Vector2(12, -18), 6.0, Color("dfc58a"))

func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, 960, 82), Color(0.025, 0.035, 0.03, 0.91))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(18, 23), "DARK RADAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f2e8d2"))
	draw_string(font, Vector2(18, 43), "PROTOTYPE 0.3  |  TACTICAL POWER-UPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("9fb19d"))
	draw_string(font, Vector2(390, 24), "PHASE  " + _phase_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d8d2b2"))
	draw_string(font, Vector2(390, 47), "TIME  " + _format_time(game_time), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d8d2b2"))
	draw_string(font, Vector2(600, 24), "RESCUED  " + str(rescued_count) + "/5", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8ed3d5"))
	draw_string(font, Vector2(600, 47), "KIDNAPPED  " + str(kidnapped_count) + "/5", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e49b88"))
	draw_string(font, Vector2(810, 24), "RESCUERS  " + str(_active_rescuer_count()) + "/4", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c9d5d1"))
	var carry_text := "CARRYING: INNOCENT" if player_carrying >= 0 else "CARRYING: NONE"
	draw_string(font, Vector2(810, 47), carry_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e5d5bb"))
	var powerup_text := "POWER-UP: " + _powerup_display_name(player_powerup) if player_powerup != "" else "POWER-UP: EMPTY (F TO COLLECT)"
	draw_string(font, Vector2(600, 68), powerup_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("e8ce83"))

	draw_rect(Rect2(0, 548, 960, 52), Color(0.025, 0.035, 0.03, 0.91))
	draw_string(font, Vector2(12, 568), "WASD MOVE   E PICK/DROP   F COLLECT POWER-UP   Q USE POWER-UP   SPACE ATTACK   R RESTART", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("d4d8c7"))
	var objective := "OBJECTIVE: SECURE 3 OF 5 — MATCH ENDS WHEN ALL FIVE ARE DELIVERED (OR VILLAIN IS CAUGHT)"
	draw_string(font, Vector2(12, 589), objective, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("aab9a5"))

	if _hunter_mode_active():
		draw_rect(Rect2(235, 88, 490, 32), Color(0.27, 0.015, 0.13, 0.94))
		draw_string(font, Vector2(249, 110), "DANGER: HUNTER MODE ACTIVE — SURVIVE " + str(ceili(_hunter_mode_remaining())) + " SECONDS!", HORIZONTAL_ALIGNMENT_LEFT, 462, 12, Color("ffd5eb"))
	elif message_timer > 0.0 and not game_over:
		draw_rect(Rect2(220, 91, 520, 30), Color(0.02, 0.03, 0.025, 0.82))
		draw_string(font, Vector2(232, 111), message_text, HORIZONTAL_ALIGNMENT_LEFT, 496, 12, Color("f0e8d2"))
	if hunter_pickup_active:
		draw_string(font, Vector2(745, 135), "RARE HUNTER CACHE ACTIVE", HORIZONTAL_ALIGNMENT_LEFT, 205, 10, Color("ff8bd0"))
	if demo_view:
		draw_string(font, Vector2(750, 151), "INVESTOR VIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9de0df"))

func _draw_game_over() -> void:
	draw_rect(Rect2(0, 0, 960, 600), Color(0.01, 0.015, 0.02, 0.78))
	draw_string(ThemeDB.fallback_font, Vector2(250, 260), winner_text, HORIZONTAL_ALIGNMENT_CENTER, 460, 34, Color("f2e8d2"))
	draw_string(ThemeDB.fallback_font, Vector2(250, 300), "RESCUED  " + str(rescued_count) + "     /     KIDNAPPED  " + str(kidnapped_count), HORIZONTAL_ALIGNMENT_CENTER, 460, 16, Color("d6d4c2"))
	draw_string(ThemeDB.fallback_font, Vector2(250, 340), "Press R to restart the match", HORIZONTAL_ALIGNMENT_CENTER, 460, 14, Color("a9c1b0"))

func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [int(total / 60), total % 60]
