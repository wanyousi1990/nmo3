extends Control
## 主選單用的女主分層立繪：
## BODY 下含 TORSO / BREAST / HEAD / PUSSY，所有部位可依破關狀態切換 NotCleared/Cleared。
## 呼吸動畫採「TORSO 主呼吸 + BREAST 延遲柔性追隨」，保留 PUSSY 瞬間縮放脈衝。

# --- 節點（場景預設名稱可改，請對應 Inspector）---
@export_group("節點")
@export var path_visual_root: NodePath = NodePath("VisualAnchor/VisualRoot") # 女主立繪根節點
@export var path_body_uncleared: NodePath = NodePath("VisualAnchor/VisualRoot/BODY/NotCleared") # 身體未破關圖層
@export var path_body_cleared: NodePath = NodePath("VisualAnchor/VisualRoot/BODY/Cleared") # 身體已破關圖層
@export var path_torso: NodePath = NodePath("VisualAnchor/VisualRoot/BODY/TORSO") # 上身節點（主呼吸）
@export var path_breast: NodePath = NodePath("VisualAnchor/VisualRoot/BODY/TORSO/BREAST") # 胸部節點（柔性追隨）
@export var path_pussy: NodePath = NodePath("VisualAnchor/VisualRoot/BODY/PUSSY") # 下體節點（脈衝縮放）
@export var path_head_uncleared: NodePath = NodePath("VisualAnchor/VisualRoot/BODY/HEAD/NotCleared") # 頭部未破關圖層
@export var path_head_cleared: NodePath = NodePath("VisualAnchor/VisualRoot/BODY/HEAD/Cleared") # 頭部已破關圖層
@export var path_breast_uncleared: NodePath = NodePath("VisualAnchor/VisualRoot/BODY/TORSO/BREAST/NotCleared") # 胸部未破關圖層
@export var path_breast_cleared: NodePath = NodePath("VisualAnchor/VisualRoot/BODY/TORSO/BREAST/Cleared") # 胸部已破關圖層
@export var path_pussy_uncleared: NodePath = NodePath("VisualAnchor/VisualRoot/BODY/PUSSY/NotCleared") # 下體未破關圖層
@export var path_pussy_cleared: NodePath = NodePath("VisualAnchor/VisualRoot/BODY/PUSSY/Cleared") # 下體已破關圖層

# --- 版面 ---
@export_group("版面")
@export var visual_scale: float = 1.0 # 整體立繪縮放倍率
@export var visual_pixel_offset: Vector2 = Vector2.ZERO # 整體立繪位置偏移

# --- 呼吸：上身（主呼吸）---
@export_group("呼吸動畫－上身")
@export_range(0.0, 8.0, 0.05) var torso_vertical_amplitude_px: float = 1.2 # 上身上下起伏幅度（像素）
@export_range(0.0, 5.0, 0.05) var torso_lateral_amplitude_px: float = 0.4 # 上身左右擺動幅度（像素）
@export_range(0.0, 8.0, 0.05) var torso_rotation_amplitude_deg: float = 1.0 # 上身旋轉幅度（度）
@export_range(0.0, 6.29, 0.01) var torso_phase_offset_rad: float = 0.15 # 上身呼吸相位偏移（弧度）

# --- 呼吸：胸部（柔性追隨）---
@export_group("呼吸動畫－胸部")
@export_range(0.4, 12.0, 0.05) var breath_period_sec: float = 2.8 # 呼吸一個完整週期的秒數（未破關）
@export_range(0.0, 24.0, 0.25) var breast_vertical_amplitude_px: float = 1.6 # 胸部上下位移幅度（像素）
@export_range(0.0, 24.0, 0.25) var breast_lateral_amplitude_px: float = 0.7 # 胸部左右位移幅度（像素）
@export_range(0.0, 12.0, 0.05) var breast_rotation_amplitude_deg: float = 1.2 # 胸部旋轉幅度（度）
@export_range(0.0, 0.08, 0.001) var breast_scale_y_amplitude: float = 0.028 # 胸部Y軸縮放幅度
@export_range(0.0, 0.08, 0.001) var breast_scale_x_compensate: float = 0.016 # 胸部X軸反向補償
@export_range(0.0, 12.0, 0.05) var breast_secondary_jiggle_freq: float = 2.8 # 次級晃動頻率倍率
@export_range(0.0, 6.0, 0.05) var breast_secondary_jiggle_amp_px: float = 0.4 # 次級晃動位移幅度（像素）
@export_range(0.0, 120.0, 0.5) var breast_follow_stiffness: float = 28.0 # 胸部追隨剛性（越大越跟手）
@export_range(0.0, 30.0, 0.1) var breast_follow_damping: float = 7.8 # 胸部追隨阻尼（越大越不晃）
@export_range(0.0, 6.29, 0.01) var breath_phase_offset_rad: float = 0.0 # 胸部呼吸相位偏移（弧度）

# --- 呼吸參數（破關 CLEAR：更色更軟、更明顯 PUSSY）---
@export_group("呼吸參數－CLEAR")
@export_range(0.0, 8.0, 0.05) var torso_vertical_amplitude_px_cleared: float = 1.35 # 上身上下起伏（破關）
@export_range(0.0, 5.0, 0.05) var torso_lateral_amplitude_px_cleared: float = 0.55 # 上身左右擺動（破關）
@export_range(0.0, 8.0, 0.05) var torso_rotation_amplitude_deg_cleared: float = 1.2 # 上身旋轉幅度（度）（破關）
@export_range(0.0, 6.29, 0.01) var torso_phase_offset_rad_cleared: float = 0.22 # 上身呼吸相位偏移（弧度）（破關）

@export_range(0.4, 12.0, 0.05) var breath_period_sec_cleared: float = 2.8 # 呼吸一個完整週期的秒數（破關）
@export_range(0.0, 24.0, 0.25) var breast_vertical_amplitude_px_cleared: float = 2.25 # 胸部上下位移幅度（像素）（破關）
@export_range(0.0, 24.0, 0.25) var breast_lateral_amplitude_px_cleared: float = 0.95 # 胸部左右位移幅度（像素）（破關）
@export_range(0.0, 12.0, 0.05) var breast_rotation_amplitude_deg_cleared: float = 1.4 # 胸部旋轉幅度（度）（破關）
@export_range(0.0, 0.08, 0.001) var breast_scale_y_amplitude_cleared: float = 0.034 # 胸部Y軸縮放幅度（破關）
@export_range(0.0, 0.08, 0.001) var breast_scale_x_compensate_cleared: float = 0.02 # 胸部X軸反向補償（破關）
@export_range(0.0, 12.0, 0.05) var breast_secondary_jiggle_freq_cleared: float = 2.3 # 次級晃動頻率倍率（破關）
@export_range(0.0, 6.0, 0.05) var breast_secondary_jiggle_amp_px_cleared: float = 0.55 # 次級晃動位移幅度（像素）（破關）
@export_range(0.0, 120.0, 0.5) var breast_follow_stiffness_cleared: float = 20.0 # 胸部追隨剛性（越大越跟手；破關更軟）
@export_range(0.0, 30.0, 0.1) var breast_follow_damping_cleared: float = 6.8 # 胸部追隨阻尼（破關更柔）
@export_range(0.0, 6.29, 0.01) var breath_phase_offset_rad_cleared: float = 0.1 # 胸部呼吸相位偏移（弧度）（破關）

@export_range(1, 8, 1) var pussy_pulse_every_n_breaths_cleared: int = 1 # 破關：每幾個呼吸週期觸發一次下體脈衝
@export_range(1.0, 1.5, 0.01) var pussy_pulse_scale_mult_cleared: float = 1.18 # 破關：下體脈衝放大倍率（更明顯）
@export_range(0.0, 0.3, 0.005) var pussy_pulse_hold_sec_cleared: float = 0.14 # 破關：下體脈衝峰值停留秒數
@export_range(0.0, 0.25, 0.005) var pussy_pulse_release_sec_cleared: float = 0.22 # 破關：下體脈衝回復秒數

# --- 呼吸：下體（瞬間縮放脈衝）---
@export_group("呼吸動畫－下體")
@export_range(1, 8, 1) var pussy_pulse_every_n_breaths: int = 1 # 每幾個呼吸週期觸發一次下體脈衝
@export_range(1.0, 1.5, 0.01) var pussy_pulse_scale_mult: float = 1.08 # 下體脈衝放大倍率
@export_range(0.0, 0.3, 0.005) var pussy_pulse_hold_sec: float = 0.04 # 下體脈衝峰值停留秒數
@export_range(0.0, 0.25, 0.005) var pussy_pulse_release_sec: float = 0.06 # 下體脈衝回復秒數

# --- 除錯 ---
@export_group("除錯")
@export var print_layer_refresh: bool = false # 是否輸出破關切圖除錯訊息

var _visual_root: Node2D
var _spr_body_u: CanvasItem
var _spr_body_c: CanvasItem
var _torso_root: Node2D
var _breast_root: Node2D
var _pussy_root: Node2D
var _spr_head_u: CanvasItem
var _spr_head_c: CanvasItem
var _spr_breast_u: CanvasItem
var _spr_breast_c: CanvasItem
var _spr_pussy_u: CanvasItem
var _spr_pussy_c: CanvasItem

var _torso_base_position: Vector2
var _torso_base_rotation: float
var _breast_base_position: Vector2
var _breast_base_scale: Vector2
var _breast_base_rotation: float
var _breast_follow_position: Vector2
var _breast_follow_velocity: Vector2
var _pussy_base_scale: Vector2

var _breath_phase: float = 0.0
var _breaths_completed: int = 0

enum _PussyPulsePhase { IDLE, HOLD, RELEASE }
var _pussy_pulse_state: _PussyPulsePhase = _PussyPulsePhase.IDLE
var _pussy_pulse_timer: float = 0.0
var _last_game_cleared_shown: bool = false
var _pussy_pulse_scale_mult_active: float = 1.0
var _pussy_pulse_release_sec_active: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root = get_node_or_null(path_visual_root) as Node2D
	_spr_body_u = get_node_or_null(path_body_uncleared) as CanvasItem
	_spr_body_c = get_node_or_null(path_body_cleared) as CanvasItem
	_torso_root = get_node_or_null(path_torso) as Node2D
	_breast_root = get_node_or_null(path_breast) as Node2D
	_pussy_root = get_node_or_null(path_pussy) as Node2D
	_spr_head_u = get_node_or_null(path_head_uncleared) as CanvasItem
	_spr_head_c = get_node_or_null(path_head_cleared) as CanvasItem
	_spr_breast_u = get_node_or_null(path_breast_uncleared) as CanvasItem
	_spr_breast_c = get_node_or_null(path_breast_cleared) as CanvasItem
	_spr_pussy_u = get_node_or_null(path_pussy_uncleared) as CanvasItem
	_spr_pussy_c = get_node_or_null(path_pussy_cleared) as CanvasItem
	if _torso_root:
		_torso_base_position = _torso_root.position
		_torso_base_rotation = _torso_root.rotation
	if _breast_root:
		_breast_base_position = _breast_root.position
		_breast_base_scale = _breast_root.scale
		_breast_base_rotation = _breast_root.rotation
		_breast_follow_position = _breast_root.position
		_breast_follow_velocity = Vector2.ZERO
	if _pussy_root:
		_pussy_base_scale = _pussy_root.scale
	_last_game_cleared_shown = GlobalState.game_cleared
	_apply_layout_baseline()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_refresh_layers_from_global_state()


func _process(delta: float) -> void:
	var gc := GlobalState.game_cleared
	if gc != _last_game_cleared_shown:
		_last_game_cleared_shown = gc
		_refresh_layers_from_global_state()
	if not _visual_root or not _torso_root or not _breast_root or not _pussy_root:
		return
	var cleared := gc

	# --- 根據未破關/破關選擇參數 ---
	var active_breath_period_sec: float = breath_period_sec_cleared if cleared else breath_period_sec
	var active_torso_phase_offset_rad: float = torso_phase_offset_rad_cleared if cleared else torso_phase_offset_rad
	var active_torso_vertical_amplitude_px: float = torso_vertical_amplitude_px_cleared if cleared else torso_vertical_amplitude_px
	var active_torso_lateral_amplitude_px: float = torso_lateral_amplitude_px_cleared if cleared else torso_lateral_amplitude_px
	var active_torso_rotation_amplitude_deg: float = torso_rotation_amplitude_deg_cleared if cleared else torso_rotation_amplitude_deg

	var active_breath_phase_offset_rad: float = breath_phase_offset_rad_cleared if cleared else breath_phase_offset_rad
	var active_breast_vertical_amplitude_px: float = breast_vertical_amplitude_px_cleared if cleared else breast_vertical_amplitude_px
	var active_breast_lateral_amplitude_px: float = breast_lateral_amplitude_px_cleared if cleared else breast_lateral_amplitude_px
	var active_breast_rotation_amplitude_deg: float = breast_rotation_amplitude_deg_cleared if cleared else breast_rotation_amplitude_deg
	var active_breast_scale_y_amplitude: float = breast_scale_y_amplitude_cleared if cleared else breast_scale_y_amplitude
	var active_breast_scale_x_compensate: float = breast_scale_x_compensate_cleared if cleared else breast_scale_x_compensate
	var active_breast_secondary_jiggle_freq: float = breast_secondary_jiggle_freq_cleared if cleared else breast_secondary_jiggle_freq
	var active_breast_secondary_jiggle_amp_px: float = breast_secondary_jiggle_amp_px_cleared if cleared else breast_secondary_jiggle_amp_px
	var active_breast_follow_stiffness: float = breast_follow_stiffness_cleared if cleared else breast_follow_stiffness
	var active_breast_follow_damping: float = breast_follow_damping_cleared if cleared else breast_follow_damping

	var active_pussy_every_n_breaths: int = pussy_pulse_every_n_breaths_cleared if cleared else pussy_pulse_every_n_breaths

	if active_breath_period_sec <= 0.001:
		return
	var prev_phase: float = _breath_phase
	_breath_phase += delta * TAU / active_breath_period_sec
	var torso_s: float = sin(_breath_phase + active_torso_phase_offset_rad)
	var torso_c: float = cos(_breath_phase + active_torso_phase_offset_rad)
	_torso_root.position = _torso_base_position + Vector2(torso_c * active_torso_lateral_amplitude_px, torso_s * active_torso_vertical_amplitude_px)
	_torso_root.rotation = _torso_base_rotation + deg_to_rad(torso_s * active_torso_rotation_amplitude_deg)

	var s: float = sin(_breath_phase + active_breath_phase_offset_rad)
	var c: float = cos(_breath_phase + active_breath_phase_offset_rad)
	var jiggle: float = sin((_breath_phase + active_breath_phase_offset_rad) * active_breast_secondary_jiggle_freq)
	var target_breast_pos := _breast_base_position + Vector2(
		c * active_breast_lateral_amplitude_px,
		s * active_breast_vertical_amplitude_px + jiggle * active_breast_secondary_jiggle_amp_px
	)
	var acc := (target_breast_pos - _breast_follow_position) * active_breast_follow_stiffness - _breast_follow_velocity * active_breast_follow_damping
	_breast_follow_velocity += acc * delta
	_breast_follow_position += _breast_follow_velocity * delta
	_breast_root.position = _breast_follow_position
	_breast_root.rotation = _breast_base_rotation + deg_to_rad(c * active_breast_rotation_amplitude_deg + jiggle * active_breast_rotation_amplitude_deg * 0.35)
	var sy: float = 1.0 + s * active_breast_scale_y_amplitude + jiggle * active_breast_scale_y_amplitude * 0.35
	var sx: float = 1.0 - s * active_breast_scale_x_compensate
	_breast_root.scale = Vector2(_breast_base_scale.x * sx, _breast_base_scale.y * sy)

	var prev_i: int = int(floor(prev_phase / TAU))
	var new_i: int = int(floor(_breath_phase / TAU))
	if new_i > prev_i:
		_breaths_completed += 1
		if _breaths_completed >= active_pussy_every_n_breaths:
			_breaths_completed = 0
			_start_pussy_pulse()
	_step_pussy_pulse(delta)


func _apply_layout_baseline() -> void:
	if _visual_root:
		_visual_root.scale = Vector2(visual_scale, visual_scale)
		_visual_root.position = visual_pixel_offset


func _refresh_layers_from_global_state() -> void:
	var cleared: bool = GlobalState.game_cleared
	if _spr_body_u:
		_spr_body_u.visible = not cleared
	if _spr_body_c:
		_spr_body_c.visible = cleared
	if _spr_head_u:
		_spr_head_u.visible = not cleared
	if _spr_head_c:
		_spr_head_c.visible = cleared
	if _spr_breast_u:
		_spr_breast_u.visible = not cleared
	if _spr_breast_c:
		_spr_breast_c.visible = cleared
	if _spr_pussy_u:
		_spr_pussy_u.visible = not cleared
	if _spr_pussy_c:
		_spr_pussy_c.visible = cleared
	if print_layer_refresh:
		print("[HeroinMenuVisual] 圖層 cleared=", cleared)


func refresh_from_global_state() -> void:
	_last_game_cleared_shown = GlobalState.game_cleared
	_refresh_layers_from_global_state()


func _start_pussy_pulse() -> void:
	var cleared := GlobalState.game_cleared
	var scale_mult_active := pussy_pulse_scale_mult_cleared if cleared else pussy_pulse_scale_mult
	var hold_sec_active := pussy_pulse_hold_sec_cleared if cleared else pussy_pulse_hold_sec
	var release_sec_active := pussy_pulse_release_sec_cleared if cleared else pussy_pulse_release_sec

	_pussy_pulse_scale_mult_active = scale_mult_active
	_pussy_pulse_release_sec_active = release_sec_active

	if scale_mult_active <= 1.0001 or not _pussy_root:
		return
	_pussy_pulse_state = _PussyPulsePhase.HOLD
	_pussy_pulse_timer = hold_sec_active
	_pussy_root.scale = _pussy_base_scale * scale_mult_active


func _step_pussy_pulse(delta: float) -> void:
	if not _pussy_root:
		return
	match _pussy_pulse_state:
		_PussyPulsePhase.IDLE:
			pass
		_PussyPulsePhase.HOLD:
			_pussy_pulse_timer -= delta
			if _pussy_pulse_timer <= 0.0:
				if _pussy_pulse_release_sec_active <= 0.0001:
					_pussy_root.scale = _pussy_base_scale
					_pussy_pulse_state = _PussyPulsePhase.IDLE
				else:
					_pussy_pulse_state = _PussyPulsePhase.RELEASE
					_pussy_pulse_timer = _pussy_pulse_release_sec_active
		_PussyPulsePhase.RELEASE:
			_pussy_pulse_timer -= delta
			var t: float = clampf(1.0 - (_pussy_pulse_timer / maxf(_pussy_pulse_release_sec_active, 0.0001)), 0.0, 1.0)
			var k: float = lerpf(_pussy_pulse_scale_mult_active, 1.0, t)
			_pussy_root.scale = _pussy_base_scale * k
			if _pussy_pulse_timer <= 0.0:
				_pussy_root.scale = _pussy_base_scale
				_pussy_pulse_state = _PussyPulsePhase.IDLE
