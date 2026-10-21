extends CharacterBody2D

# ==============================================================================
# Monster_SideScroller_Logic (V4.6 - 後撤距離邏輯修正版)
# 職責：
#   1. 後撤邏輯修正: 改用目標座標判定，使 stuck_back_distance 參數生效。
#   2. 撞牆優化: 追逐時若撞牆會停頓並後退，避免物理抖動。
#   3. 程序化動畫：透過代碼控制肢體的 sin 擺動。
#   4. 狀態防抖：修正主角快速進出範圍導致怪物無限發呆的問題。
# ==============================================================================

@export_group("H-Event Settings")
## 觸發 H 時從此列表隨機選一個姿勢（須與 OL_H_Visual 子節點名稱一致）
@export var h_pose_tags: Array[String] = ["H_Pose_03"]

@export_group("Movement")
@export var speed: float = 60.0
@export var chase_speed: float = 90.0
@export var acceleration: float = 400.0
@export var gravity: float = 980.0
@export var patrol_limit: Vector2 = Vector2(-150, 150)

@export_group("Chase switch & Stuck Correction")
@export var chase_switch_time: float = 0.3
@export var patrol_switch_time: float = 1.0
@export var stuck_pause_time: float = 0.5     # 撞牆後的停頓時間
@export var stuck_back_distance: float = 30.0 # 撞牆後的後退距離 (像素)

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

# 內部狀態定義
enum State { PATROL, START_CHASE, CHASE, STUCK_BY_WALL, LOST_TARGET, HIDDEN, COOLDOWN }
var current_state = State.PATROL
var spawn_pos: Vector2
var direction: int = 1
var target_player: CharacterBody2D = null
var anim_phase: float = 0.0 

# 節點引用緩存
@onready var visual_node = $Visaul
@onready var floor_detector: RayCast2D = $FloorDetector 

func _ready():
	spawn_pos = global_position
	add_to_group("Monster")
	
	if floor_detector:
		floor_detector.enabled = true
		floor_detector.target_position = Vector2(0, 20)
	
	if chase_area:
		chase_area.body_entered.connect(_on_chase_entered)
		chase_area.body_exited.connect(_on_chase_exited)
	
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)

func _physics_process(delta: float):
	if current_state == State.HIDDEN:
		return 

	if not is_on_floor():
		velocity.y += gravity * delta

	match current_state:
		State.PATROL:
			_handle_patrol(delta)
			_check_all_overlaps()
		State.START_CHASE:
			_handle_reaction_pause(delta) 
			_check_all_overlaps() 
		State.CHASE:
			_handle_chase(delta)
			_check_all_overlaps()
		State.STUCK_BY_WALL:
			# 撞牆處理期間速度由協程控制，這裡維持物理模擬即可
			pass
		State.LOST_TARGET:
			_handle_reaction_pause(delta) 
		State.COOLDOWN:
			_handle_cooldown(delta)

	move_and_slide()
	_update_procedural_animation(delta) 
	
	if is_on_wall() and current_state == State.PATROL:
		_reverse_direction()

# --- 動畫邏輯 ---
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

# --- 巡邏邏輯 ---
func _handle_patrol(_delta: float):
	_update_floor_detector_position()
	
	var out_of_bounds = false
	if direction > 0 and global_position.x > spawn_pos.x + patrol_limit.y:
		out_of_bounds = true
	elif direction < 0 and global_position.x < spawn_pos.x + patrol_limit.x:
		out_of_bounds = true
	
	var is_near_edge = false
	if floor_detector and is_on_floor():
		if not floor_detector.is_colliding():
			is_near_edge = true
	
	if out_of_bounds or is_near_edge:
		_reverse_direction()
		
	velocity.x = move_toward(velocity.x, direction * speed, acceleration * _delta)
	_update_sprite_direction()

# --- 追逐邏輯 ---
func _handle_chase(_delta: float):
	if not is_instance_valid(target_player):
		_switch_to_lost_target()
		return
	
	if is_on_wall():
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

# --- 追逐撞牆處理邏輯 (修正版) ---
func _handle_wall_collision():
	current_state = State.STUCK_BY_WALL
	velocity.x = 0
	print("[AI] 追逐撞牆，停頓中...")
	
	if not await _await_safe_timer(stuck_pause_time):
		return
	
	# 改用目標位置判斷
	var back_dir = -direction
	var start_x = global_position.x
	var target_x = start_x + (back_dir * stuck_back_distance)
	
	print("[AI] 開始執行後退，目標距離: ", stuck_back_distance)
	
	# 持續移動直到到達目標位置或撞到另一面牆
	while (current_state == State.STUCK_BY_WALL):
		var current_dist = abs(global_position.x - start_x)
		if current_dist >= stuck_back_distance:
			break
		
		# 如果後退途中又撞牆，也停止
		if is_on_wall() and current_dist > 5.0: 
			break
			
		velocity.x = back_dir * (speed * 0.8)
		if not is_instance_valid(self) or not get_tree():
			return
		await get_tree().process_frame
		
	velocity.x = 0
	if not await _await_safe_timer(0.5):
		return
	
	if current_state == State.STUCK_BY_WALL:
		current_state = State.CHASE

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
		current_state = State.PATROL
		return

	target_player = null
	current_state = State.LOST_TARGET
	if not await _await_safe_timer(patrol_switch_time):
		return
	
	if current_state == State.LOST_TARGET:
		current_state = State.PATROL

# --- 核心：全範圍重疊檢查 ---
func _check_all_overlaps():
	if (current_state == State.PATROL or current_state == State.LOST_TARGET) and chase_area:
		var chase_bodies = chase_area.get_overlapping_bodies()
		for body in chase_bodies:
			if body.is_in_group("Player"):
				_switch_to_start_chase(body)
				return 

	if (current_state == State.PATROL or current_state == State.CHASE or current_state == State.START_CHASE) and detection_area:
		var detect_bodies = detection_area.get_overlapping_bodies()
		for body in detect_bodies:
			if body.is_in_group("Player"):
				var is_player_busy = body.get("is_in_h_mode") == true or \
									 (body.has_method("is_invincible") and body.is_invincible())
				
				if not is_player_busy:
					_trigger_player_h(body)
					return 
				break

# --- 冷卻狀態邏輯 ---
func _handle_cooldown(_delta: float):
	velocity.x = move_toward(velocity.x, 0, acceleration * _delta)

# --- 輔助功能 ---
func _reverse_direction():
	direction *= -1
	global_position.x += direction * 2.0 

func _update_sprite_direction():
	if visual_node:
		visual_node.scale.x = abs(visual_node.scale.x) * direction

func _update_floor_detector_position():
	if floor_detector:
		floor_detector.position.x = direction * 20.0

# --- 偵測區信號回調 ---
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


func _pick_h_pose_tag() -> String:
	if h_pose_tags.is_empty():
		return "H_Pose_03"
	return h_pose_tags[randi() % h_pose_tags.size()]

# --- 外部接口 ---
func reactivate_monster():
	self.visible = true
	current_state = State.COOLDOWN
	if not await _await_safe_timer(3.0):
		return
	if current_state == State.COOLDOWN:
		current_state = State.PATROL
