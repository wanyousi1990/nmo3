extends Node2D
# ==============================================================================
# Dash_Visual
# 職責：衝刺姿勢 Naked / Clothed 層切換；Bra、ShirtOpen 由子 Sprite 腳本處理。
# 另負責衝刺時胸部／臀部彈簧晃動（輕量，無 RigidBody）。
# ==============================================================================

@export var pelvis_node: Node2D ## 骨盆節點（Naked/Clothed 層切換用）
@export var hip_node: Node2D ## 臀部晃動目標節點
@export var breasts: Array[Node2D] = [] ## 胸部晃動目標節點陣列（通常左、右胸）

@export_group("Breast Physics")
# [Naked, Clothed] 與 Visuals_Manager 相同索引
@export var b_stiffness_modes: Array[float] = [120.0, 140.0] ## [Naked, Clothed] 彈簧硬度；裸體較軟、著衣較硬
@export var b_damping_modes: Array[float] = [3.2, 3.8] ## [Naked, Clothed] 阻尼；裸體較小、晃較久
@export var b_max_offset_modes: Array[float] = [12.0, 10.0] ## [Naked, Clothed] 最大位移（像素）；裸體較大
@export var b_async_factor_modes: Array[float] = [0.35, 0.28] ## [Naked, Clothed] 左右胸初速不同步比例；裸體較明顯
@export var b_rotation_factor_modes: Array[float] = [0.14, 0.12] ## [Naked, Clothed] 位移轉成胸部旋轉的係數
@export var b_squash_factor_modes: Array[float] = [0.055, 0.045] ## [Naked, Clothed] 上下位移轉成擠壓變形的係數
@export var b_inertial_gain_modes: Array[float] = [0.026, 0.022] ## [Naked, Clothed] 加速度灌進彈簧速度（衝刺啟動那一下）
@export var b_lag_follow_gain_modes: Array[float] = [0.008, 0.006] ## [Naked, Clothed] 持續慣性位移；太大只剩跟著飛、沒有彈

@export_group("Hip Physics")
@export var h_stiffness_modes: Array[float] = [150.0, 170.0] ## [Naked, Clothed] 臀部彈簧硬度；裸體較軟
@export var h_damping_modes: Array[float] = [3.8, 4.4] ## [Naked, Clothed] 臀部阻尼；裸體較小、晃較久
@export var h_max_offset_modes: Array[float] = [10.0, 8.0] ## [Naked, Clothed] 臀部最大位移（像素）
@export var h_rotation_factor_modes: Array[float] = [0.12, 0.1] ## [Naked, Clothed] 位移轉成臀部旋轉的係數
@export var h_squash_factor_modes: Array[float] = [0.042, 0.035] ## [Naked, Clothed] 上下位移轉成臀部擠壓變形的係數
@export var h_inertial_gain_modes: Array[float] = [0.022, 0.018] ## [Naked, Clothed] 加速度灌進臀部彈簧速度
@export var h_lag_follow_gain_modes: Array[float] = [0.007, 0.005] ## [Naked, Clothed] 臀部持續慣性跟隨位移

@export_group("Ripple 水波餘震")
@export var b_ripple_freq_modes: Array[float] = [20.0, 22.0] ## [Naked, Clothed] 胸部水波餘震頻率
@export var b_ripple_size_modes: Array[float] = [0.15, 0.12] ## [Naked, Clothed] 胸部水波振幅倍率；裸體較大
@export var b_ripple_decay_modes: Array[float] = [0.45, 0.55] ## [Naked, Clothed] 胸部水波能量衰減；越大消得越快
@export var h_ripple_freq_modes: Array[float] = [16.0, 18.0] ## [Naked, Clothed] 臀部水波餘震頻率
@export var h_ripple_size_modes: Array[float] = [0.11, 0.09] ## [Naked, Clothed] 臀部水波振幅倍率
@export var h_ripple_decay_modes: Array[float] = [0.4, 0.5] ## [Naked, Clothed] 臀部水波能量衰減
@export var dash_ripple_boost_modes: Array[float] = [2.1, 1.8] ## [Naked, Clothed] 衝刺開始灌入的水波能量

@export_group("Dash Impulse")
@export var dash_impulse_modes: Array[Vector2] = [Vector2(-60.0, 26.0), Vector2(-52.0, 22.0)] ## [Naked, Clothed] 衝刺當下胸部彈簧初速度（X 負＝往後甩）
@export var dash_hip_impulse_modes: Array[Vector2] = [Vector2(-42.0, 18.0), Vector2(-36.0, 16.0)] ## [Naked, Clothed] 衝刺當下臀部彈簧初速度
@export var accel_clamp: float = 1800.0 ## 父節點加速度上限，避免瞬移造成爆衝
@export var settle_velocity_epsilon: float = 0.8 ## 判定彈簧已靜止的速度閾值
@export var settle_offset_epsilon: float = 0.03 ## 判定彈簧已靜止的位移閾值

var skin_nodes: Array[Node2D] = []

var initial_breast_positions: Array[Vector2] = []
var breast_vels: Array[Vector2] = []
var breast_offsets: Array[Vector2] = []
var breast_secondary: Array[Vector2] = []
var b_stiff_mul: Array[float] = []
var b_damp_mul: Array[float] = []

var initial_hip_pos: Vector2 = Vector2.ZERO
var hip_vel: Vector2 = Vector2.ZERO
var hip_offset: Vector2 = Vector2.ZERO
var hip_secondary: Vector2 = Vector2.ZERO

var b_ripple_energy: float = 0.0
var h_ripple_energy: float = 0.0
var t: float = 0.0

var parent_vel_prev: Vector2 = Vector2.ZERO
var _parent_vel_initialized: bool = false
var _body: CharacterBody2D = null


func _ready() -> void:
	_body = get_parent().get_parent() as CharacterBody2D
	_collect_skin_nodes()
	_initialize_physics()
	refresh_appearance()
	if not GlobalState.request_appearance_change.is_connected(_on_global_change_requested):
		GlobalState.request_appearance_change.connect(_on_global_change_requested)


func _exit_tree() -> void:
	if GlobalState.request_appearance_change.is_connected(_on_global_change_requested):
		GlobalState.request_appearance_change.disconnect(_on_global_change_requested)


func _on_global_change_requested(_type: int) -> void:
	refresh_appearance()


func refresh_appearance() -> void:
	_update_appearance_visuals()


func on_dash_started() -> void:
	_reset_soft_state()
	_parent_vel_initialized = false
	if _body:
		parent_vel_prev = _body.velocity
		_parent_vel_initialized = true
	var b_async_factor: float = _mode_f(b_async_factor_modes, 0.28)
	var dash_impulse: Vector2 = _mode_v2(dash_impulse_modes, Vector2(-52.0, 22.0))
	var dash_hip_impulse: Vector2 = _mode_v2(dash_hip_impulse_modes, Vector2(-36.0, 16.0))
	var dash_ripple_boost: float = _mode_f(dash_ripple_boost_modes, 1.8)
	for i in range(breast_vels.size()):
		var sync_break: float = randf_range(1.0 - b_async_factor, 1.0 + b_async_factor)
		breast_vels[i] += dash_impulse * sync_break
		breast_vels[i].x += randf_range(-6.0, 6.0)
	hip_vel += dash_hip_impulse
	hip_vel.x += randf_range(-4.0, 4.0)
	b_ripple_energy = clampf(b_ripple_energy + dash_ripple_boost, 0.0, 3.0)
	h_ripple_energy = clampf(h_ripple_energy + dash_ripple_boost * 0.85, 0.0, 3.0)


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	_calculate_physics(delta)
	_apply_visuals()


func _collect_skin_nodes() -> void:
	skin_nodes.clear()
	var node_names: Array[String] = ["Pelvis", "Hip", "Breast_L", "Breast_R"]
	for n_name in node_names:
		var n: Node2D = find_child(n_name, true, false) as Node2D
		if n:
			skin_nodes.append(n)


func _initialize_physics() -> void:
	initial_breast_positions.clear()
	breast_vels.clear()
	breast_offsets.clear()
	breast_secondary.clear()
	b_stiff_mul.clear()
	b_damp_mul.clear()
	for b in breasts:
		if b == null:
			continue
		initial_breast_positions.append(b.position)
		breast_vels.append(Vector2.ZERO)
		breast_offsets.append(Vector2.ZERO)
		breast_secondary.append(Vector2.ZERO)
		b_stiff_mul.append(randf_range(0.94, 1.06))
		b_damp_mul.append(randf_range(0.94, 1.06))
	if hip_node:
		initial_hip_pos = hip_node.position
	hip_vel = Vector2.ZERO
	hip_offset = Vector2.ZERO
	hip_secondary = Vector2.ZERO


func _reset_soft_state() -> void:
	for i in range(breast_vels.size()):
		breast_vels[i] = Vector2.ZERO
		breast_offsets[i] = Vector2.ZERO
		breast_secondary[i] = Vector2.ZERO
	hip_vel = Vector2.ZERO
	hip_offset = Vector2.ZERO
	hip_secondary = Vector2.ZERO
	b_ripple_energy = 0.0
	h_ripple_energy = 0.0


func _facing_sign() -> float:
	var vis: Node2D = get_parent() as Node2D
	if vis:
		return 1.0 if vis.scale.x >= 0.0 else -1.0
	return 1.0


func _local_body_velocity() -> Vector2:
	if _body == null:
		return Vector2.ZERO
	var face: float = _facing_sign()
	return Vector2(_body.velocity.x * face, _body.velocity.y)


func _mode_index() -> int:
	var mode: int = int(GlobalState.current_mode)
	return clampi(mode, 0, 1)


func _mode_f(arr: Array[float], fallback: float) -> float:
	var i: int = _mode_index()
	if i >= 0 and i < arr.size():
		return arr[i]
	return fallback


func _mode_v2(arr: Array[Vector2], fallback: Vector2) -> Vector2:
	var i: int = _mode_index()
	if i >= 0 and i < arr.size():
		return arr[i]
	return fallback


func _calculate_physics(delta: float) -> void:
	if _body == null:
		return
	if not _parent_vel_initialized:
		parent_vel_prev = _body.velocity
		_parent_vel_initialized = true

	var parent_accel: Vector2 = Vector2.ZERO
	if delta > 1e-8:
		parent_accel = ((_body.velocity - parent_vel_prev) / delta).limit_length(accel_clamp)
	var local_accel: Vector2 = Vector2(parent_accel.x * _facing_sign(), parent_accel.y)
	var local_vel: Vector2 = _local_body_velocity()
	var b_stiffness: float = _mode_f(b_stiffness_modes, 140.0)
	var b_damping: float = _mode_f(b_damping_modes, 3.8)
	var b_max_offset: float = _mode_f(b_max_offset_modes, 10.0)
	var b_inertial_gain: float = _mode_f(b_inertial_gain_modes, 0.022)
	var b_lag_follow_gain: float = _mode_f(b_lag_follow_gain_modes, 0.006)
	var h_stiffness: float = _mode_f(h_stiffness_modes, 170.0)
	var h_damping: float = _mode_f(h_damping_modes, 4.4)
	var h_max_offset: float = _mode_f(h_max_offset_modes, 8.0)
	var h_inertial_gain: float = _mode_f(h_inertial_gain_modes, 0.018)
	var h_lag_follow_gain: float = _mode_f(h_lag_follow_gain_modes, 0.005)
	var b_ripple_decay: float = _mode_f(b_ripple_decay_modes, 0.55)
	var h_ripple_decay: float = _mode_f(h_ripple_decay_modes, 0.5)

	for i in range(breast_vels.size()):
		var stiff_i: float = b_stiffness * b_stiff_mul[i]
		var v: Vector2 = breast_vels[i]
		var damp_i: float = b_damping * b_damp_mul[i]
		var accel: Vector2 = -stiff_i * breast_offsets[i] - damp_i * v - local_accel * b_inertial_gain
		breast_vels[i] = v + accel * delta
		var o: Vector2 = breast_offsets[i] + breast_vels[i] * delta
		breast_offsets[i] = Vector2(clampf(o.x, -b_max_offset, b_max_offset), clampf(o.y, -b_max_offset, b_max_offset))
		var lag_target: Vector2 = Vector2(-local_vel.x, -local_vel.y) * b_lag_follow_gain
		breast_secondary[i] = breast_secondary[i].lerp(lag_target, clampf(delta * 8.0, 0.0, 1.0))

	var h_accel: Vector2 = -h_stiffness * hip_offset - h_damping * hip_vel - local_accel * h_inertial_gain
	hip_vel += h_accel * delta
	var ho: Vector2 = hip_offset + hip_vel * delta
	hip_offset = Vector2(clampf(ho.x, -h_max_offset, h_max_offset), clampf(ho.y, -h_max_offset, h_max_offset))
	var hip_lag: Vector2 = Vector2(-local_vel.x, -local_vel.y) * h_lag_follow_gain
	hip_secondary = hip_secondary.lerp(hip_lag, clampf(delta * 8.0, 0.0, 1.0))

	b_ripple_energy = lerpf(b_ripple_energy, 0.0, delta * b_damping * b_ripple_decay)
	h_ripple_energy = lerpf(h_ripple_energy, 0.0, delta * h_damping * h_ripple_decay)

	parent_vel_prev = _body.velocity


func _apply_visuals() -> void:
	var b_ripple_freq: float = _mode_f(b_ripple_freq_modes, 22.0)
	var b_ripple_size: float = _mode_f(b_ripple_size_modes, 0.12)
	var b_rotation_factor: float = _mode_f(b_rotation_factor_modes, 0.12)
	var b_squash_factor: float = _mode_f(b_squash_factor_modes, 0.045)
	var h_ripple_freq: float = _mode_f(h_ripple_freq_modes, 18.0)
	var h_ripple_size: float = _mode_f(h_ripple_size_modes, 0.09)
	var h_rotation_factor: float = _mode_f(h_rotation_factor_modes, 0.1)
	var h_squash_factor: float = _mode_f(h_squash_factor_modes, 0.035)
	for i in range(breasts.size()):
		if i >= breast_offsets.size():
			continue
		var node: Node2D = breasts[i]
		if node == null:
			continue
		var offset: Vector2 = breast_offsets[i]
		var sec: Vector2 = breast_secondary[i]
		var phase_shift: float = float(i) * 0.55
		var ripple: float = sin((t + phase_shift) * b_ripple_freq) * b_ripple_energy * b_ripple_size
		var ripple_pos: Vector2 = Vector2(ripple * 4.0, -absf(ripple) * 6.0)
		node.position = initial_breast_positions[i] + offset + sec + ripple_pos
		node.rotation = (offset.x * 1.0 + offset.y * 0.2) * b_rotation_factor
		var squash: float = (-offset.y * b_squash_factor) + ripple
		node.scale = Vector2(1.0 + squash, 1.0 - squash)

	if hip_node:
		var h_ripple: float = sin(t * h_ripple_freq) * h_ripple_energy * h_ripple_size
		var h_ripple_pos: Vector2 = Vector2(h_ripple * 3.0, absf(h_ripple) * 5.0)
		hip_node.position = initial_hip_pos + hip_offset + hip_secondary + h_ripple_pos
		hip_node.rotation = (hip_offset.x * 1.0 + hip_offset.y * 0.2) * h_rotation_factor
		var h_squash: float = (-hip_offset.y * h_squash_factor) + h_ripple
		hip_node.scale = Vector2(1.0 + h_squash, 1.0 - h_squash)


func _update_appearance_visuals() -> void:
	var is_naked: bool = GlobalState.current_mode == GlobalState.AppearanceMode.NAKED
	for n in skin_nodes:
		# 約定：child 0 = NAKED、child 1 = CLOTHED；其後 Bra / ShirtOpen 由各自腳本控制
		if n.get_child_count() >= 2:
			n.get_child(0).visible = is_naked
			n.get_child(1).visible = not is_naked
