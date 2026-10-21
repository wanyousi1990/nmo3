extends Node2D

# ==============================================================================
# FM_H_Pose_02 控制器 (單一節點版 + 胸部衝擊晃動)
# 結構：Pelvis / Leg / Dick / Torso / Breast_L / Breast_R / Head
# 運作邏輯參考 FM_H_POSE_01_Controller.gd：
#   快速等速插入 → 衝擊到底停頓 → 平滑抽回，並於衝擊瞬間觸發胸部彈簧晃動 + 水波餘震。
# ==============================================================================

@export var target_h_controller: Node2D # 引用女主控制器 (H_Visual)
@export var move_root_instead_of_sprite: bool = true # 是否移動整個根節點而非單一 Sprite

@export_group("Thrust Settings (衝擊位移設定)")
@export var thrust_distance: float = 10.0 # 衝擊的最大距離 (像素)
@export var thrust_offset_vec: Vector2 = Vector2(0, -6) # 衝擊的方向向量

@export_group("Timing Settings (節奏感設定)")
@export var thrust_start_threshold: float = 0.75 # 進度達此比例時開始插入 (0.0~1.0)
@export var pause_at_top_duration: float = 0.1 # 衝擊到底後的停頓時間 (秒)
@export var withdraw_speed: float = 6.0 # 抽回動作的平滑速度

@export_group("Pelvis (骨盆 - 主旋轉)")
@export var pelvis_node: Node2D
@export var pelvis_rotation_bend: float = 10.0 # 衝擊到底時的旋轉角度

@export_group("Leg (腿部控制)")
@export var leg_node: Node2D
@export var leg_inertia: float = 0.4
@export var leg_rotation: float = 6.0

@export_group("Torso (軀幹控制)")
@export var torso_node: Node2D
@export var torso_inertia_factor: float = 0.2 # 軀幹反向位移強度
@export var torso_rotation_bend: float = 2.0 # 衝擊到底時軀幹傾斜角度

@export_group("Head (頭部控制)")
@export var head_node: Node2D
@export var head_inertia: float = 0.15
@export var head_rotation: float = 3.0

@export_group("Dick (陰莖精細控制)")
@export var dick_node: Node2D
@export var dick_inertia: float = 0.1
@export var dick_rotation: float = 12.0

@export_group("Breast Jiggle (胸部衝擊晃動)")
@export var breast_l_node: Node2D                     # 左胸
@export var breast_r_node: Node2D                     # 右胸
@export var breast_stiffness: float = 220.0           # 彈簧剛性 (越大回彈越快)
@export var breast_damping: float = 7.0               # 阻尼 (越大晃動越快停止)
@export var breast_max_offset: float = 8.0            # 位移上限 (像素)
@export var breast_impact_vec: Vector2 = Vector2(0, 80) # 衝擊瞬間注入的速度向量 (像素/秒)
@export var breast_impact_strength: float = 1.0       # 衝擊強度倍率
@export var breast_async_factor: float = 0.3          # 左右胸不同步係數 (0 = 完全同步)
@export var breast_rotation_factor: float = 0.1       # 位移對旋轉的影響係數
@export var breast_squash_factor: float = 0.03        # 位移對擠壓變形的影響係數
@export var breast_ripple_freq: float = 25.0          # 水波震動頻率 (Hz)
@export var breast_ripple_size: float = 0.08          # 水波震動幅度 (scale 變化量)
@export var breast_ripple_decay: float = 0.4          # 水波能量衰減速度 (越大衰減越快)
@export var breast_ripple_gain: float = 1.6           # 每次衝擊注入的水波能量

# 內部狀態變數
var initial_pos: Vector2
var node_initial_states: Dictionary = {}

var last_impact_state: bool = false 
var current_move_amount: float = 0.0
var post_impact_pause_timer: float = 0.0 # 用於處理衝擊後的停頓計時

# 胸部彈簧物理狀態
var breasts: Array[Node2D] = []
var initial_breast_pos: Array[Vector2] = []
var initial_breast_rot: Array[float] = []
var breast_vels: Array[Vector2] = []
var breast_offsets: Array[Vector2] = []

# 水波餘震狀態
var _t: float = 0.0          # 累計時間，驅動 sin 波
var _ripple_energy: float = 0.0  # 目前殘餘能量，衝擊時注入、每幀衰減
var _was_h_active: bool = false

func _ready():
	# 紀錄初始位置 (抽出狀態)
	initial_pos = self.position
	
	# 紀錄所有相關節點的初始狀態
	_record_initials("pelvis", [pelvis_node])
	_record_initials("leg", [leg_node])
	_record_initials("torso", [torso_node])
	_record_initials("head", [head_node])
	_record_initials("dick", [dick_node])
	_initialize_breasts()
	
	if target_h_controller:
		print("FM_H_Pose_02 控制器已就緒，已連結：", target_h_controller.name)

func _initialize_breasts():
	for node in [breast_l_node, breast_r_node]:
		if node is Node2D:
			breasts.append(node)
			initial_breast_pos.append(node.position)
			initial_breast_rot.append(node.rotation)
			breast_vels.append(Vector2.ZERO)
			breast_offsets.append(Vector2.ZERO)

func _record_initials(key: String, nodes: Array):
	var states = []
	for node in nodes:
		if node is Node2D:
			states.append({"pos": node.position, "rot": node.rotation})
		else:
			states.append(null)
	node_initial_states[key] = states

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
		var progress = timer / interval
		
		# --- 核心動作邏輯：插入、停頓、抽回 ---
		if progress < 0.05 and not last_impact_state:
			last_impact_state = true
			post_impact_pause_timer = pause_at_top_duration 
			_trigger_breast_impact() # 衝擊到底瞬間觸發胸部晃動
		elif progress > 0.5:
			last_impact_state = false
			
		if post_impact_pause_timer > 0:
			post_impact_pause_timer -= delta
			current_move_amount = 1.0 
		elif progress < thrust_start_threshold:
			current_move_amount = lerp(current_move_amount, 0.0, delta * withdraw_speed)
		else:
			var thrust_p = (progress - thrust_start_threshold) / (1.0 - thrust_start_threshold)
			current_move_amount = clamp(thrust_p, 0.0, 1.0)
		
		# --- 應用位移與慣性 ---
		var move_vec = thrust_offset_vec.normalized() * current_move_amount * thrust_distance
		self.position = initial_pos + move_vec
		
		_apply_all_inertia(move_vec)
		_update_breast_physics(delta)
	else:
		# 待機狀態：平滑回歸初始位置
		var return_delta = delta * 5.0
		self.position = self.position.lerp(initial_pos, return_delta)
		current_move_amount = lerp(current_move_amount, 0.0, return_delta)
		_apply_all_inertia(Vector2.ZERO, return_delta)
		_update_breast_physics(delta)

## 中途退出／再進 H 時瞬間回到抽出姿勢（不平滑殘留）
func reset_thrust_pose() -> void:
	current_move_amount = 0.0
	post_impact_pause_timer = 0.0
	last_impact_state = false
	_ripple_energy = 0.0
	position = initial_pos
	_apply_all_inertia(Vector2.ZERO)
	for i in range(breasts.size()):
		breast_vels[i] = Vector2.ZERO
		breast_offsets[i] = Vector2.ZERO
		if breasts[i]:
			breasts[i].position = initial_breast_pos[i]
			breasts[i].rotation = initial_breast_rot[i]
			breasts[i].scale = Vector2.ONE

# 統一處理所有節點的慣性應用
func _apply_all_inertia(move_vec: Vector2, lerp_delta: float = -1.0):
	# 1. 骨盆旋轉 (主體)
	_update_nodes_visual("pelvis", [pelvis_node], Vector2.ZERO, 0.0, pelvis_rotation_bend, lerp_delta)
	
	# 2. 腿部
	_update_nodes_visual("leg", [leg_node], move_vec, leg_inertia, leg_rotation, lerp_delta)
	
	# 3. 軀幹
	_update_nodes_visual("torso", [torso_node], move_vec, torso_inertia_factor, torso_rotation_bend, lerp_delta)
	
	# 4. 頭部
	_update_nodes_visual("head", [head_node], move_vec, head_inertia, head_rotation, lerp_delta)
	
	# 5. 陰莖
	_update_nodes_visual("dick", [dick_node], move_vec, dick_inertia, dick_rotation, lerp_delta)

# 內部函式：處理節點陣列的反向慣性位移與旋轉
func _update_nodes_visual(key: String, nodes: Array, body_offset: Vector2, inertia_factor: float, rot_bend: float, lerp_delta: float):
	if not node_initial_states.has(key): return
	var initials = node_initial_states[key]
	
	for i in range(nodes.size()):
		var node = nodes[i]
		if not node or not initials[i]: continue
		
		var data = initials[i]
		var target_offset = data["pos"] - (body_offset * inertia_factor)
		var target_rot = data["rot"] + deg_to_rad(rot_bend) * current_move_amount
		
		if lerp_delta > 0:
			node.position = node.position.lerp(target_offset, lerp_delta)
			node.rotation = lerp(node.rotation, data["rot"], lerp_delta)
		else:
			node.position = target_offset
			node.rotation = target_rot

# 衝擊到底瞬間：對每個胸部注入速度衝量，產生晃動
func _trigger_breast_impact():
	for i in range(breast_vels.size()):
		var sync_break = randf_range(1.0 - breast_async_factor, 1.0 + breast_async_factor)
		breast_vels[i] += breast_impact_vec * breast_impact_strength * sync_break
	_ripple_energy = clamp(_ripple_energy + breast_ripple_gain, 0.0, breast_ripple_gain * 2.0)

# 胸部彈簧物理：每幀朝初始位置回彈並套用位移、旋轉、擠壓 + 水波餘震
func _update_breast_physics(delta: float):
	_t += delta
	# 水波能量每幀依阻尼衰減
	_ripple_energy = lerpf(_ripple_energy, 0.0, delta * breast_damping * breast_ripple_decay)

	for i in range(breasts.size()):
		var node = breasts[i]
		if not node:
			continue
		
		# 彈簧 + 阻尼
		var spring = -breast_stiffness * breast_offsets[i]
		var damp = -breast_damping * breast_vels[i]
		breast_vels[i] += (spring + damp) * delta
		breast_offsets[i] += breast_vels[i] * delta
		breast_offsets[i] = breast_offsets[i].limit_length(breast_max_offset)
		
		var offset = breast_offsets[i]
		node.position = initial_breast_pos[i] + offset
		node.rotation = initial_breast_rot[i] + (offset.x + offset.y * 0.2) * breast_rotation_factor
		
		# 水波餘震：以各胸部半週期相位錯開，產生左右交替的細碎抖動
		var phase_shift = float(i) * 0.5
		var ripple = sin((_t + phase_shift) * breast_ripple_freq) * _ripple_energy * breast_ripple_size
		var squash = (-offset.y * breast_squash_factor) + ripple
		node.scale = Vector2(1.0 + squash, 1.0 - squash)

func force_single_thrust():
	# 預留手動觸發單次衝擊的介面
	pass
