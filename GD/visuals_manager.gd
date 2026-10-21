extends Node2D

# ==============================================================================
# Visual_Manager (進階物理整合版)
# 職責：整合角色移動動畫與 OL_H_Controller 的精緻物理晃動邏輯。
# ==============================================================================

#enum AppearanceMode { NAKED, CLOTHED }
#@export var current_mode: AppearanceMode = AppearanceMode.NAKED
#@export var enable_cloth_keys: bool = false

@export var H_Controller: Node2D
@export var move_anim: AnimationPlayer ## 地圖移動用 AnimationPlayer（目前只播 run）
@export var run_anim_name: StringName = &"run" ## 跑步片段名稱
@export var idle_anim_name: StringName = &"idle" ## 站立片段（不被 run 的 RESET 蓋掉）
@export var run_anim_speed: float = 1.0 ## 跑步動畫播放倍率（隨走速會再乘一點）
@export var run_blend_in: float = 0.18 ## idle 接到 run 的過渡秒數（0＝立刻切）
@export var run_blend_out: float = 0.18 ## run 接到 idle 的過渡秒數（0＝立刻切）
@export var run_land_time: float = 0.125 ## 落地接 run 的時間軸（避開第 0 幀大彎腿）
@export var run_land_blend_in: float = 0.08 ## 落地接 run 的過渡秒數
@export var run_stop_grace: float = 0.08 ## 地面短暫鬆開方向鍵，不重跑 blend_in／out
@export var idle_return_lerp: float = 0.28 ## 落地／停跑後回到站姿的每幀插值
@export var run_breast_gather_time: float = 0.125 ## ARM_R 往前時胸聚攏（對 run 時間軸）
@export var run_butt_forward_time: float = 0.375 ## THIGH_R 往前時臀 X 往前（對 run 時間軸）
@export var run_body_twist_width: float = 0.1 ## 胸／臀跟著肢體的波峰寬度（秒）
@export var run_breast_l_gather: Vector2 = Vector2(-1.2, -0.3) ## 左胸聚攏位移（本地；X負＝往中，Y負＝往上）
@export var run_breast_r_gather: Vector2 = Vector2(1.8, -0.3) ## 右胸聚攏位移（本地；X正＝往中，Y負＝往上）
@export var run_butt_forward_x: float = 1.8 ## 右臀往前的 X（本地座標，正＝往面朝方向）
@export var run_butt_forward_y: float = 0.4 ## 臀往前時略下沉／鼓起的 Y

@export_group("Idle & Movement Settings")
@export var idle_speed: float = 3.0
@export var idle_amp: float = 1.0
@export var run_speed_threshold: float = 10.0
@export var run_freq: float = 8.5
@export var run_strength: float = 1.2
@export var run_leg_swing: float = 0.4  # 新增：控制跑步時大腿擺動幅度的變數
@export var run_impact_vec: Vector2 = Vector2(1, 3.0)
@export var jump_impact_vec: Vector2 = Vector2(0, 40)
@export var dash_end_impact_vec: Vector2 = Vector2(14.0, 10.0) ## 衝刺結束切回 Normal 時的物理衝擊（本地座標，X 正＝朝面朝方向繼續甩）
@export var dash_end_impact_scale: float = 1.0 ## 衝刺結束衝擊倍率

@export_group("Torso & Pelvis")
@export var torso_node: Node2D
@export var pelvis_node: Node2D
@export var torso_stiffness: float = 60.0
@export var torso_damping: float = 6.0
@export var torso_rotation: float = -0.07
@export var pelvis_stiffness: float = 140.0
@export var pelvis_damping: float = 12.0

@export_group("Breast Physics (新版彈簧物理)")
@export var breasts: Array[Node2D] = []
# [Naked, Clothed]
@export var b_stiffness_modes: Array[float] = [220.0, 220.0]
@export var b_damping_modes: Array[float] = [7.0, 9.0]
@export var b_max_offset_modes: Array[float] = [7.0, 5.0]
@export var b_async_factor_modes: Array[float] = [0.3, 0.2]
@export var b_rotation_factor: float = 0.1
@export var b_squash_factor: float = 0.025
@export var b_ripple_freq: float = 25.0
@export var b_ripple_size: float = 0.08
@export var b_ripple_decay: float = 0.4

@export_group("Butt Physics (新版彈簧物理)")
@export var butts: Array[Node2D] = []
# [Naked, Clothed]
@export var h_stiffness_modes: Array[float] = [300.0, 300.0]
@export var h_damping_modes: Array[float] = [9.0, 10.0]
@export var h_max_offset_modes: Array[float] = [10.0, 10.0]
@export var h_rotation_factor: float = 0.1
@export var h_squash_factor: float = 0.02
@export var h_expand_factor: float = 0.2
@export var h_ripple_freq: float = 30.0
@export var h_ripple_size: float = 0.05         # 臀部水波幅度
@export var h_ripple_decay: float = 0.4         # 臀部水波能量衰減速度


# ==============================================================================
# 內部變數
# ==============================================================================

@onready var parent: CharacterBody2D = _find_player_body()


func _find_player_body() -> CharacterBody2D:
	var n: Node = self
	while n:
		if n is CharacterBody2D:
			return n as CharacterBody2D
		n = n.get_parent()
	return null

var t: float = 0.0
var speed_ratio: float = 0.0
var last_facing: float = 1.0

# 初始位置紀錄
var initial_torso_pos: Vector2
var initial_pelvis_pos: Vector2
var initial_breast_positions: Array[Vector2] = []
var initial_butt_positions: Array[Vector2] = []
var initial_arm_rotations: Dictionary = {}
var initial_arm_positions: Dictionary = {}
var initial_forearm_positions: Dictionary = {}
var initial_leg_rotations: Dictionary = {}

# 物理狀態 (OL_H_Controller 核心變數)
var breast_vels: Array[Vector2] = []
var breast_offsets: Array[Vector2] = []
var butt_vels: Array[Vector2] = []
var butt_offsets: Array[Vector2] = []
var torso_vel: Vector2 = Vector2.ZERO
var torso_offset: Vector2 = Vector2.ZERO
var pelvis_vel: Vector2 = Vector2.ZERO
var pelvis_offset: Vector2 = Vector2.ZERO

var b_ripple_energy: float = 0.0
var h_ripple_energy: float = 0.0

var skin_nodes: Array[Node2D] = []
var _run_blend_t: float = 0.0
var _run_blend_out_t: float = 0.0
var _run_blending_out: bool = false
var _run_blend_from: Dictionary = {}
var _run_blend_nodes: Array[Node2D] = []
var _idle_pose: Dictionary = {}
var _idle_return: Dictionary = {}
var _run_advancing: bool = false
var _run_anim_res: Animation
var _run_clock: float = 0.0
var _run_tracks: Array = []
var _run_blend_in_now: float = 0.18
var _was_airborne: bool = false
var _run_stop_grace_t: float = 0.0

# ==============================================================================
# 生命週期與輸入
# ==============================================================================

func _ready() -> void:
	if move_anim == null:
		var nv: Node = find_child("Normal_Visual", true, false)
		if nv:
			move_anim = nv.get_node_or_null("MoveAnim") as AnimationPlayer
	if move_anim:
		## 不讓 AnimationPlayer 寫骨架：play() 會先跳到第 0 幀
		move_anim.active = false
		move_anim.playback_auto_capture = false
		_cache_run_tracks()
	_run_blend_in_now = run_blend_in
	_apply_idle_animation()
	_initialize_positions()
	_collect_skin_nodes()
	_collect_run_blend_nodes()
	_update_appearance_visuals()
	GlobalState.request_appearance_change.connect(_on_global_change_requested)

	
func _input(event: InputEvent) -> void:
		# 範例：按 S 鍵切換服裝（需購買 lewd_state_plus，或 debug／劇情開啟 enable_cloth_keys）
	if event is InputEventKey and event.pressed:
		if not GlobalState.can_use_cloth_keys(): return
		if event.keycode == KEY_S: # Tab 或自定義按鍵
			toggle_appearance()

func _on_global_change_requested(type: int):
	match type:
		0: # Toggle
			toggle_appearance()
		1: # Force Naked
			GlobalState.current_mode = GlobalState.AppearanceMode.NAKED
			_refresh_after_outfit_change()
			GlobalState.appearance_mode_changed.emit(GlobalState.current_mode)
		2: # Force Clothed
			GlobalState.current_mode = GlobalState.AppearanceMode.CLOTHED
			_refresh_after_outfit_change()
			GlobalState.appearance_mode_changed.emit(GlobalState.current_mode)


func _refresh_after_outfit_change() -> void:
	_update_appearance_visuals()
	var dash_vis: Node = find_child("Dash_Visual", true, false)
	if dash_vis and dash_vis.has_method("refresh_appearance"):
		dash_vis.refresh_appearance()
	if H_Controller and H_Controller.has_method("set_appearance_mode"):
		H_Controller._update_pose_visual_layers()


func _process(delta: float) -> void:
	if parent == null:
		parent = _find_player_body()
	if not parent: return
	t += delta
	
	_update_movement_state(delta)
	_calculate_physics_logic(delta)
	_apply_visuals(delta)

# ==============================================================================
# 外部介面
# ==============================================================================

func toggle_appearance() -> void:
	GlobalState.current_mode = GlobalState.AppearanceMode.CLOTHED if GlobalState.current_mode == GlobalState.AppearanceMode.NAKED else GlobalState.AppearanceMode.NAKED
	_refresh_after_outfit_change()
	GlobalState.appearance_mode_changed.emit(GlobalState.current_mode)
	print("已通知 OL_H_Controller 切換至模式: ", GlobalState.current_mode)



func update_facing(dir: float) -> void:
	var mode = GlobalState.current_mode
	var b_async_factor = b_async_factor_modes[mode]
	var target_facing = 1.0 if dir > 0 else -1.0
	var scale_sign: float = 1.0 if scale.x >= 0.0 else -1.0
	# H 進出會改 scale 但不改 last_facing：按住進場同向時不會觸發轉向，需先對齊
	if target_facing == last_facing:
		if scale_sign != target_facing:
			self.scale.x = target_facing
			print("[Visuals] 朝向與 scale 不同步，已對齊：", target_facing)
		return
	if target_facing != last_facing:
		last_facing = target_facing
		self.scale.x = last_facing
		# Visuals 可能被塞進 SubViewport，owner 會變 null；改用 parent（玩家）
		var body: Node = parent if parent else _find_player_body()
		if body == null and owner:
			body = owner
		if body and body.has_method("set_current_facing"):
			body.set_current_facing(last_facing)
		# 轉向時注入橫向衝量，產生甩動感
		#for i in range(breast_vels.size()): breast_vels[i].x += last_facing * 100.0
		#for i in range(butt_vels.size()): butt_vels[i].x -= last_facing * 10.0
		#for i in range(breast_vels.size()): breast_vels[i].y += 10.0
		#for i in range(butt_vels.size()): butt_vels[i].y += 10.0
		for i in range(breast_vels.size()):
			var sync_break = randf_range(1.0 - b_async_factor, 1.0 + b_async_factor)
			breast_vels[i] += run_impact_vec * sync_break * 10
			breast_vels[i].x += randf_range(-15, 15)
	
		for i in range(butt_vels.size()):
			butt_vels[i] += run_impact_vec * 7.5
			butt_vels[i].x += randf_range(-10, 10)
		
		b_ripple_energy = clamp(b_ripple_energy + 0.8, 0.0, 2.0)
		h_ripple_energy = clamp(h_ripple_energy + 0.8, 0.0, 2.0)

func on_jump_triggered() -> void:
	# 跳躍時向上彈起
	#for i in range(breast_vels.size()): breast_vels[i].y += 50.0
	#for i in range(butt_vels.size()): butt_vels[i].y += 20.0
	var mode = GlobalState.current_mode
	var b_async_factor = b_async_factor_modes[mode]
	for i in range(breast_vels.size()):
		var sync_break = randf_range(1.0 - b_async_factor, 1.0 + b_async_factor)
		breast_vels[i] += jump_impact_vec * sync_break * 2.0
		breast_vels[i].x += randf_range(-15, 15)
	
	for i in range(butt_vels.size()):
		butt_vels[i] += jump_impact_vec * 1.5
		butt_vels[i].x += randf_range(-10, 10)
	
	b_ripple_energy = clamp(b_ripple_energy + 0.8, 0.0, 2.0)
	h_ripple_energy = clamp(h_ripple_energy + 0.8, 0.0, 2.0)

func on_impact_landed() -> void:
	# 跳躍落地時向下壓並觸發餘震水波
	var mode = GlobalState.current_mode
	var b_async_factor = b_async_factor_modes[mode]
	for i in range(breast_vels.size()):
		var sync_break = randf_range(1.0 - b_async_factor, 1.0 + b_async_factor)
		breast_vels[i] += jump_impact_vec * sync_break * 2.5
		breast_vels[i].x += randf_range(-15, 15)
	
	for i in range(butt_vels.size()):
		butt_vels[i] += jump_impact_vec * 1.5
		butt_vels[i].x += randf_range(-10, 10)

	b_ripple_energy = clamp(b_ripple_energy + 1.6, 1.6, 4.0)
	h_ripple_energy = clamp(h_ripple_energy + 1.6, 1.6, 4.0)

func on_impact_run() -> void:
	# 落地時向下壓並觸發餘震水波
	#for i in range(breast_vels.size()): breast_vels[i].y -= 5.0
	#for i in range(butt_vels.size()): butt_vels[i].y += 5.0
	var mode = GlobalState.current_mode
	var b_async_factor = b_async_factor_modes[mode]
	for i in range(breast_vels.size()):
		var sync_break = randf_range(1.0 - b_async_factor, 1.0 + b_async_factor)
		breast_vels[i] += run_impact_vec * sync_break * 2.0
		breast_vels[i].x += randf_range(-15, 15)
	
	for i in range(butt_vels.size()):
		butt_vels[i] += run_impact_vec * 1.5
		butt_vels[i].x += randf_range(-10, 10)
	
	b_ripple_energy = clamp(b_ripple_energy + 0.6, 0.0, 1.5)
	h_ripple_energy = clamp(h_ripple_energy + 0.6, 0.0, 1.5)

func on_dash_ended() -> void:
	# 衝刺結束切回 Normal 瞬間：軟組織因急停繼續往前甩
	var mode = GlobalState.current_mode
	var b_async_factor = b_async_factor_modes[mode]
	var scale_mul: float = dash_end_impact_scale
	for i in range(breast_vels.size()):
		var sync_break = randf_range(1.0 - b_async_factor, 1.0 + b_async_factor)
		breast_vels[i] += dash_end_impact_vec * sync_break * scale_mul
		breast_vels[i].x += randf_range(-8, 8) * scale_mul
	for i in range(butt_vels.size()):
		butt_vels[i] += dash_end_impact_vec * 0.75 * scale_mul
		butt_vels[i].x += randf_range(-6, 6) * scale_mul
	b_ripple_energy = clamp(b_ripple_energy + 0.9 * scale_mul, 0.0, 2.5)
	h_ripple_energy = clamp(h_ripple_energy + 0.7 * scale_mul, 0.0, 2.5)

# ==============================================================================
# 核心物理運算 (改進版)
# ==============================================================================

func _calculate_physics_logic(delta: float) -> void:
	var mode = GlobalState.current_mode
	var b_stiff = b_stiffness_modes[mode]
	var b_damp = b_damping_modes[mode]
	var b_max = b_max_offset_modes[mode]
	var h_stiff = h_stiffness_modes[mode]
	var h_damp = h_damping_modes[mode]
	var h_max = h_max_offset_modes[mode]

	# 1. 胸部物理計算
	for i in range(breast_vels.size()):
		var spring = -b_stiff * breast_offsets[i]
		var damp = -b_damp * breast_vels[i]
		breast_vels[i] += (spring + damp) * delta
		breast_offsets[i] += breast_vels[i] * delta
		#breast_offsets[i] = breast_offsets[i].limit_length(b_max)
		breast_offsets[i].x = clamp(breast_offsets[i].x, -b_max, b_max)
		breast_offsets[i].y = clamp(breast_offsets[i].y, -b_max, b_max)

	# 2. 臀部物理計算
	for i in range(butt_vels.size()):
		var spring = -h_stiff * butt_offsets[i]
		var damp = -h_damp * butt_vels[i]
		butt_vels[i] += (spring + damp) * delta
		butt_offsets[i] += butt_vels[i] * delta
		#butt_offsets[i] = butt_offsets[i].limit_length(h_max)
		butt_offsets[i].x = clamp(butt_offsets[i].x, -h_max, h_max)
		butt_offsets[i].y = clamp(butt_offsets[i].y, -h_max, h_max)

	# 3. 軀幹與骨盆彈簧
	torso_vel += (-torso_stiffness * torso_offset - torso_damping * torso_vel) * delta
	torso_offset += torso_vel * delta
	pelvis_vel += (-pelvis_stiffness * pelvis_offset - pelvis_damping * pelvis_vel) * delta
	pelvis_offset += pelvis_vel * delta

	# 4. 餘震能量衰減
	b_ripple_energy = lerp(b_ripple_energy, 0.0, delta * b_damping_modes[mode] * b_ripple_decay)
	h_ripple_energy = lerp(h_ripple_energy, 0.0, delta * h_damping_modes[mode] * h_ripple_decay)

func _update_movement_state(_delta: float) -> void:
	var max_speed = parent.SPEED if "SPEED" in parent else 300.0
	speed_ratio = clamp(abs(parent.velocity.x) / max_speed, 0.0, 1.0)
	
	# 處理跑步時的節奏性撞擊感
	if parent.is_on_floor() and abs(parent.velocity.x) > run_speed_threshold:
		var run_wave = sin(t * run_freq)
		if abs(run_wave) > 0.95: # 模擬腳步踩下瞬間
			on_impact_run()

func _using_run_anim() -> bool:
	return move_anim != null and move_anim.has_animation(run_anim_name)


func _apply_idle_animation() -> void:
	if move_anim == null or not move_anim.has_animation(idle_anim_name):
		return
	var anim: Animation = move_anim.get_animation(idle_anim_name)
	if anim == null:
		return
	var root: Node = move_anim.get_node_or_null(move_anim.root_node)
	if root == null:
		return
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_VALUE:
			continue
		if not anim.track_is_enabled(i):
			continue
		var bits: PackedStringArray = String(anim.track_get_path(i)).split(":")
		if bits.size() < 2:
			continue
		var n: Node = root.get_node_or_null(NodePath(bits[0]))
		if n == null:
			continue
		n.set(bits[1], anim.track_get_key_value(i, 0))


func _run_length() -> float:
	if _run_anim_res == null:
		return 0.0
	return _run_anim_res.length


func _run_anim_time() -> float:
	var length: float = _run_length()
	if length <= 0.0:
		return 0.0
	return fposmod(_run_clock, length)


func _run_cycle_peak(peak_t: float) -> float:
	## 時間軸在 peak_t 附近為 1，遠離則為 0；會繞 0.5 秒循環
	if not _using_run_anim() or _run_anim_res == null:
		return 0.0
	var length: float = _run_length()
	if length <= 0.001:
		return 0.0
	if run_body_twist_width <= 0.0:
		return 0.0
	var d: float = _run_anim_time() - peak_t
	d = d - length * floor((d + length * 0.5) / length)
	var u: float = d / run_body_twist_width
	if absf(u) >= 1.0:
		return 0.0
	return 0.5 * (1.0 + cos(PI * u))


func _collect_run_blend_nodes() -> void:
	_run_blend_nodes.clear()
	var names: PackedStringArray = [
		"Pelvis", "Torso", "Head",
		"Arm_L", "Arm_R", "Forearm_L", "Forearm_R",
		"Thigh_L", "Thigh_R", "Calf_L", "Calf_R",
	]
	var root_container: Node = find_child("Normal_Visual", true, false)
	if root_container == null:
		root_container = self
	for n_name in names:
		var n: Node = root_container.find_child(n_name, true, false)
		if n is Node2D:
			_run_blend_nodes.append(n as Node2D)
	_store_idle_pose()


func _store_idle_pose() -> void:
	_idle_pose.clear()
	for n in _run_blend_nodes:
		if n == null:
			continue
		_idle_pose[n] = {
			"pos": n.position,
			"rot": n.rotation,
			"scl": n.scale,
			"skew": n.skew,
		}


func _snapshot_run_blend() -> void:
	_run_blend_from.clear()
	for n in _run_blend_nodes:
		if n == null:
			continue
		_run_blend_from[n] = {
			"pos": n.position,
			"rot": n.rotation,
			"scl": n.scale,
			"skew": n.skew,
		}


func _copy_pose(src: Dictionary) -> Dictionary:
	var dst: Dictionary = {}
	for n in src:
		var p: Dictionary = src[n]
		dst[n] = {
			"pos": p["pos"],
			"rot": p["rot"],
			"scl": p["scl"],
			"skew": p.get("skew", 0.0),
		}
	return dst


func _cache_run_tracks() -> void:
	_run_tracks.clear()
	_run_anim_res = null
	if move_anim == null or not move_anim.has_animation(run_anim_name):
		return
	_run_anim_res = move_anim.get_animation(run_anim_name)
	var root: Node = move_anim.get_node_or_null(move_anim.root_node)
	if root == null or _run_anim_res == null:
		return
	for i in _run_anim_res.get_track_count():
		if _run_anim_res.track_get_type(i) != Animation.TYPE_VALUE:
			continue
		if not _run_anim_res.track_is_enabled(i):
			continue
		var bits: PackedStringArray = String(_run_anim_res.track_get_path(i)).split(":")
		if bits.size() < 2:
			continue
		var node := root.get_node_or_null(bits[0]) as Node2D
		if node == null:
			continue
		_run_tracks.append({"i": i, "node": node, "prop": bits[1]})


func _pose_key_for_prop(prop: String) -> String:
	match prop:
		"position":
			return "pos"
		"rotation":
			return "rot"
		"scale":
			return "scl"
		"skew":
			return "skew"
		_:
			return ""


func _blend_track_value(prop: String, from: Variant, to: Variant, w: float) -> Variant:
	if prop == "rotation":
		return lerp_angle(from as float, to as float, w)
	if from is Vector2 and to is Vector2:
		return (from as Vector2).lerp(to as Vector2, w)
	if typeof(from) == TYPE_FLOAT or typeof(from) == TYPE_INT:
		return lerpf(from as float, to as float, w)
	return to


func _write_run_sample(w: float) -> void:
	if _run_anim_res == null:
		return
	var length: float = _run_length()
	var time: float = 0.0 if length <= 0.0 else fposmod(_run_clock, length)
	for tr in _run_tracks:
		var node: Node2D = tr["node"]
		var prop: String = tr["prop"]
		var sampled: Variant = _run_anim_res.value_track_interpolate(int(tr["i"]), time)
		var written: Variant = sampled
		if w < 1.0 and _run_blend_from.has(node):
			var from: Dictionary = _run_blend_from[node]
			var key: String = _pose_key_for_prop(prop)
			if key != "" and from.has(key):
				written = _blend_track_value(prop, from[key], sampled, w)
		node.set(prop, written)


func _pick_run_time_near_pose() -> float:
	## 站姿最接近的跑步時間。第 0 幀小腿彎很大，不要每次都從那裡開始
	var length: float = _run_length()
	if length <= 0.0 or _run_anim_res == null:
		return 0.0
	var best_t: float = 0.0
	var best_score: float = INF
	var steps: int = 16
	for s in steps:
		var time: float = length * float(s) / float(steps)
		var score: float = 0.0
		for tr in _run_tracks:
			if String(tr["prop"]) != "rotation":
				continue
			var node: Node2D = tr["node"]
			if node == null:
				continue
			var sampled: float = float(_run_anim_res.value_track_interpolate(int(tr["i"]), time))
			score += absf(angle_difference(node.rotation, sampled))
		if score < best_score:
			best_score = score
			best_t = time
	return best_t


func _run_blend_weight() -> float:
	if _run_blend_in_now <= 0.0:
		return 1.0
	var w: float = clampf(_run_blend_t / _run_blend_in_now, 0.0, 1.0)
	return w * w * (3.0 - 2.0 * w)


func _run_blend_out_weight() -> float:
	if run_blend_out <= 0.0:
		return 1.0
	var w: float = clampf(_run_blend_out_t / run_blend_out, 0.0, 1.0)
	return w * w * (3.0 - 2.0 * w)


func _apply_run_blend_out(delta: float) -> void:
	_run_blend_out_t += delta
	var w: float = _run_blend_out_weight()
	for n in _run_blend_from:
		if n == null or not _idle_pose.has(n):
			continue
		var from: Dictionary = _run_blend_from[n]
		var idle: Dictionary = _idle_pose[n]
		n.position = from["pos"].lerp(idle["pos"], w)
		n.rotation = lerp_angle(from["rot"], idle["rot"], w)
		n.scale = from["scl"].lerp(idle["scl"], w)
		n.skew = lerpf(from.get("skew", 0.0) as float, idle.get("skew", 0.0) as float, w)
	if w >= 1.0:
		_run_blending_out = false
		_run_blend_from.clear()


func _lerp_to_idle_pose(alpha: float) -> void:
	## 手腳／頭回到 idle.tres 站姿（含 Calf 位置），骨盆／軀幹留給上面的呼吸
	if alpha <= 0.0 or _idle_pose.is_empty():
		return
	for n in _idle_pose:
		if n == null or n == torso_node or n == pelvis_node:
			continue
		var idle: Dictionary = _idle_pose[n]
		n.position = n.position.lerp(idle["pos"], alpha)
		n.rotation = lerp_angle(n.rotation, idle["rot"], alpha)
		n.scale = n.scale.lerp(idle["scl"], alpha)
		n.skew = lerpf(n.skew, idle.get("skew", 0.0) as float, alpha)


func _begin_run_from_current_pose(from_air: bool) -> void:
	_snapshot_run_blend()
	if from_air:
		_run_clock = clampf(run_land_time, 0.0, maxf(_run_length(), 0.0))
		_run_blend_in_now = run_land_blend_in
	elif _run_blending_out:
		_run_blend_in_now = run_blend_in
	else:
		_run_clock = _pick_run_time_near_pose()
		_run_blend_in_now = run_blend_in
	_idle_return = _copy_pose(_idle_pose)
	_run_blend_t = 0.0
	_run_blending_out = false
	_run_advancing = true
	_run_stop_grace_t = 0.0


func _stop_run_to_idle() -> void:
	_snapshot_run_blend()
	_run_advancing = false
	_run_blend_t = 0.0
	_run_stop_grace_t = 0.0
	if parent.is_on_floor() and run_blend_out > 0.0 and not _idle_pose.is_empty():
		_run_blend_out_t = 0.0
		_run_blending_out = true
	else:
		_run_blending_out = false
		_run_blend_from.clear()


func _sync_run_anim(is_running: bool, delta: float) -> void:
	if not _using_run_anim() or _run_anim_res == null:
		_was_airborne = parent == null or not parent.is_on_floor()
		return
	var on_floor: bool = parent.is_on_floor()
	var from_air: bool = _was_airborne and on_floor
	var play_run: bool = is_running and on_floor
	if play_run:
		_run_stop_grace_t = 0.0
		if not _run_advancing:
			_begin_run_from_current_pose(from_air)
		else:
			var speed: float = run_anim_speed * lerpf(0.75, 1.25, speed_ratio)
			_run_clock += delta * speed
			_run_blend_t += delta
		_write_run_sample(_run_blend_weight())
	elif _run_advancing:
		if on_floor and run_stop_grace > 0.0 and _run_stop_grace_t < run_stop_grace:
			## 連打方向鍵：先停在當下跑步姿勢，不要重開混接、不要配第 0 幀
			_run_stop_grace_t += delta
			_write_run_sample(1.0)
		elif on_floor:
			_stop_run_to_idle()
		else:
			_run_advancing = false
			_run_blending_out = false
			_run_stop_grace_t = 0.0
	elif _run_blending_out and not on_floor:
		_run_blending_out = false
	_was_airborne = not on_floor


func _apply_visuals(delta: float) -> void:
	var idle_weight = clamp(1.0 - speed_ratio * 1.5, 0.0, 1.0)
	var breath = sin(t * idle_speed) * idle_weight
	var is_running = abs(parent.velocity.x) > run_speed_threshold
	var torso_rot = 0.0
	_sync_run_anim(is_running, delta)
	var run_from_anim: bool = _using_run_anim() and _run_advancing
	if _run_blending_out:
		_apply_run_blend_out(delta)
	
	# 軀幹動畫（跑步改由 MoveAnim/run 時間軸；這裡只疊彈簧位移）
	if torso_node:
		if run_from_anim or _run_blending_out:
			torso_node.position += torso_offset
		else:
			var run_bob = abs(sin(t * run_freq)) * 1.5 if is_running and parent.is_on_floor() else 0.0
			if is_running and parent.is_on_floor():
				torso_rot = torso_rotation
				breath = 0.0
			elif not parent.is_on_floor():
				torso_rot = torso_rotation * 2.0
				breath = 0.0
				
			torso_node.position = lerp(
				torso_node.position,
				 initial_torso_pos + torso_offset + Vector2(0, breath * 2.0 + run_bob),
				 0.4
				)
			
			torso_node.rotation = lerp_angle(
				torso_node.rotation, torso_rot + breath * 0.04, 0.2
				)
	
	# 骨盆動畫
	if pelvis_node:
		if run_from_anim or _run_blending_out:
			pelvis_node.position += pelvis_offset
		else:
			var run_bob = abs(sin(t * run_freq)) * 2.5 if is_running and parent.is_on_floor() else 0.0
			pelvis_node.position = lerp(
				pelvis_node.position, 
				initial_pelvis_pos + pelvis_offset + Vector2(0, run_bob), 
				0.4
				)
			var idle_pelvis_rot: float = 0.0
			if _idle_pose.has(pelvis_node):
				idle_pelvis_rot = _idle_pose[pelvis_node]["rot"]
			pelvis_node.rotation = lerp_angle(pelvis_node.rotation, idle_pelvis_rot, 0.25)
	
	# 胸部應用
	for i in range(breasts.size()):
		var node = breasts[i]
		if node == null or i >= breast_offsets.size() or i >= initial_breast_positions.size():
			continue
		var offset = breast_offsets[i]
		var phase_shift = i * 0.5
		# 水波餘震
		var ripple = sin((t + phase_shift) * b_ripple_freq) * b_ripple_energy * b_ripple_size
		
		# 左右獨立聚攏：跑步時對齊 run 時間軸（0.125＝ARM_R 往前）
		var run_twist: float = 0.0
		if is_running and parent.is_on_floor():
			if run_from_anim:
				run_twist = _run_cycle_peak(run_breast_gather_time) * _run_blend_weight()
			else:
				run_twist = sin((t + 0.1) * run_freq)
		var is_left_breast: bool = String(node.name).contains("Breast_L") or String(node.name).ends_with("_L")
		var gather_vec: Vector2 = run_breast_l_gather if is_left_breast else run_breast_r_gather
		var run_twist_offset = gather_vec * run_twist
		
		node.position = lerp(node.position, initial_breast_positions[i] + offset + run_twist_offset, 0.4)
		node.rotation = (offset.x * 1.0 + offset.y * 0.2) * b_rotation_factor
		
		# 擠壓與水波變形
		var squash = (-offset.y * b_squash_factor) + ripple
		node.scale = Vector2(1.0 + squash, 1.0 - squash)

	# 臀部應用
	for i in range(butts.size()):
		var node = butts[i]
		if node == null or i >= butt_offsets.size() or i >= initial_butt_positions.size():
			continue
		var offset = butt_offsets[i]
		var side_dir = -1.0 if i == 0 else 1.0
		var dynamic_expand = Vector2(offset.y * h_expand_factor * side_dir, 0)
		var ripple = sin(t * h_ripple_freq) * h_ripple_energy * h_ripple_size
		
		# 跑步時對齊 run 時間軸（0.375＝THIGH_R 往前→臀 X 往前）
		var run_twist: float = 0.0
		if is_running and parent.is_on_floor():
			if run_from_anim:
				run_twist = _run_cycle_peak(run_butt_forward_time) * _run_blend_weight()
			else:
				run_twist = sin((t + 0.3) * run_freq)
		var run_twist_offset := Vector2.ZERO
		if run_from_anim:
			run_twist_offset = Vector2(run_twist * run_butt_forward_x, abs(run_twist) * run_butt_forward_y)
		else:
			var twist_side = 1.0 if i == 0 else -1.0
			run_twist_offset = Vector2(run_twist * twist_side * 1.5, abs(run_twist))
		node.position = lerp(node.position, initial_butt_positions[i] + offset + run_twist_offset + dynamic_expand, 0.4)
		node.rotation = (offset.x * 1.0 + offset.y * 0.2) * h_rotation_factor
		
		var squash = (-offset.y * h_squash_factor) + ripple
		node.scale = Vector2(1.0 + squash, 1.0 - squash)

	if not run_from_anim and not _run_blending_out:
		if parent.is_on_floor() and not is_running:
			_lerp_to_idle_pose(idle_return_lerp)
		else:
			_apply_limbs(is_running)

# ==============================================================================
# 輔助函式
# ==============================================================================

func _initialize_positions() -> void:
	if torso_node:
		initial_torso_pos = torso_node.position
		for side in ["_L", "_R"]:
			var arm = torso_node.get_node_or_null("Arm" + side)
			if arm:
				initial_arm_rotations[side] = arm.rotation
				initial_arm_positions[side] = arm.position
				var forearm = arm.get_node_or_null("Forearm" + side)
				if forearm: initial_forearm_positions[side] = forearm.position
	
	if pelvis_node:
		initial_pelvis_pos = pelvis_node.position
		for side in ["_L", "_R"]:
			var thigh = pelvis_node.get_node_or_null("Thigh" + side)
			if thigh: initial_leg_rotations[side] = thigh.rotation

	for b in breasts:
		# 空槽仍佔 index（左右對應），避免 SANDBOX 對 null 讀 position
		if b == null:
			initial_breast_positions.append(Vector2.ZERO)
			breast_vels.append(Vector2.ZERO)
			breast_offsets.append(Vector2.ZERO)
			continue
		initial_breast_positions.append(b.position)
		breast_vels.append(Vector2.ZERO)
		breast_offsets.append(Vector2.ZERO)
	
	for b in butts:
		if b == null:
			initial_butt_positions.append(Vector2.ZERO)
			butt_vels.append(Vector2.ZERO)
			butt_offsets.append(Vector2.ZERO)
			continue
		initial_butt_positions.append(b.position)
		butt_vels.append(Vector2.ZERO)
		butt_offsets.append(Vector2.ZERO)

func _collect_skin_nodes() -> void:
	var node_names = ["Pelvis", "Torso", "Breast_L", "Breast_R", "Arm_R", "Forearm_R", "Arm_L", "Forearm_L", "Hip_L", "Hip_R", "Thigh_R", "Calf_R", "Thigh_L", "Calf_L"]
	var root_container = find_child("Normal_Visual", true, false)
	if not root_container: root_container = self
	for n_name in node_names:
		var n = root_container.find_child(n_name, true, false)
		if n: skin_nodes.append(n)

func _update_appearance_visuals() -> void:
	for n in skin_nodes:
		if n.get_child_count() >= 2:
			n.get_child(0).visible = (GlobalState.current_mode == GlobalState.AppearanceMode.NAKED)
			n.get_child(1).visible = (GlobalState.current_mode == GlobalState.AppearanceMode.CLOTHED)

func _apply_limbs(is_running: bool) -> void:
# =========================================================
# LEGS (少女小跑步 - 角度驅動版 + 完整註解)
# =========================================================
	if pelvis_node:  # 確保骨盆節點存在
		for side in ["_L", "_R"]:  # 依序處理左右腿
			var thigh = pelvis_node.get_node_or_null("Thigh" + side)  # 取得大腿節點
			if not thigh:
				continue  # 若找不到大腿則跳過

			var swing_phase = 0.0 if side == "_L" else PI  # 左右腿錯開半個週期
			var cycle = sin(t * run_freq + swing_phase)  # 跑步正弦週期值 (-1 ~ 1)
			var cycle_cos = cos(t * run_freq + swing_phase) # 取得餘弦值判斷運動方向

			# -----------------------------
			# 🌸 少女小跑步 - 大腿控制
			# -----------------------------

			var small_step_amplitude = run_leg_swing * 0.4 # 控制步幅大小（越小越碎步）
			var inner_offset = -0.05 if side == "_L" else -0.1  # 讓雙腿微內收（窄裙感）

			var target_rot = 0.0  # 大腿目標角度

			if not parent.is_on_floor():
				target_rot = -0.15 if side == "_L" else 0.0  # 空中雙腿略併攏
				thigh.rotation = lerp_angle(thigh.rotation, -0.8, 0.1)
			elif is_running:
				target_rot = (cycle * small_step_amplitude) + inner_offset  # 小幅度來回擺動

			thigh.rotation = lerp_angle(thigh.rotation, target_rot, 0.25)  # 平滑插值到目標角度

			# -----------------------------
			# 🦶 小腿（慣性擺盪優化）
			# -----------------------------

			var calf = thigh.get_node_or_null("Calf" + side)  # 取得小腿節點
			if calf:

				if is_running and parent.is_on_floor():  # 只在跑步時啟用

					# 🔧 ===== 少女可調參數 =====
					var max_bend = 1.5        # 小腿最大彎曲幅度 (略微調降避免抽動)
					var bend_speed = 0.12     # 小腿反應速度 (調低使擺盪更柔和)
					var swing_extension = 0.2  # 往前踢時的伸展慣性
					# 🔧 ========================

					var calf_target = 0.0  # 小腿目標角度

					# -------------------------------------------------
					# 🎯 邏輯：利用 cycle_cos 判斷大腿是在「後擺中」還是「前擺中」
					# 少女感核心：大腿在後方回彈瞬間 (cycle > 0 且 cos 變負) 彎曲最高
					# -------------------------------------------------
					
					if cycle > 0: # 大腿處於後半圈 (向後擺動或準備回收)
						# 只有在大腿往回動時 (cycle_cos < 0)，才根據位置增加彎曲
						if cycle_cos < -0.0:
							# 這是從後方收回來的過程，彎曲度隨 cycle 增加
							calf_target = cycle * max_bend 
						else:
							# 這是往後踩的過程，保持自然微彎
							calf_target = cycle * 1.0
					else: # 大腿處於前半圈 (往前踢出)
						# 往前踢時，利用 cycle_cos 產生一個平滑的伸展動作
						calf_target = abs(cycle) * -swing_extension 

					calf.rotation = lerp_angle(
						calf.rotation,
						calf_target,
						bend_speed
					)  # 平滑過渡小腿角度
				
				elif not parent.is_on_floor():
					# 空中收腿（OL跳躍）
					calf.rotation = lerp_angle(calf.rotation, 1.8, 0.25)
					
				else:
					# 非跑步或空中狀態，小腿回歸初始旋轉
					calf.rotation = lerp_angle(calf.rotation, 0.0, 0.15)	
	# =========================================================
	# ARMS (保持少女小跑步版)
	# =========================================================
	if torso_node:
		for side in ["_L", "_R"]:
			var arm = torso_node.get_node_or_null("Arm" + side)
			if not arm: continue

			var side_mul: float = 1.0 if side == "_L" else -1.0
			var target_rot = initial_arm_rotations.get(side, 0.0)
			var target_pos = initial_arm_positions.get(side, Vector2.ZERO)

			if is_running and parent.is_on_floor():
				var swing = sin(t * run_freq)
				var twist = sin(t * run_freq + PI * 0.5)

				var base_open = -0.1 * side_mul
				var swing_rot = swing * 0.1 * side_mul
				var arm_target = base_open + swing_rot
				arm.rotation = lerp_angle(arm.rotation, arm_target, 0.35)

				var shoulder_offset = swing * 1.5 * side_mul
				arm.position.x = lerp(arm.position.x, target_pos.x + shoulder_offset, 0.2)

				var forearm = arm.get_node_or_null("Forearm" + side)
				if forearm:
					var forearm_rot = 0.4 * side_mul + swing * -0.2 * side_mul
					forearm.rotation = lerp_angle(forearm.rotation, forearm_rot, 0.1)

					var twist_factor = clamp(twist * side_mul, -1.0, 1.0)
					forearm.scale.x = 1.0 - twist_factor * 0.05
					forearm.scale.y = 1.0 + abs(twist_factor) * 0.02

					var base_f_pos = initial_forearm_positions.get(side, Vector2.ZERO)
					var shift_x = -twist_factor * 1.0
					var shift_y = abs(twist_factor) * 2.5
					forearm.position = base_f_pos + Vector2(shift_x, shift_y)
					forearm.skew = twist_factor * 0.4
					arm.rotation += twist_factor * 0.05
			
			elif not parent.is_on_floor():
				arm.rotation = lerp_angle(arm.rotation, 0.3, 0.15)
				arm.position.y = lerp(arm.position.y, target_pos.y - 2 , 0.1)
				arm.position.x = lerp(arm.position.x, target_pos.x + 1 , 0.1)
				var forearm = arm.get_node_or_null("Forearm" + side)
				if forearm:
					forearm.rotation = lerp_angle(forearm.rotation, -0.6, 0.1)
					forearm.skew = lerp(forearm.skew, 0.3, 0.1)
					forearm.scale = lerp(forearm.scale, Vector2.ONE, 0.1)
					forearm.position = lerp(forearm.position, initial_forearm_positions.get(side, Vector2.ZERO), 0.1)
			
			else:
				arm.rotation = lerp_angle(arm.rotation, target_rot, 0.15)
				arm.position = lerp(arm.position, target_pos, 0.1)
				var forearm = arm.get_node_or_null("Forearm" + side)
				if forearm:
					forearm.rotation = lerp_angle(forearm.rotation, 0.0, 0.1)
					forearm.skew = lerp(forearm.skew, 0.0, 0.1)
					forearm.scale = lerp(forearm.scale, Vector2.ONE, 0.1)
					forearm.position = lerp(forearm.position, initial_forearm_positions.get(side, Vector2.ZERO), 0.1)
