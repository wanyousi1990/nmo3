extends Node2D

# ==============================================================================
# Monster02_H_Controller (V1.2 - 全部位精細控制版)
# 職責：處理怪物 2 的衝擊動作，提供各部位獨立的慣性與旋轉參數。
# 特色：
#   1. 骨盆 (Pelvis) 主導逆時針旋轉。
#   2. 軀幹、大腿、陰莖、手部各別設定反向力參數。
#   3. 小腿 (Calf) 支援連動慣性。
# ==============================================================================

@export var target_h_controller: Node2D # 引用女主控制器
@export var move_root_instead_of_sprite: bool = true

@export_group("Thrust Settings (衝擊位移設定)")
@export var thrust_distance: float = 12.0 
@export var thrust_offset_vec: Vector2 = Vector2(-4, -1) # 面向左，故 X 為負

@export_group("Timing Settings (節奏感設定)")
@export var thrust_start_threshold: float = 0.75 
@export var pause_at_top_duration: float = 0.12 
@export var withdraw_speed: float = 7.0 

@export_group("Pelvis (骨盆 - 主旋轉)")
@export var pelvis_node: Node2D
@export var pelvis_rotation_bend: float = -12.0 # 逆時針旋轉

@export_group("Torso (軀幹 - 沉重感)")
@export var torso_node: Node2D
@export var torso_inertia: float = 0.15         # 位移反向力
@export var torso_rotation: float = 3.0         # 旋轉反向力

@export_group("Arm (手部 - 撐地感)")
@export var arm_node: Node2D
@export var arm_inertia: float = 0.3            # 手部通常慣性較大，模擬撐在原地的感覺
@export var arm_rotation: float = 5.0           # 衝擊時的彎曲感

@export_group("Thigh (大腿 - 支撐感)")
@export var thigh_node: Node2D
@export var thigh_inertia: float = 0.4          # 位移反向力
@export var thigh_rotation: float = 6.0         # 旋轉反向力

@export_group("Dick (陰莖 - 柔軟感)")
@export var dick_node: Node2D
@export var dick_inertia: float = 0.1           # 位移反向力
@export var dick_rotation: float = 15.0         # 旋轉反向力 (較大，增加甩動感)

@export_group("Calf (小腿 - 連動慣性)")
@export var calf_node: Node2D
@export var calf_inertia: float = 0.2           # 隨主位移的反向力
@export var calf_rotation: float = 10.0         # 旋轉補償

# 內部狀態儲存字典
var initial_states: Dictionary = {}

var current_move_amount: float = 0.0
var post_impact_pause_timer: float = 0.0
var last_impact_state: bool = false
var initial_pos: Vector2
var _was_h_active: bool = false

func _ready():
	initial_pos = self.position
	
	# 紀錄所有節點的初始狀態以便還原
	_record_node_initial("pelvis", pelvis_node)
	_record_node_initial("torso", torso_node)
	_record_node_initial("arm", arm_node)
	_record_node_initial("thigh", thigh_node)
	_record_node_initial("dick", dick_node)
	_record_node_initial("calf", calf_node)

func _record_node_initial(key: String, node: Node2D):
	if node:
		initial_states[key] = {"pos": node.position, "rot": node.rotation}

func _process(delta: float):
	var active: bool = target_h_controller != null and bool(target_h_controller.get("is_h_active"))
	if active and not _was_h_active:
		reset_thrust_pose()
	if not active:
		if _was_h_active:
			reset_thrust_pose()
		_was_h_active = false
		return
	_was_h_active = true
	
	var interval = target_h_controller.get("auto_impact_interval")
	var timer = target_h_controller.get("auto_impact_timer")
	
	if interval != null and interval > 0:
		_handle_movement_logic(delta, timer / interval)
		_apply_refined_visual_inertia(delta)
	else:
		_return_to_idle(delta)

## 中途退出／再進 H 時瞬間回到抽出姿勢
func reset_thrust_pose() -> void:
	current_move_amount = 0.0
	post_impact_pause_timer = 0.0
	last_impact_state = false
	position = initial_pos
	for pair in [
		["pelvis", pelvis_node], ["torso", torso_node], ["arm", arm_node],
		["thigh", thigh_node], ["dick", dick_node], ["calf", calf_node]
	]:
		var key: String = pair[0]
		var node: Node2D = pair[1]
		if node == null or not initial_states.has(key):
			continue
		var data = initial_states[key]
		node.position = data["pos"]
		node.rotation = data["rot"]

func _handle_movement_logic(delta: float, progress: float):
	if progress < 0.05 and not last_impact_state:
		last_impact_state = true
		post_impact_pause_timer = pause_at_top_duration
	elif progress > 0.5:
		last_impact_state = false

	if post_impact_pause_timer > 0:
		post_impact_pause_timer -= delta
		current_move_amount = 1.0
	elif progress < thrust_start_threshold:
		current_move_amount = lerp(current_move_amount, 0.0, delta * withdraw_speed)
	else:
		var p = (progress - thrust_start_threshold) / (1.0 - thrust_start_threshold)
		current_move_amount = clamp(p, 0.0, 1.0)
	
	var move_vec = thrust_offset_vec.normalized() * current_move_amount * thrust_distance
	self.position = initial_pos + move_vec

func _apply_refined_visual_inertia(delta: float, is_returning: bool = false):
	var move_vec = thrust_offset_vec.normalized() * current_move_amount * thrust_distance
	var lerp_val = delta * 5.0 if is_returning else 1.0
	
	# 1. 骨盆 (主體旋轉)
	_update_node_visual("pelvis", pelvis_node, Vector2.ZERO, pelvis_rotation_bend, lerp_val)
	
	# 2. 軀幹 (Torso)
	_update_node_visual("torso", torso_node, move_vec * torso_inertia, torso_rotation, lerp_val)
	
	# 3. 手部 (Arm)
	_update_node_visual("arm", arm_node, move_vec * arm_inertia, arm_rotation, lerp_val)
	
	# 4. 大腿 (Thigh)
	_update_node_visual("thigh", thigh_node, move_vec * thigh_inertia, thigh_rotation, lerp_val)
	
	# 5. 陰莖 (Dick)
	_update_node_visual("dick", dick_node, move_vec * dick_inertia, dick_rotation, lerp_val)
	
	# 6. 小腿 (Calf)
	_update_node_visual("calf", calf_node, move_vec * calf_inertia, calf_rotation, lerp_val)

func _update_node_visual(key: String, node: Node2D, offset: Vector2, rot_deg: float, lerp_val: float):
	if not node or not initial_states.has(key): return
	
	var data = initial_states[key]
	var target_pos = data["pos"] - offset # 反向位移
	var target_rot = data["rot"] + deg_to_rad(rot_deg) * current_move_amount # 反向/補償旋轉
	
	node.position = node.position.lerp(target_pos, lerp_val)
	node.rotation = lerp(node.rotation, target_rot, lerp_val)

func _return_to_idle(delta: float):
	var r_delta = delta * 5.0
	self.position = self.position.lerp(initial_pos, r_delta)
	current_move_amount = lerp(current_move_amount, 0.0, r_delta)
	_apply_refined_visual_inertia(delta, true)
