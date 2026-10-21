extends CharacterBody2D

# ==============================================================================
# Monster_04 (V1.0 - 含胸部彈簧物理)
# 基於 monster_01 邏輯，胸部晃動參考 visuals_manager.gd
# ==============================================================================

@export_group("H-Event Settings")
## 觸發 H 時從此列表隨機選一個姿勢（須與 OL_H_Visual 子節點名稱一致）
@export var h_pose_tags: Array[String] = ["H_Pose_01", "H_Pose_06"]

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
@export var breast_l_node: Node2D
@export var breast_r_node: Node2D

@export_group("Animation Settings")
@export var walk_anim_speed: float = 10.0       ## 步頻係數（影響所有肢體與胸部節奏）
@export var walk_anim_amplitude: float = 0.3    ## 腿部擺動幅度
@export var walk_bob_amplitude: float = 10.0    ## 走路時骨盆上下起伏幅度（像素）

@export_group("Breast Physics")
@export var b_stiffness: float = 220.0
@export var b_damping: float = 7.0
@export var b_max_offset: float = 7.0
@export var b_async_factor: float = 0.3
@export var b_rotation_factor: float = 0.1
@export var b_squash_factor: float = 0.025
@export var b_ripple_freq: float = 25.0
@export var b_ripple_size: float = 0.08
@export var b_ripple_decay: float = 0.4
@export var run_impact_vec: Vector2 = Vector2(1, 3.0)
@export var run_speed_threshold: float = 10.0
@export var run_impact_strength: float = 1.2
@export var b_accel_threshold: float = 8.0   ## 觸發起步/停止晃動的速度變化門檻（像素/秒）
@export var b_accel_strength: float = 1.0    ## 起步/停止晃動的衝量強度

@export_group("Detection Zones")
@export var chase_area: Area2D
@export var detection_area: Area2D

enum State { PATROL, PATROL_PAUSE, START_CHASE, CHASE, STUCK_BY_WALL, LOST_TARGET, HIDDEN, COOLDOWN }
var current_state = State.PATROL
var direction: int = 1
var target_player: CharacterBody2D = null
var anim_phase: float = 0.0
var t: float = 0.0
var reverse_cooldown: float = 0.0
var _impact_step_index: int = -1
var _prev_pelvis_y: float = 0.0
var patrol_origin: Vector2 = Vector2.ZERO
var patrol_pause_timer: float = 0.0
var prev_state = State.PATROL
var is_handling_wall := false

var breasts: Array[Node2D] = []
var initial_breast_positions: Array[Vector2] = []
var breast_vels: Array[Vector2] = []
var breast_offsets: Array[Vector2] = []
var b_ripple_energy: float = 0.0
var _prev_velocity_x: float = 0.0

@onready var visual_node = $Visaul
@onready var floor_detector: RayCast2D = $FloorDetector

func _ready() -> void:
	patrol_origin = global_position
	add_to_group("Monster")
	_initialize_breasts()

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

func _physics_process(delta: float) -> void:
	if current_state != prev_state:
		print("[DEBUG] 狀態: ", prev_state, " -> ", current_state)
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

func _initialize_breasts() -> void:
	for node in [breast_l_node, breast_r_node]:
		if node:
			breasts.append(node)
			initial_breast_positions.append(node.position)
			breast_vels.append(Vector2.ZERO)
			breast_offsets.append(Vector2.ZERO)
	if pelvis_node:
		_prev_pelvis_y = pelvis_node.position.y

func _update_procedural_animation(delta: float) -> void:
	t += delta
	var is_moving = abs(velocity.x) > 5.0 and is_on_floor()
	var speed_ratio = clamp(abs(velocity.x) / chase_speed, 0.0, 1.0)

	if is_moving:
		anim_phase += delta * walk_anim_speed * speed_ratio
	else:
		anim_phase = lerp(anim_phase, ceil(anim_phase / (PI * 2)) * PI * 2, delta * 10.0)

	var swing = sin(anim_phase) * walk_anim_amplitude

	if thigh_l_node:
		thigh_l_node.rotation = swing
	if thigh_r_node:
		thigh_r_node.rotation = -swing
	if arm_l_node:
		arm_l_node.rotation = -swing * 0.5
	if arm_r_node:
		arm_r_node.rotation = swing * 0.5

	var new_pelvis_y := 0.0
	if pelvis_node:
		if is_moving:
			new_pelvis_y = -abs(sin(anim_phase)) * walk_bob_amplitude * speed_ratio
		else:
			new_pelvis_y = lerpf(pelvis_node.position.y, 0.0, delta * 10.0)
		pelvis_node.position.y = new_pelvis_y

	_update_breast_movement_state(speed_ratio, new_pelvis_y)
	_update_breast_physics(delta)
	_apply_breast_visuals(is_moving, speed_ratio)

func _update_breast_movement_state(speed_ratio: float, pelvis_y: float) -> void:
	# ── 加速/減速慣性衝量（起步、停止、後撤轉前進都會觸發）──────────────
	var vel_delta = velocity.x - _prev_velocity_x
	if is_on_floor() and abs(vel_delta) > b_accel_threshold:
		_inject_breast_accel_impulse(vel_delta)
	_prev_velocity_x = velocity.x

	# ── 速度太低時跳過腳步衝擊，但仍保持 prev 同步 ──────────────────────
	if not is_on_floor() or abs(velocity.x) <= run_speed_threshold:
		_impact_step_index = -1
		_prev_pelvis_y = pelvis_y
		return

	# ── 用 anim_phase（真實步頻）觸發腳步衝擊，每半週期（一步）只觸發一次 ──
	var step_index = int(floor(anim_phase / PI))
	if step_index != _impact_step_index and abs(sin(anim_phase)) > 0.9:
		_impact_step_index = step_index
		_on_breast_impact_run(speed_ratio)

	# ── 骨盆上下位移的慣性也帶動胸部（跟隨走路起伏）────────────────────
	var pelvis_delta_y = pelvis_y - _prev_pelvis_y
	if abs(pelvis_delta_y) > 0.01:
		for i in range(breast_vels.size()):
			breast_vels[i].y += pelvis_delta_y * 8.0
	_prev_pelvis_y = pelvis_y

func _update_breast_physics(delta: float) -> void:
	for i in range(breast_vels.size()):
		var spring = -b_stiffness * breast_offsets[i]
		var damp = -b_damping * breast_vels[i]
		breast_vels[i] += (spring + damp) * delta
		breast_offsets[i] += breast_vels[i] * delta
		breast_offsets[i].x = clamp(breast_offsets[i].x, -b_max_offset, b_max_offset)
		breast_offsets[i].y = clamp(breast_offsets[i].y, -b_max_offset, b_max_offset)

	b_ripple_energy = lerp(b_ripple_energy, 0.0, delta * b_damping * b_ripple_decay)

func _apply_breast_visuals(is_moving: bool, speed_ratio: float) -> void:
	var is_running = is_moving and abs(velocity.x) > run_speed_threshold
	var run_twist_scale = speed_ratio if is_running else 0.0

	for i in range(breasts.size()):
		var node = breasts[i]
		var offset = breast_offsets[i]
		var phase_shift = i * 0.5
		var ripple = sin((t + phase_shift) * b_ripple_freq) * b_ripple_energy * b_ripple_size

		# run_twist 改用 anim_phase，讓扭轉節奏跟隨實際步頻
		var twist_side = -1.0 if i == 0 else 1.5
		var run_twist = sin(anim_phase + 0.1) * run_twist_scale
		var run_twist_offset = Vector2(run_twist * twist_side, -abs(run_twist) * 0.3)

		node.position = lerp(
			node.position,
			initial_breast_positions[i] + offset + run_twist_offset,
			0.4
		)
		node.rotation = (offset.x * 1.0 + offset.y * 0.2) * b_rotation_factor

		var squash = (-offset.y * b_squash_factor) + ripple
		node.scale = Vector2(1.0 + squash, 1.0 - squash)

func _on_breast_impact_run(speed_ratio: float = 1.0) -> void:
	var impact_scale = run_impact_strength * speed_ratio
	for i in range(breast_vels.size()):
		var sync_break = randf_range(1.0 - b_async_factor, 1.0 + b_async_factor)
		breast_vels[i] += run_impact_vec * sync_break * impact_scale
		breast_vels[i].x += randf_range(-8.0, 8.0) * speed_ratio

	b_ripple_energy = clamp(b_ripple_energy + 0.4 * speed_ratio, 0.0, 1.5)

func _inject_breast_accel_impulse(vel_delta: float) -> void:
	# vel_delta > 0：向右加速（胸部因慣性往左甩）
	# vel_delta < 0：向左加速/向右減速（胸部往右甩）
	var strength = clamp(abs(vel_delta) / acceleration, 0.0, 1.0) * b_accel_strength
	for i in range(breast_vels.size()):
		var sync_break = randf_range(1.0 - b_async_factor, 1.0 + b_async_factor)
		# x：慣性方向（與加速方向相反）
		breast_vels[i].x -= vel_delta * 0.08 * strength * sync_break
		# y：輕微上下甩動感
		breast_vels[i].y += abs(vel_delta) * 0.04 * strength * sync_break
	b_ripple_energy = clamp(b_ripple_energy + 0.3 * strength, 0.0, 1.5)

func _inject_breast_turn_impulse() -> void:
	for i in range(breast_vels.size()):
		var sync_break = randf_range(1.0 - b_async_factor, 1.0 + b_async_factor)
		breast_vels[i] += run_impact_vec * sync_break * 3.0
		breast_vels[i].x += randf_range(-10, 10)

	b_ripple_energy = clamp(b_ripple_energy + 0.5, 0.0, 2.0)

func _handle_patrol(_delta: float) -> void:
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
	print("[AI] 巡邏轉向前停頓: ", patrol_pause_timer, " 秒")

func _handle_patrol_pause(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, acceleration * _delta)
	patrol_pause_timer -= _delta
	if patrol_pause_timer <= 0.0:
		_reverse_direction()
		_update_sprite_direction()
		current_state = State.PATROL
		reverse_cooldown = 0.5
		print("[AI] 巡邏停頓結束，轉向繼續巡邏")

func _handle_chase(_delta: float) -> void:
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

func _handle_wall_collision() -> void:
	velocity.x = 0
	print("[AI] 追逐撞牆，開始後撤流程...")

	if not await _await_safe_timer(stuck_pause_time):
		is_handling_wall = false
		return

	var back_dir = -direction
	var start_x = global_position.x

	print("[AI] 執行後退，目標距離: ", stuck_back_distance)

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
	print("[AI] 後撤完成，準備恢復追逐")
	if not await _await_safe_timer(0.2):
		is_handling_wall = false
		return

	if current_state == State.STUCK_BY_WALL:
		current_state = State.CHASE

	is_handling_wall = false

func _handle_reaction_pause(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, acceleration * _delta)

func _switch_to_start_chase(player: Node2D) -> void:
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

func _switch_to_lost_target() -> void:
	# STUCK_BY_WALL 也允許切換：while 迴圈條件失效後協程會自然結束
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

func _check_all_overlaps() -> void:
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

func _handle_cooldown(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, acceleration * _delta)

func _reverse_direction() -> void:
	direction *= -1
	global_position.x += direction * 2.0
	_inject_breast_turn_impulse()

func _update_sprite_direction() -> void:
	if visual_node:
		visual_node.scale.x = abs(visual_node.scale.x) * direction

func _update_floor_detector_position() -> void:
	if floor_detector:
		floor_detector.position.x = direction * 20.0

func _on_chase_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_switch_to_start_chase(body)

func _on_chase_exited(body: Node2D) -> void:
	if body == target_player:
		_switch_to_lost_target()

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if current_state != State.HIDDEN and current_state != State.COOLDOWN:
			var is_player_busy = body.get("is_in_h_mode") == true or \
				(body.has_method("is_invincible") and body.is_invincible())

			if not is_player_busy:
				_trigger_player_h(body)

func _trigger_player_h(player: CharacterBody2D) -> void:
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
	print("[AI] 隨機 H 姿勢: ", picked)
	return picked

func reactivate_monster() -> void:
	self.visible = true
	current_state = State.COOLDOWN
	if not await _await_safe_timer(3.0):
		return
	if current_state == State.COOLDOWN:
		current_state = State.PATROL
