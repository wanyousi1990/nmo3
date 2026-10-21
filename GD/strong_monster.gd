extends CharacterBody2D

# ==============================================================================
# Strong Monster Logic
# 行為邏輯與 monster_01.gd 相同：巡邏 → 追逐 → 撞牆後撤 → H 事件觸發
# ==============================================================================

@export_group("H-Event Settings")
## 觸發 H 時從此列表隨機選一個姿勢（須與 OL_H_Visual 子節點名稱一致）
@export var h_pose_tags: Array[String] = ["H_Pose_02", "H_Pose_05"]

@export_group("Movement")
@export var speed: float = 60.0
@export var chase_speed: float = 90.0
@export var acceleration: float = 400.0
@export var gravity: float = 980.0

@export_group("Patrol")
## 相對巡邏中心往左最遠距離（像素）；約 32px = 1 格
@export var patrol_range_left: float = 300.0
## 相對巡邏中心往右最遠距離（像素）；約 32px = 1 格
@export var patrol_range_right: float = 300.0
## 巡邏轉向時隨機停頓秒數（每次從中抽一個）
@export var patrol_turn_pause_options: Array[float] = [1.0, 2.0, 3.0]

@export_group("Chase switch & Stuck Correction")
@export var chase_switch_time: float = 0.3
@export var patrol_switch_time: float = 1.0
@export var stuck_pause_time: float = 0.5
@export var stuck_back_distance: float = 30.0

@export_group("Limb Nodes")
@export var pelvis_node: Node2D
@export var arm_l_node: Node2D
@export var arm_r_node: Node2D
@export var thigh_l_node: Node2D
@export var thigh_r_node: Node2D

@export_group("Animation Settings")
@export var walk_anim_speed: float = 10.0
@export var walk_anim_amplitude: float = 0.3

@export_group("Detection Zones")
@export var chase_area: Area2D
@export var detection_area: Area2D

enum State { PATROL, PATROL_PAUSE, START_CHASE, CHASE, STUCK_BY_WALL, LOST_TARGET, HIDDEN, COOLDOWN }
var current_state = State.PATROL
var direction: int = 1
var target_player: CharacterBody2D = null
var anim_phase: float = 0.0
var reverse_cooldown: float = 0.0
var patrol_origin: Vector2 = Vector2.ZERO
var patrol_pause_timer: float = 0.0
var prev_state = State.PATROL
var is_handling_wall := false

@onready var visual_node = $Visaul
@onready var floor_detector: RayCast2D = $FloorDetector

func _ready():
	patrol_origin = global_position
	add_to_group("Monster")

	if floor_detector:
		floor_detector.enabled = true
		floor_detector.target_position = Vector2(0, 20)
		# 地板在 layer 4（與本體 collision_mask 一致）；mask 錯誤會永遠偵測不到→短距來回掉頭
		floor_detector.collision_mask = collision_mask
		floor_detector.hit_from_inside = true
		print("[AI] FloorDetector mask=", floor_detector.collision_mask)

	if chase_area:
		chase_area.body_entered.connect(_on_chase_entered)
		chase_area.body_exited.connect(_on_chase_exited)

	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)

func _physics_process(delta: float):
	if current_state != prev_state:
		print("[SM DEBUG] 狀態: ", prev_state, " -> ", current_state)
		prev_state = current_state

	if current_state == State.HIDDEN:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	match current_state:
		State.PATROL:
			_handle_patrol(delta)
			_check_all_overlaps()
		State.PATROL_PAUSE:
			_handle_patrol_pause(delta)
			_check_all_overlaps()
		State.START_CHASE:
			_handle_reaction_pause(delta)
			_check_all_overlaps()
		State.CHASE:
			_handle_chase(delta)
			_check_all_overlaps()
		State.STUCK_BY_WALL:
			_check_player_left_chase_area()
		State.LOST_TARGET:
			_handle_reaction_pause(delta)
		State.COOLDOWN:
			_handle_cooldown(delta)

	var was_on_floor = is_on_floor()
	move_and_slide()
	_update_procedural_animation(delta)

	if is_on_floor() and not was_on_floor:
		if current_state == State.PATROL or current_state == State.LOST_TARGET:
			patrol_origin = global_position

	if is_on_wall() and current_state == State.PATROL and reverse_cooldown <= 0.0:
		_begin_patrol_turn_pause()

	if reverse_cooldown > 0.0:
		reverse_cooldown -= delta

func _update_procedural_animation(delta: float):
	var is_moving = abs(velocity.x) > 5.0 and is_on_floor()

	if is_moving:
		anim_phase += delta * walk_anim_speed * (abs(velocity.x) / chase_speed)
	else:
		anim_phase = lerp(anim_phase, ceil(anim_phase / (PI * 2)) * PI * 2, delta * 10.0)

	var swing = sin(anim_phase) * walk_anim_amplitude

	if thigh_l_node: thigh_l_node.rotation = swing
	if thigh_r_node: thigh_r_node.rotation = -swing
	if arm_l_node: arm_l_node.rotation = -swing * 0.5
	if arm_r_node: arm_r_node.rotation = swing * 0.5
	if pelvis_node:
		pelvis_node.position.y = abs(swing) * -5.0

func _handle_patrol(_delta: float):
	_update_floor_detector_position()

	var out_of_bounds = false
	if direction > 0 and global_position.x > patrol_origin.x + patrol_range_right:
		out_of_bounds = true
	elif direction < 0 and global_position.x < patrol_origin.x - patrol_range_left:
		out_of_bounds = true

	var is_near_edge = false
	if floor_detector and is_on_floor():
		if not floor_detector.is_colliding():
			is_near_edge = true

	if (out_of_bounds or is_near_edge) and reverse_cooldown <= 0.0:
		_begin_patrol_turn_pause()
		return

	velocity.x = move_toward(velocity.x, direction * speed, acceleration * _delta)
	_update_sprite_direction()

## 巡邏轉向：先停頓，結束後再轉身繼續走
func _begin_patrol_turn_pause() -> void:
	velocity.x = 0
	if patrol_turn_pause_options.is_empty():
		patrol_pause_timer = 1.0
	else:
		patrol_pause_timer = patrol_turn_pause_options[randi() % patrol_turn_pause_options.size()]
	current_state = State.PATROL_PAUSE
	reverse_cooldown = 0.5
	print("[SM AI] 巡邏轉向前停頓: ", patrol_pause_timer, " 秒")

func _handle_patrol_pause(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, acceleration * _delta)
	patrol_pause_timer -= _delta
	if patrol_pause_timer <= 0.0:
		_reverse_direction()
		_update_sprite_direction()
		current_state = State.PATROL
		reverse_cooldown = 0.5
		print("[SM AI] 巡邏停頓結束，轉向繼續巡邏")

func _handle_chase(_delta: float):
	if not is_instance_valid(target_player):
		_switch_to_lost_target()
		return

	if is_on_wall() and not is_handling_wall:
		var wall_normal = get_wall_normal()
		if (direction > 0 and wall_normal.x < -0.7) or (direction < 0 and wall_normal.x > 0.7):
			is_handling_wall = true
			current_state = State.STUCK_BY_WALL
			_handle_wall_collision()
			return

	var is_player_in_h = target_player.get("is_in_h_mode") == true
	if is_player_in_h or current_state == State.COOLDOWN:
		velocity.x = move_toward(velocity.x, 0, acceleration * _delta)
		return

	var dist_x = target_player.global_position.x - global_position.x
	if abs(dist_x) > 15.0:
		direction = 1 if dist_x > 0 else -1
		velocity.x = move_toward(velocity.x, direction * chase_speed, acceleration * _delta)
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * _delta)

	_update_sprite_direction()

## 回主選單等場景切換後 get_tree() 可能為 null；安全等待，仍在樹上回傳 true
func _await_safe_timer(duration: float) -> bool:
	if not is_instance_valid(self):
		return false
	var tree := get_tree()
	if tree == null:
		return false
	await tree.create_timer(duration).timeout
	return is_instance_valid(self) and is_inside_tree()

func _handle_wall_collision():
	velocity.x = 0
	print("[SM AI] 追逐撞牆，開始後撤流程...")

	if not await _await_safe_timer(stuck_pause_time):
		is_handling_wall = false
		return

	var back_dir = -direction
	var start_x = global_position.x

	while current_state == State.STUCK_BY_WALL:
		var moved_dist = abs(global_position.x - start_x)
		if moved_dist >= stuck_back_distance:
			break
		if is_on_wall() and moved_dist > 5.0:
			break
		velocity.x = back_dir * (speed * 0.8)
		if not is_instance_valid(self) or not get_tree():
			is_handling_wall = false
			return
		await get_tree().process_frame

	velocity.x = 0
	if not await _await_safe_timer(0.2):
		is_handling_wall = false
		return

	if current_state == State.STUCK_BY_WALL:
		current_state = State.CHASE

	is_handling_wall = false

func _handle_reaction_pause(_delta: float):
	velocity.x = move_toward(velocity.x, 0, acceleration * _delta)

func _switch_to_start_chase(player: Node2D):
	if current_state == State.START_CHASE or current_state == State.CHASE or current_state == State.STUCK_BY_WALL:
		target_player = player
		return

	target_player = player
	current_state = State.START_CHASE

	var dist_x = player.global_position.x - global_position.x
	if abs(dist_x) > 5.0:
		direction = 1 if dist_x > 0 else -1
		_update_sprite_direction()

	if not await _await_safe_timer(chase_switch_time):
		return

	if current_state == State.START_CHASE:
		if is_instance_valid(target_player):
			current_state = State.CHASE
		else:
			current_state = State.PATROL

func _switch_to_lost_target():
	if current_state != State.CHASE and current_state != State.STUCK_BY_WALL:
		target_player = null
		patrol_origin = global_position
		current_state = State.PATROL
		return

	target_player = null
	current_state = State.LOST_TARGET
	if not await _await_safe_timer(patrol_switch_time):
		return

	if current_state == State.LOST_TARGET:
		patrol_origin = global_position
		current_state = State.PATROL

func _check_player_left_chase_area() -> void:
	if not is_instance_valid(target_player) or not chase_area:
		_switch_to_lost_target()
		return
	if not target_player in chase_area.get_overlapping_bodies():
		_switch_to_lost_target()

func _check_all_overlaps():
	if (current_state == State.PATROL or current_state == State.PATROL_PAUSE or current_state == State.LOST_TARGET) and chase_area:
		var chase_bodies = chase_area.get_overlapping_bodies()
		for body in chase_bodies:
			if body.is_in_group("Player"):
				_switch_to_start_chase(body)
				return

	if (current_state == State.PATROL or current_state == State.PATROL_PAUSE or current_state == State.CHASE or current_state == State.START_CHASE) and detection_area:
		var detect_bodies = detection_area.get_overlapping_bodies()
		for body in detect_bodies:
			if body.is_in_group("Player"):
				var is_player_busy = body.get("is_in_h_mode") == true or \
									 (body.has_method("is_invincible") and body.is_invincible())
				if not is_player_busy:
					_trigger_player_h(body)
					return
				break

func _handle_cooldown(_delta: float):
	velocity.x = move_toward(velocity.x, 0, acceleration * _delta)

func _reverse_direction():
	direction *= -1
	global_position.x += direction * 2.0

func _update_sprite_direction():
	if visual_node:
		visual_node.scale.x = abs(visual_node.scale.x) * direction

func _update_floor_detector_position():
	if floor_detector:
		floor_detector.position.x = direction * 20.0

func _on_chase_entered(body: Node2D):
	if body.is_in_group("Player"):
		_switch_to_start_chase(body)

func _on_chase_exited(body: Node2D):
	if body == target_player:
		_switch_to_lost_target()

func _on_detection_body_entered(body: Node2D):
	if body.is_in_group("Player"):
		if current_state != State.HIDDEN and current_state != State.COOLDOWN:
			var is_player_busy = body.get("is_in_h_mode") == true or \
								 (body.has_method("is_invincible") and body.is_invincible())
			if not is_player_busy:
				_trigger_player_h(body)

func _trigger_player_h(player: CharacterBody2D):
	current_state = State.HIDDEN
	self.visible = false
	anim_phase = 0.0

	if player.has_method("start_h_event"):
		player.start_h_event(self, _pick_h_pose_tag())


## 從 h_pose_tags 隨機二選一；不看方向。列表空則退回 H_Pose_01
func _pick_h_pose_tag() -> String:
	if h_pose_tags.is_empty():
		return "H_Pose_01"
	var picked: String = h_pose_tags[randi() % h_pose_tags.size()]
	print("[SM AI] 隨機 H 姿勢: ", picked)
	return picked

func reactivate_monster():
	self.visible = true
	current_state = State.COOLDOWN
	if not await _await_safe_timer(3.0):
		return
	if current_state == State.COOLDOWN:
		current_state = State.PATROL
