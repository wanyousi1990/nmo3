extends Node2D

class_name OL_H_Controller

const DEFAULT_POSE_CONFIGS: Array[PoseConfigResource] = [
	preload("res://TRES/pose_config_h_pose_01.tres"),
	preload("res://TRES/pose_config_h_pose_02.tres"),
	preload("res://TRES/pose_config_h_pose_03.tres"),
	preload("res://TRES/pose_config_h_pose_04.tres"),
	preload("res://TRES/pose_config_h_pose_05.tres"),
	preload("res://TRES/pose_config_h_pose_06.tres"),
	preload("res://TRES/pose_config_tits_fcuk_01.tres"),
	preload("res://TRES/pose_config_tits_fuck_02.tres"),
	preload("res://TRES/pose_config_tits_fuck_03.tres"),
]

# ==============================================================================
# OL_H_Controller (V36 - Multi-Semen-Moan & Audio Integration)
# 職責：負責 H 狀態切換、物理衝量注入、音效觸發、動態 FX 尋找。
# 修正重點：
# 1. 高潮 Pitch 強化：射精階段自動調高語音音高，模擬生理緊縮感。
# 2. 隨機音效截取：支援從單一長音檔中隨機播放特定秒數片段，並防止連續重複。
# 3. 完整保留原有之所有詳細物理備註與邏輯架構。
# ==============================================================================

signal h_mode_finished # 當自動進程完全結束時送出
signal h_mode_toggled(active: bool) # 手動切換 H 模式時通知父節點
signal h_sequence_stage_changed(stage: int) # 抽插階段變更（0慢／1中／2快／3射精…；Lewd Torso 用）

@export_group("Escape Settings")
@export var escape_arrow: Node2D
## 掙脫進度橫條（置於角色與 Escape_Arrow 之間）；子節點需含 Track、Fill 兩條 Line2D
@export var escape_progress_bar_root: Node2D
@export var escape_threshold: int = 15         # 掙脫需要的左右交替總次數 (可在編輯器設定)
@export var escape_bar_half_width: float = 36.0   # 橫條半長（像素）
## 若為 true：未鎖定時每幀用下方 Track／Fill 色覆寫子節點 Line2D（子節點 Inspector 調色會無效）。
## 若為 false：沿用場景裡 Escape_ProgressBar／Track、Fill 上設定的 default_color（可直接選 Fill 調色）。
@export var escape_bar_use_export_colors: bool = false
@export var escape_bar_track_color: Color = Color(0.22, 0.22, 0.26, 0.92)
@export var escape_bar_fill_color: Color = Color(0.35, 0.95, 0.62, 1)
## Horny 滿鎖掙脫時強制使用下列顏色（與 escape_bar_fill_color 無關，請改這兩個才看得到變化）
@export var escape_bar_locked_track_color: Color = Color(0.42, 0.14, 0.14, 0.92)
@export var escape_bar_locked_fill_color: Color = Color(0.55, 0.12, 0.12, 0.88)
var _escape_count: int = 0
var _last_escape_key: String = ""             # 紀錄上一次按下的鍵 ("left" or "right")
var _escape_track_line: Line2D
var _escape_fill_line: Line2D
var _escape_track_scene_color: Color = Color.WHITE
var _escape_fill_scene_color: Color = Color.WHITE

@export_group("Audio Settings (音效設定)")
@export var sfx_player_water: AudioStreamPlayer    # 插入水聲播放器
@export var sfx_player_semen: AudioStreamPlayer    # 射精音播放器
@export var sfx_player_voice: AudioStreamPlayer    # 呻吟聲播放器
@export var voice_segments: Array[Vector2] = [     # 一般插入時的呻吟片段設定: X=開始時間(秒), Y=持續長度(秒)
	Vector2(0.5, 0.8), 
	Vector2(1.5, 1.0), 
	Vector2(3.0, 1.2)
]
@export var voice_semen_segments: Array[Vector2] = [ # 射精時的長呻吟片段陣列 (隨機抽取)
	Vector2(5.0, 2.5),
	Vector2(8.0, 3.0),
	Vector2(12.0, 2.8)
]

@export_group("FX Settings (粒子特效設定)")
var fx_particles: GPUParticles2D      # 現在會根據 Pose 自動抓取，不再僅限於單一節點
@export var fx_amount_normal: int = 8         # 一般射精粒子量
@export var fx_amount_burst: int = 25         # 第一下與最後一下的粒子量

@export_group("H_FX 液體高光")
## 是否把噴出的粒子加上像素高光（關閉則維持原本實心色塊）
@export var fx_liquid_enabled: bool = true
## 0=原本方顆粒+高光（較像素）  1=像素圓（硬邊圓，不是平滑球）
@export_enum("像素方塊", "像素圓") var fx_pixel_shape: int = 0
## 一顆液滴切成幾格（越小越顆粒）
@export_range(4, 16, 1) var fx_pixel_grid: int = 8
## 高光顏色（偏白）
@export var fx_highlight_color: Color = Color(1.0, 1.0, 0.97, 1.0)
## 高光混色強度
@export_range(0.0, 1.0, 0.01) var fx_highlight_strength: float = 1.0
## 高光範圍（格子座標，越大亮點越多格）
@export_range(0.05, 0.9, 0.01) var fx_highlight_size: float = 0.32
## 高光位置（負 X／負 Y 為左上）
@export var fx_highlight_offset: Vector2 = Vector2(-0.28, -0.32)
## 外圈格子暗度（做出一點厚度，仍是整格變色）
@export_range(0.2, 1.0, 0.01) var fx_volume_dark: float = 0.72
## 從哪裡開始變暗（越大只有最外圈暗）
@export_range(0.3, 1.0, 0.01) var fx_shade_band: float = 0.68
## 液滴最小／最大縮放（建議是格子的倍數，例如 8～12）
@export_range(1.0, 40.0, 0.5) var fx_scale_min: float = 8.0
@export_range(1.0, 40.0, 0.5) var fx_scale_max: float = 12.0
## 噴出時把附近 PointLight2D 的顏色混進液滴（Compatibility 無法在此 shader 寫 light()）
@export var fx_receive_lights: bool = true
## 燈光混色強度
@export_range(0.0, 2.0, 0.01) var fx_light_mix: float = 1.0

const _FX_LIQUID_SHADER: Shader = preload("res://h_fx_liquid.gdshader")
var _fx_liquid_mat: ShaderMaterial
## 記住該 H_FX 原本的粒子色，避免每次噴出疊乘燈光
var _fx_saved_color_for: GPUParticles2D
var _fx_saved_color: Color = Color(0.960784, 0.941176, 0.823529, 1)

@export_group("Gallery / Debug Keys（H 中）")
## H 中按 Q 增減 Horny（負值＝減少）
@export var gallery_horny_step: float = 10.0
## H 中按 W 增減 Semen（負值＝減少；實際按鍵套用 -step）
@export var gallery_semen_step: float = 10.0

@export_group("Current Pose Physics (當前姿勢動態參數)")
@export var current_impact_dir_torso: Vector2 = Vector2(40, -20)  # 軀幹受力方向
@export var current_impact_dir_pelvis: Vector2 = Vector2(30, -30) # 骨盆受力方向
@export var current_b_impact_mult: float = 1.0  # 胸部力道倍率
@export var current_h_mult: float = 1.0         # 臀部力道倍率
@export var current_breast_motion_type: String = "impact" # impact: 衝擊彈簧 / press: 乳交擠壓

var current_trigger_vec: Vector2 = Vector2(0, -50) # 當前預設衝擊向量
var current_semen_range: Vector2i = Vector2i(3, 5) # 隨機射精次數範圍

@export_group("Breast Physics (胸部物理)")
@export var b_impact_strength: float = 2.0      # 基礎衝擊強度
@export var b_stiffness_modes: Array[float] = [200.0, 220.0]          # 彈簧硬度 (越高回彈越快)
@export var b_damping_modes: Array[float] = [5.2, 7]              # 阻尼 (越高停止越快)
@export var b_max_offset_modes: Array[float] = [7.0, 5.0]          # 最大位移限制
@export var b_rotation_factor: float = 1.0      # 位移對旋轉的影響係數
@export var b_squash_factor: float = 0.02       # 擠壓伸縮係數
@export var b_ripple_freq: float = 25.0         # 水波紋震盪頻率
@export var b_ripple_size: float = 0.12         # 水波紋振幅
@export var b_ripple_decay: float = 0.3         # 能量衰減率
@export var b_async_factor_modes: Array[float] = [0.6, 0.3]         # 左右異步隨機因子 (避免機械化對稱)
@export var b_expand_factor: float = 0.0        # 胸部受衝擊向外擠開係數（由姿勢設定覆蓋）
@export var b_press_freq_stages: Array[float] = [6.0, 9.5, 13.0] # 乳交頻率(慢/中/快)
@export var b_press_depth: float = 0.09         # 乳交往下壓時的上下壓扁程度
@export var b_press_rebound: float = 0.07       # 乳交水平回彈膨脹
@export var b_press_y_follow: float = 5.0       # 乳交壓縮時向下位移
@export var b_press_phase_shift: float = 0.4    # 左右胸擠壓相位差
@export var b_press_smooth: float = 14.0        # 乳交形變平滑速度
@export var b_press_inward_px: float = 2.0      # 乳交時左右胸往中線夾擊位移
@export var b_press_inward_scale: float = 0.08  # 乳交時水平壓縮比例
@export var b_press_vertical_stretch: float = 0.12 # 乳交時垂直拉長比例
@export var b_press_contact_delay: float = 0.12     # 每次衝擊後，延遲多久才開始乳交形變
@export var b_press_attack_ratio: float = 0.35      # 一次乳交循環中，擠壓段比例
@export var b_press_release_ratio: float = 0.65     # 一次乳交循環中，回彈段比例

@export_group("Butt Physics (臀部物理)")
@export var h_impact_strength: float = 1.5      # 臀部衝擊強度
@export var h_stiffness_modes: Array[float] = [250.0, 250.0]          # 臀部硬度
@export var h_damping_modes: Array[float] = [8.0, 9.0]              # 臀部阻尼
@export var h_max_offset_modes: Array[float] = [2.5, 2.0]          # 臀部位移限制
@export var h_rotation_factor: float = -15.0      # 臀部旋轉係數
@export var h_squash_factor: float = 0.02      # 臀部擠壓係數
@export var h_ripple_freq: float = 30.0         
@export var h_ripple_size: float = 0.12         
@export var h_ripple_decay: float = 0.3         
@export var h_expand_factor: float = 0.8        # 向兩側擠開的位移係數

@export_group("Body Physics (軀幹與骨盆物理)")
@export var torso_stiffness: float = 120.0       # 軀幹回彈硬度
@export var torso_damping: float = 12.0         # 軀幹阻尼
@export var torso_inertia: float = 1.0          # 軀幹慣性權重
@export var pelvis_stiffness: float = 200.0     # 骨盆硬度
@export var pelvis_damping: float = 8.0         # 骨盆阻尼

@export_group("Nodes Reference")
@export var normal_visual: Node2D      # 一般走路/跑步的視覺節點
@export var pose_root: Node2D          # 當前 H 姿勢的根節點 (e.g. H_Pose_01)
@export var animation_player: AnimationPlayer 
@export var h_animation_name: String = "H_Pose_01_Loop" 
@export var pose_config_resources: Array[PoseConfigResource] = DEFAULT_POSE_CONFIGS

@export_group("Cold Start Warmup (冷啟動預熱)")
@export var warmup_on_ready: bool = true ## 進場景後預熱 H 貼圖／Shader／粒子／音效，消除第一次進 H 卡頓
@export var warmup_process_frames: int = 2 ## 預熱時等待幾幀讓 GPU 完成編譯／上傳
@export var warmup_force_draw: bool = true ## 預熱時強制 RenderingServer.force_draw（Debug 較有效）

# --- 內部物理狀態變數 ---
var nude_breasts: Array[Node2D] = []      # 紀錄當前姿勢下的胸部節點
var breast_vels: Array[Vector2] = []      # 胸部當前速度
var breast_offsets: Array[Vector2] = []   # 胸部當前偏移
var butt_vels: Array[Vector2] = []        # 臀部速度
var butt_offsets: Array[Vector2] = []     # 臀部偏移

var torso_node: Node2D
var pelvis_node: Node2D
var torso_initial_pos: Vector2
var pelvis_initial_pos: Vector2
var torso_initial_rot: float = 0.0
var pelvis_initial_rot: float = 0.0
var torso_initial_scale: Vector2 = Vector2.ONE
var pelvis_initial_scale: Vector2 = Vector2.ONE
var torso_vel: Vector2 = Vector2.ZERO
var torso_offset: Vector2 = Vector2.ZERO
var pelvis_vel: Vector2 = Vector2.ZERO
var pelvis_offset: Vector2 = Vector2.ZERO

var initial_breast_pos: Array[Vector2] = [] # 原始相對座標
var initial_breast_rot: Array[float] = [] # 姿勢場景原始旋轉（勿強制歸零）
var initial_breast_scale: Array[Vector2] = []
var initial_butt_pos: Array[Vector2] = []   # 原始相對座標
var initial_butt_rot: Array[float] = []
var initial_butt_scale: Array[Vector2] = []

var b_ripple_energy: float = 0.0
var h_ripple_energy: float = 0.0
var time_passed: float = 0.0
var breast_press_time: float = 0.0 # 保留: 乳交觸發後經過時間
var breast_press_state: int = 0    # 0: idle, 1: delay, 2: attack, 3: release
var breast_press_state_time: float = 0.0
var breast_press_amount: float = 0.0 # 0~1，給 _apply_physics_to_nodes 使用
var breast_press_inward_amount: float = 0.0 # 0~1，夾擊專用時間相位（延後於下壓）
var breast_press_cycle_progress: float = 0.0 # 0~1，下壓循環相位
var breast_press_inward_progress: float = 0.0 # 0~1，夾擊循環相位

var auto_impact_interval: float = 0.0     # 自動衝擊間隔 (0 = 關閉)
var auto_impact_timer: float = 0.0        # 自動衝擊計時器

var is_sequence_active: bool = false
var sequence_stage: int = 0               # 0:1.2s, 1:0.6s, 2:0.3s, 3:Final
var sequence_count: int = 0               # 當前階段衝擊計數
var sequence_target_count: int = 0        # 當前階段目標次數

var is_h_active: bool = false             
var current_pose_index: int = 0
var pose_list: Array = [] # 儲存字典中的鍵名 (H_Pose_01, H_Pose_02...)
var pose_config_map: Dictionary = {}

var _last_voice_idx: int = -1 # 用於記錄上一次播放的索引，防止重複
var _last_semen_idx: int = -1 # 用於記錄上一次播放的索引，防止重複
var _current_voice_task_id: int = 0 # 新增一個內部變數，用來追蹤當前的播放任務 ID
var _h_warmup_done: bool = false
var _h_warmup_running: bool = false
## 各姿勢軟體「抽出靜止」快照（避免中途退出後把半截姿勢當成新初始）
var _softbody_rest_by_pose: Dictionary = {}

func _ready():
	_rebuild_pose_config_map()
	_auto_setup_nodes()
	_cache_escape_progress_lines()
	self.visible = false
	if normal_visual: normal_visual.visible = true
	if warmup_on_ready:
		call_deferred("_run_h_cold_start_warmup")

func _process(delta: float):
	if _h_warmup_running:
		return
	if is_h_active:
		time_passed += delta
		if current_breast_motion_type == "press":
			_update_breast_press_state(delta)
		if auto_impact_interval > 0.0:
			auto_impact_timer += delta
			if auto_impact_timer >= auto_impact_interval:
				trigger_impact(current_trigger_vec) 
				auto_impact_timer = 0.0        
				if is_sequence_active: _handle_sequence_logic()
		_update_physics_logic(delta)
		_apply_physics_to_nodes()
		
	if sequence_stage >= 3:
		escape_arrow.modulate.a = 0
	else:
		escape_arrow.modulate.a = 1
	_update_escape_progress_ui()

# ==============================================================================
# 音效處理邏輯 (Audio Handling)
# ==============================================================================

func _play_random_moan():
	if not sfx_player_voice or voice_segments.is_empty(): return
	
	var new_idx: int = 0
	if voice_segments.size() > 1:
		new_idx = randi() % voice_segments.size()
		# 如果抽到跟上次一樣的，就再抽一次 (簡單的防重複)
		while new_idx == _last_voice_idx:
			new_idx = randi() % voice_segments.size()
	
	_last_voice_idx = new_idx
	var seg = voice_segments[new_idx]
	_play_voice_segment(seg.x, seg.y)

func _play_semen_moan():
	if not sfx_player_voice or voice_semen_segments.is_empty(): return
	
	var new_idx: int = 0
	if voice_semen_segments.size() > 1:
		new_idx = randi() % voice_semen_segments.size()
		# 射精音同樣防止連續重複
		while new_idx == _last_semen_idx:
			new_idx = randi() % voice_semen_segments.size()
			
	_last_semen_idx = new_idx
	var seg = voice_semen_segments[new_idx]
	_play_voice_segment(seg.x, seg.y)

func _play_voice_segment(start_time: float, duration: float):
	# 每次呼叫時增加 ID，確保這是一個新的播放任務
	_current_voice_task_id += 1
	var my_task_id = _current_voice_task_id
	
	# 動態計算 Pitch: 如果處於射精階段 (Stage 3)，提高 Pitch 以增加快感表現
	if is_sequence_active and sequence_stage == 3:
		sfx_player_voice.pitch_scale = randf_range(1.05, 1.15) # 尖銳、高亢的高潮聲
	else:
		sfx_player_voice.pitch_scale = randf_range(0.95, 1.05) # 一般頻率
	
	# 如果是 0.3s 的極速階段或射精中，稍微調大音量增加瘋狂感
	if auto_impact_interval > 0 and auto_impact_interval <= 0.4:
		sfx_player_voice.volume_db = 1.5
	else:
		sfx_player_voice.volume_db = 0.0
		
	sfx_player_voice.stop()
	sfx_player_voice.play(start_time)
	
	# 使用 SceneTreeTimer 在持續時間結束時停止播放，並透過 ID 驗證防止誤殺
	get_tree().create_timer(duration).timeout.connect(func():
		if _current_voice_task_id == my_task_id and sfx_player_voice.playing:
			sfx_player_voice.stop()
	)

func _play_water_sfx():
	if sfx_player_water: sfx_player_water.play()

func _play_semen_sfx():
	if sfx_player_semen: sfx_player_semen.play()

# ==============================================================================
# 服裝同步邏輯
# ==============================================================================

func set_appearance_mode(mode: int):
	GlobalState.current_mode = mode as GlobalState.AppearanceMode
	_update_pose_visual_layers()

func _update_pose_visual_layers():
	if not pose_root: return
	_set_visibility_by_suffix(pose_root, "_NAKED", GlobalState.current_mode == GlobalState.AppearanceMode.NAKED)
	_set_visibility_by_suffix(pose_root, "_CLOTHED", GlobalState.current_mode == GlobalState.AppearanceMode.CLOTHED)

func _set_visibility_by_suffix(root: Node, suffix: String, p_visible: bool):
	if root.name.ends_with(suffix):
		if root is CanvasItem: root.visible = p_visible
	for child in root.get_children(): _set_visibility_by_suffix(child, suffix, p_visible)

# ==============================================================================
# 掙脫機制 (Escape Mechanic)
# ==============================================================================

func _handle_escape_input():
	if sequence_stage >= 3:
		return
	if HSystem.is_escape_locked_by_horny():
		return
	
	var pressed_left = Input.is_action_just_pressed("ui_left")
	var pressed_right = Input.is_action_just_pressed("ui_right")
	if pressed_left or pressed_right:
		var current_key = "left" if pressed_left else "right"
		
		# 檢查是否為「交替按下」(例如：左 -> 右 -> 左)
		if current_key != _last_escape_key:
			_escape_count += 1
			_last_escape_key = current_key
			
			# 給予視覺反饋：強迫軀幹抖動一下
			torso_vel += Vector2(randf_range(-20, 20), randf_range(-10, 10))
			
			var need_presses: int = HSystem.get_escape_presses_required(escape_threshold)
			if _escape_count >= need_presses: force_stop_h_mode()
		else:
			# 如果沒按對（重複按同一邊），暫時不計數
			pass

func force_stop_h_mode():
	_escape_count = 0
	_last_escape_key = ""
	print("[Escape] 掙脫達標，強制結束 H 模式。")
	exit_h_mode()
	h_mode_finished.emit()

func _cache_escape_progress_lines() -> void:
	if escape_progress_bar_root == null:
		return
	_escape_track_line = escape_progress_bar_root.get_node_or_null("Track") as Line2D
	_escape_fill_line = escape_progress_bar_root.get_node_or_null("Fill") as Line2D
	if _escape_track_line:
		_escape_track_scene_color = _escape_track_line.default_color
	if _escape_fill_line:
		_escape_fill_scene_color = _escape_fill_line.default_color

func _update_escape_progress_ui() -> void:
	if escape_progress_bar_root == null:
		return
	var show_ui: bool = is_h_active and sequence_stage < 3
	escape_progress_bar_root.visible = show_ui
	if not show_ui:
		return
	if _escape_track_line == null or _escape_fill_line == null:
		return
	var locked: bool = HSystem.is_escape_locked_by_horny()
	var need: int = HSystem.get_escape_presses_required(escape_threshold)
	var ratio: float = 0.0
	if not locked and need < 900000:
		ratio = clampf(float(_escape_count) / float(maxi(need, 1)), 0.0, 1.0)
	var hw: float = escape_bar_half_width
	_escape_track_line.points = PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0)])
	var fill_end: float = -hw + 2.0 * hw * ratio
	if ratio <= 0.001:
		fill_end = -hw + 0.12
	_escape_fill_line.points = PackedVector2Array([Vector2(-hw, 0), Vector2(fill_end, 0)])
	if locked:
		_escape_track_line.default_color = escape_bar_locked_track_color
		_escape_fill_line.default_color = escape_bar_locked_fill_color
	elif escape_bar_use_export_colors:
		_escape_track_line.default_color = escape_bar_track_color
		_escape_fill_line.default_color = escape_bar_fill_color
	else:
		_escape_track_line.default_color = _escape_track_scene_color
		_escape_fill_line.default_color = _escape_fill_scene_color

# ==============================================================================
# 核心切換邏輯
# ==============================================================================

# 支援接收字串 pose_tag 並自動搜尋節點
func switch_pose(pose_data, anim_override: String = ""):
	var target_node: Node2D = null
	var pose_key: String = ""

	# 1. 判斷傳入的是節點還是字串 Tag
	if pose_data is Node2D:
		target_node = pose_data; pose_key = target_node.name
	elif pose_data is String:
		pose_key = pose_data; target_node = get_node_or_null(pose_key)
	
	if not target_node:
		push_warning("警告：嘗試切換到不存在的 Pose: " + str(pose_key))
		return
	
	# 切換姿勢時，停止所有自動衝擊與進程模式 (確保畫廊導覽一致性)
	_stop_sequence()
	auto_impact_interval = 0.0; auto_impact_timer = 0.0
	
	if is_h_active:
		_reset_breast_press_state()
		_reset_physics_offsets()
		
	# 隱藏所有姿勢
	for p_name in pose_list:
		var p_node = get_node_or_null(p_name)
		if p_node: p_node.visible = false
	
	pose_root = target_node
	
	# 2. 從 Resource 讀取設定並更新參數
	if pose_config_map.has(pose_key):
		var cfg: PoseConfigResource = pose_config_map[pose_key] as PoseConfigResource
		_apply_pose_config(cfg, anim_override)
		print("已切換姿勢: ", pose_key, " | 射精次數: ", current_semen_range)
	else:
		push_warning("警告：找不到 Pose 設定 Resource: " + pose_key)
	
	# 3. 顯示新姿勢節點並重啟物理追蹤，同時自動尋找該 Pose 下的 FX 節點
	if pose_root:
		# 先靜音／歸零，再顯示，避免進場當幀噴粒子或殘留半截姿勢
		fx_particles = _find_node_by_name_recursive(pose_root, "H_FX") as GPUParticles2D
		_silence_h_fx(fx_particles)
		_reset_partner_thrust_under(pose_root)
		_stop_pose_animation()
		pose_root.visible = is_h_active
		if fx_particles:
			_apply_fx_liquid_look()
			fx_particles.visible = false
		_update_pose_visual_layers()
		if is_h_active and pose_root.is_inside_tree():
			_prepare_softbody_for_h_session()
			_play_pose_animation_from_start()

func _input(event):
	if is_h_active: _handle_escape_input() 
	if not GlobalState.enable_H_keys: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H: toggle_h_mode()
		if is_h_active:
			if event.keycode == KEY_Q:
				_debug_adjust_horny(-gallery_horny_step)
			elif event.keycode == KEY_W:
				_debug_adjust_semen(-gallery_semen_step)
			elif event.keycode == KEY_T: trigger_impact(current_trigger_vec) 
			elif event.keycode == KEY_1: _stop_sequence(); _toggle_auto_impact(1.2)
			elif event.keycode == KEY_2: _stop_sequence(); _toggle_auto_impact(0.6)
			elif event.keycode == KEY_3: _stop_sequence(); _toggle_auto_impact(0.3)
			elif event.keycode == KEY_4:
				if is_sequence_active and sequence_stage == 3: _stop_sequence()
				else: _start_final_sequence()
			elif event.keycode == KEY_A:
				if is_sequence_active and sequence_stage < 3: _stop_sequence()
				else: _start_sequence_mode()
			elif event.keycode == KEY_UP or event.keycode == KEY_DOWN:
				var step = -1 if event.keycode == KEY_UP else 1
				current_pose_index = (current_pose_index + step) % pose_list.size()
				if current_pose_index < 0: current_pose_index = pose_list.size() - 1
				switch_pose(pose_list[current_pose_index])
		else:
			# 如果沒開 H 模式 but 按了按鍵，給個提示
			if event.keycode in [KEY_T, KEY_1, KEY_2, KEY_3, KEY_4, KEY_A, KEY_UP, KEY_DOWN, KEY_Q, KEY_W]:
				print("請先開啟 H 模式")


func _debug_adjust_horny(delta: float) -> void:
	var before: float = HSystem.horny
	HSystem.set_horny(before + delta)
	print("[OL_H] Horny ", before, " → ", HSystem.horny, " (Δ", delta, ")")


func _debug_adjust_semen(delta: float) -> void:
	var before: float = HSystem.semen
	HSystem.set_semen(before + delta)
	print("[OL_H] Semen ", before, " → ", HSystem.semen, " (Δ", delta, ")")

# ==============================================================================
# 自動進程與粒子觸發 (FX & Sequence Logic)
# ==============================================================================

func _start_sequence_mode():
	is_sequence_active = true
	_set_sequence_stage(0)
	sequence_count = 0; sequence_target_count = 6
	auto_impact_interval = 1.2; auto_impact_timer = 0.15
	print("[Sequence] 啟動：階段 1 (1.2s x 6)")

func _start_final_sequence():
	is_sequence_active = true
	_set_sequence_stage(3)
	sequence_count = 0
	sequence_target_count = randi_range(current_semen_range.x, current_semen_range.y)
	auto_impact_interval = 0.8; auto_impact_timer = -0.8 + 0.15
	print("[Sequence] 直接啟動：最終射精階段。先蓄力... (隨機次數: ", sequence_target_count, ")")

func _stop_sequence():
	if is_sequence_active:
		is_sequence_active = false
		auto_impact_interval = 0.0
		print("[Sequence] 已手動停止")

## 統一設定抽插階段並通知 Lewd Torso 等監聽者
func _set_sequence_stage(stage: int) -> void:
	if sequence_stage == stage:
		return
	sequence_stage = stage
	h_sequence_stage_changed.emit(sequence_stage)

func _handle_sequence_logic():
	sequence_count += 1
	if sequence_stage == 3: _trigger_fx_burst(sequence_count, sequence_target_count)
	if is_sequence_active and sequence_stage == 3 and sequence_count < sequence_target_count:
		auto_impact_interval = randf_range(0.6, 1.0)
	
	if sequence_count >= sequence_target_count:
		sequence_count = 0
		_set_sequence_stage(sequence_stage + 1)
		match sequence_stage:
			1: sequence_target_count = 12; auto_impact_interval = 0.6; print("[Sequence] 階段 2 (0.6s x 12)")
			2: sequence_target_count = 12; auto_impact_interval = 0.3; print("[Sequence] 階段 3 (0.3s x 12)")
			3: 
				sequence_target_count = randi_range(current_semen_range.x, current_semen_range.y)
				auto_impact_interval = 0.8; auto_impact_timer = -0.8
				print("[Sequence] 最終階段：射精模擬。先蓄力... (隨機次數: ", sequence_target_count, ")")
			4: 
				auto_impact_interval = 0; is_sequence_active = false
				print("[Sequence] 進程完成，停留餘韻...")
				await get_tree().create_timer(1.8).timeout
				exit_h_mode(); h_mode_finished.emit()

func _apply_fx_liquid_look() -> void:
	if fx_particles == null:
		return
	if not fx_liquid_enabled:
		if fx_particles.material == _fx_liquid_mat:
			fx_particles.material = null
		print("H_FX 液體高光: 關閉")
		return
	if _fx_liquid_mat == null:
		_fx_liquid_mat = ShaderMaterial.new()
		_fx_liquid_mat.shader = _FX_LIQUID_SHADER
	_fx_liquid_mat.set_shader_parameter("shape_mode", fx_pixel_shape)
	_fx_liquid_mat.set_shader_parameter("pixel_grid", float(fx_pixel_grid))
	_fx_liquid_mat.set_shader_parameter("highlight_offset", fx_highlight_offset)
	_fx_liquid_mat.set_shader_parameter("highlight_color", fx_highlight_color)
	_fx_liquid_mat.set_shader_parameter("highlight_size", fx_highlight_size)
	_fx_liquid_mat.set_shader_parameter("highlight_strength", fx_highlight_strength)
	_fx_liquid_mat.set_shader_parameter("volume_dark", fx_volume_dark)
	_fx_liquid_mat.set_shader_parameter("shade_band", fx_shade_band)
	fx_particles.material = _fx_liquid_mat
	fx_particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx_particles.light_mask = 1
	var pm := fx_particles.process_material as ParticleProcessMaterial
	if pm:
		pm.scale_min = fx_scale_min
		pm.scale_max = maxf(fx_scale_min, fx_scale_max)
		if _fx_saved_color_for != fx_particles:
			_fx_saved_color_for = fx_particles
			_fx_saved_color = pm.color
		var tint: Color = _sample_world_lights(fx_particles.global_position)
		pm.color = Color(
			_fx_saved_color.r * tint.r,
			_fx_saved_color.g * tint.g,
			_fx_saved_color.b * tint.b,
			_fx_saved_color.a
		)
	print("H_FX 像素高光已套用 shape=", fx_pixel_shape, " grid=", fx_pixel_grid, " scale=", fx_scale_min, "~", fx_scale_max)


func _sample_world_lights(world_pos: Vector2) -> Color:
	if not fx_receive_lights:
		return Color.WHITE
	var scene: Node = get_tree().current_scene if get_tree() else null
	if scene == null:
		return Color.WHITE
	var lights: Array[PointLight2D] = []
	_collect_point_lights(scene, lights)
	var add_r: float = 0.0
	var add_g: float = 0.0
	var add_b: float = 0.0
	for light in lights:
		if light == null or not light.enabled or not light.visible:
			continue
		var lp: Vector2 = light.global_position + light.offset
		var tex_w: float = 256.0
		if light.texture:
			tex_w = float(light.texture.get_width())
		var radius: float = tex_w * 0.5 * light.texture_scale * maxf(absf(light.global_scale.x), absf(light.global_scale.y))
		if radius < 1.0:
			continue
		var att: float = clampf(1.0 - world_pos.distance_to(lp) / radius, 0.0, 1.0)
		att *= att * light.energy * fx_light_mix
		add_r += light.color.r * att
		add_g += light.color.g * att
		add_b += light.color.b * att
	return Color(
		clampf(1.0 + add_r * 0.65, 0.4, 2.2),
		clampf(1.0 + add_g * 0.65, 0.4, 2.2),
		clampf(1.0 + add_b * 0.65, 0.4, 2.2),
		1.0
	)


func _collect_point_lights(n: Node, out_lights: Array[PointLight2D]) -> void:
	if n is PointLight2D:
		out_lights.append(n as PointLight2D)
	for c in n.get_children():
		_collect_point_lights(c, out_lights)


func _trigger_fx_burst(current: int, total: int):
	if not fx_particles: return
	_apply_fx_liquid_look()
	# 觸發射精專屬音效與隨機長呻吟
	_play_semen_sfx()
	_play_semen_moan()
	
	var amount = fx_amount_normal
	if current == 1 or current == total: amount = fx_amount_burst
	# 僅在真正噴出時顯示；平常隱藏可避免半截粒子殘留被看見
	fx_particles.visible = true
	fx_particles.amount = amount
	fx_particles.restart()
	fx_particles.emitting = true

func _toggle_auto_impact(interval: float):
	if auto_impact_interval == interval:
		auto_impact_interval = 0.0
		print("自動衝擊停止")
	else:
		auto_impact_interval = interval
		auto_impact_timer = 0.15
		print("自動衝擊啟動：每 ", interval, " 秒一次")

func toggle_h_mode():
	if _h_warmup_running:
		await _await_h_warmup_finished()
	if is_h_active:
		exit_h_mode()
	else:
		await enter_h_mode("")

## 正式進入 H（單一入口）：先清狀態再開畫面，避免 FX／半截姿勢殘留
func enter_h_mode(pose_tag: String = "", anim_override: String = "") -> void:
	if _h_warmup_running:
		await _await_h_warmup_finished()
	if is_h_active:
		if pose_tag != "":
			switch_pose(pose_tag, anim_override)
		_hard_reset_active_pose_motion()
		_start_sequence_mode()
		return

	_hard_reset_all_h_visual_state()
	_auto_setup_nodes()
	if pose_tag != "":
		# 仍未啟用：只選定姿勢與參數，不顯示、不開 sequence
		_bind_pose_while_inactive(pose_tag, anim_override)
	elif pose_root == null:
		pose_root = get_node_or_null("H_Pose_01")

	is_h_active = true
	visible = true
	auto_impact_interval = 0.0
	auto_impact_timer = 0.0
	is_sequence_active = false
	_set_sequence_stage(0)
	_escape_count = 0
	_reset_breast_press_state()
	if normal_visual:
		normal_visual.visible = false

	if pose_root:
		fx_particles = _find_node_by_name_recursive(pose_root, "H_FX") as GPUParticles2D
		_silence_h_fx(fx_particles)
		_reset_partner_thrust_under(pose_root)
		_stop_pose_animation()
		pose_root.visible = true
		if fx_particles:
			_apply_fx_liquid_look()
			fx_particles.visible = false # 進場不顯示；等射精 burst 再亮
		_update_pose_visual_layers()
		_prepare_softbody_for_h_session()
		_play_pose_animation_from_start()
		_start_sequence_mode()

	h_mode_toggled.emit(true)
	HSystem.set_h_mode_active(true)
	print("[OL_H] enter_h_mode pose=", pose_root.name if pose_root else "null")

## 結束 H：先歸零再隱藏
func exit_h_mode() -> void:
	if not is_h_active:
		return
	is_h_active = false
	auto_impact_interval = 0.0
	auto_impact_timer = 0.0
	is_sequence_active = false
	_set_sequence_stage(0)
	_escape_count = 0
	_reset_breast_press_state()
	_hard_reset_all_h_visual_state()
	if pose_root:
		pose_root.visible = false
	visible = false
	if normal_visual:
		normal_visual.visible = true
	h_mode_toggled.emit(false)
	HSystem.set_h_mode_active(false)
	print("[OL_H] exit_h_mode 已清乾淨")

func _bind_pose_while_inactive(pose_tag: String, anim_override: String = "") -> void:
	var target_node: Node2D = get_node_or_null(pose_tag) as Node2D
	if target_node == null:
		push_warning("警告：嘗試切換到不存在的 Pose: " + pose_tag)
		return
	for p_name in pose_list:
		var p_node = get_node_or_null(p_name)
		if p_node:
			p_node.visible = false
	pose_root = target_node
	if pose_config_map.has(pose_tag):
		_apply_pose_config(pose_config_map[pose_tag] as PoseConfigResource, anim_override)
		print("已綁定姿勢(未啟用): ", pose_tag)
	fx_particles = _find_node_by_name_recursive(pose_root, "H_FX") as GPUParticles2D
	_silence_h_fx(fx_particles)
	_reset_partner_thrust_under(pose_root)
	_stop_pose_animation()

# ==============================================================================
# 物理計算與衝擊觸發
# ==============================================================================

func trigger_impact(impact_dir: Vector2):
	# 每次衝擊觸發水聲與隨機呻吟
	_play_water_sfx()
	_play_random_moan()
	if current_breast_motion_type == "press":
		_start_breast_press_cycle()
	
	var mode = GlobalState.current_mode
	var b_async_factor = b_async_factor_modes[mode]
	if current_breast_motion_type != "press":
		for i in range(breast_vels.size()):
			var sync_break = randf_range(1.0 - b_async_factor, 1.0 + b_async_factor)
			breast_vels[i] += impact_dir * b_impact_strength * sync_break * current_b_impact_mult
	for i in range(butt_vels.size()):
		butt_vels[i] += impact_dir * h_impact_strength * current_h_mult
	torso_vel += current_impact_dir_torso * torso_inertia
	pelvis_vel += current_impact_dir_pelvis
	b_ripple_energy = clamp(b_ripple_energy + 0.8, 0.0, 2.0)
	h_ripple_energy = clamp(h_ripple_energy + 0.8, 0.0, 2.0)

	var thrust_stage: int = 0
	if is_sequence_active:
		thrust_stage = clampi(sequence_stage, 0, 3)
	HSystem.apply_thrust_for_sequence_stage(thrust_stage)

func _initialize_physics_data():
	if not is_inside_tree() or (pose_root and not pose_root.is_inside_tree()): return
	nude_breasts.clear(); initial_breast_pos.clear(); initial_breast_rot.clear(); initial_breast_scale.clear()
	breast_vels.clear(); breast_offsets.clear()
	initial_butt_pos.clear(); initial_butt_rot.clear(); initial_butt_scale.clear()
	butt_vels.clear(); butt_offsets.clear()
	if pose_root:
		var bl = _find_node_by_name_recursive(pose_root, "Breast_L"); var br = _find_node_by_name_recursive(pose_root, "Breast_R")
		if bl: nude_breasts.append(bl); if br: nude_breasts.append(br)
		for b in nude_breasts:
			initial_breast_pos.append(b.position)
			initial_breast_rot.append(b.rotation)
			initial_breast_scale.append(b.scale)
			breast_vels.append(Vector2.ZERO)
			breast_offsets.append(Vector2.ZERO)
		pelvis_node = _find_node_by_name_recursive(pose_root, "Pelvis"); torso_node = _find_node_by_name_recursive(pose_root, "Torso")
		if pelvis_node:
			pelvis_initial_pos = pelvis_node.position
			pelvis_initial_rot = pelvis_node.rotation
			pelvis_initial_scale = pelvis_node.scale
		if torso_node:
			torso_initial_pos = torso_node.position
			torso_initial_rot = torso_node.rotation
			torso_initial_scale = torso_node.scale
		var hl = _find_node_by_name_recursive(pose_root, "Hip_L"); var hr = _find_node_by_name_recursive(pose_root, "Hip_R")
		var hips = []; if hl: hips.append(hl); if hr: hips.append(hr)
		for h in hips:
			initial_butt_pos.append(h.position)
			initial_butt_rot.append(h.rotation)
			initial_butt_scale.append(h.scale)
			butt_vels.append(Vector2.ZERO)
			butt_offsets.append(Vector2.ZERO)

func _update_physics_logic(delta: float):
	var mode = GlobalState.current_mode
	var b_stiffness = b_stiffness_modes[mode]; var b_damping = b_damping_modes[mode]; var b_max_offset = b_max_offset_modes[mode]
	var h_stiffness = h_stiffness_modes[mode]; var h_damping = h_damping_modes[mode]; var h_max_offset = h_max_offset_modes[mode]
	
	# 胸部物理：抽插使用衝擊彈簧；乳交(TITS_FUCK_01／02／03)使用週期擠壓回彈
	if current_breast_motion_type == "press":
		for i in range(breast_offsets.size()):
			var press_wave = 0.0
			if breast_press_state >= 2:
				var phase_shift = b_press_phase_shift if i == 0 else -b_press_phase_shift
				var phase_down = fposmod(breast_press_cycle_progress + phase_shift, 1.0)
				press_wave = _pulse01(phase_down)
			var target_offset = Vector2(0.0, press_wave * b_press_depth * b_max_offset)
			breast_offsets[i] = breast_offsets[i].lerp(target_offset, clamp(delta * b_press_smooth, 0.0, 1.0))
			breast_vels[i] = Vector2.ZERO
	else:
		for i in range(breast_vels.size()):
			breast_vels[i] += (-b_stiffness * breast_offsets[i] - b_damping * breast_vels[i]) * delta
			breast_offsets[i] += breast_vels[i] * delta
			breast_offsets[i] = breast_offsets[i].limit_length(b_max_offset)
	
	# 臀部物理
	for i in range(butt_vels.size()):
		butt_vels[i] += (-h_stiffness * butt_offsets[i] - h_damping * butt_vels[i]) * delta
		butt_offsets[i] += butt_vels[i] * delta
		butt_offsets[i] = butt_offsets[i].limit_length(h_max_offset)
	
	# 軀幹與骨盆物理
	pelvis_vel += (-pelvis_stiffness * pelvis_offset - pelvis_damping * pelvis_vel) * delta
	pelvis_offset += pelvis_vel * delta
	torso_vel += (-torso_stiffness * torso_offset - torso_damping * torso_vel) * delta
	torso_offset += torso_vel * delta
	
	# 能量衰減
	b_ripple_energy = lerp(b_ripple_energy, 0.0, delta * b_damping * b_ripple_decay)
	h_ripple_energy = lerp(h_ripple_energy, 0.0, delta * h_damping * h_ripple_decay)

func _apply_physics_to_nodes():
	if pelvis_node: pelvis_node.position = pelvis_initial_pos + pelvis_offset
	if torso_node: torso_node.position = torso_initial_pos + torso_offset
	for i in range(nude_breasts.size()):
		var node = nude_breasts[i]; var offset = breast_offsets[i]
		var side_dir = 1.0 if i == 0 else -1.0
		var ripple = sin((time_passed + i*0.5) * b_ripple_freq) * b_ripple_energy * b_ripple_size
		var base_rot_deg: float = rad_to_deg(initial_breast_rot[i]) if i < initial_breast_rot.size() else 0.0
		if current_breast_motion_type == "press":
			var down_t = breast_press_amount
			var inward_t = breast_press_inward_amount
			if breast_press_state >= 2:
				var phase_shift = b_press_phase_shift if i == 0 else -b_press_phase_shift
				var phase_down = fposmod(breast_press_cycle_progress + phase_shift, 1.0)
				var phase_inward = fposmod(breast_press_inward_progress + phase_shift, 1.0)
				down_t = _pulse01(phase_down)
				inward_t = _pulse01(phase_inward)
			var inward_x = -side_dir * inward_t * b_press_inward_px
			node.position = initial_breast_pos[i] + Vector2(inward_x, offset.y * b_press_y_follow * down_t)
			node.rotation_degrees = base_rot_deg
			var sx = 1.0 + (down_t * b_press_rebound) - (inward_t * b_press_inward_scale)
			var sy = 1.0 - (down_t * b_press_depth) + (inward_t * b_press_vertical_stretch)
			var base_sc: Vector2 = initial_breast_scale[i] if i < initial_breast_scale.size() else Vector2.ONE
			node.scale = Vector2(base_sc.x * sx, base_sc.y * sy)
		else:
			node.position = initial_breast_pos[i] + offset + Vector2(offset.y * b_expand_factor * side_dir, 0)
			# 保留姿勢場景的基礎旋轉，再疊加晃動
			node.rotation_degrees = base_rot_deg + (offset.x + offset.y * 0.2) * b_rotation_factor
			var squash = (-offset.y * b_squash_factor) + ripple
			var base_sc2: Vector2 = initial_breast_scale[i] if i < initial_breast_scale.size() else Vector2.ONE
			node.scale = Vector2(base_sc2.x * (1.0 + squash), base_sc2.y * (1.0 - squash))
	if pose_root:
		var hl = _find_node_by_name_recursive(pose_root, "Hip_L"); var hr = _find_node_by_name_recursive(pose_root, "Hip_R")
		var hips = [hl, hr]; for i in range(hips.size()):
			if hips[i] and i < initial_butt_pos.size():
				var node = hips[i]; var offset = butt_offsets[i]; var side_dir = 1.0 if i == 0 else -1.0
				var ripple = sin(time_passed * h_ripple_freq) * h_ripple_energy * h_ripple_size
				var base_hip_rot_deg: float = rad_to_deg(initial_butt_rot[i]) if i < initial_butt_rot.size() else 0.0
				node.position = initial_butt_pos[i] + offset + Vector2(offset.y * h_expand_factor * side_dir, 0)
				node.rotation_degrees = base_hip_rot_deg + (offset.x + offset.y * 0.2) * h_rotation_factor
				var squash = (-offset.y * h_squash_factor) + ripple # 修正: 統一使用肉感擠壓
				var base_hip_sc: Vector2 = initial_butt_scale[i] if i < initial_butt_scale.size() else Vector2.ONE
				node.scale = Vector2(base_hip_sc.x * (1.0 + squash), base_hip_sc.y * (1.0 - squash))

func _reset_physics_offsets():
	# 連同餘震能量一起清掉，否則下次進 H 胸／臀還會繼續晃
	b_ripple_energy = 0.0
	h_ripple_energy = 0.0
	torso_offset = Vector2.ZERO; torso_vel = Vector2.ZERO
	pelvis_offset = Vector2.ZERO; pelvis_vel = Vector2.ZERO
	for i in range(breast_offsets.size()): breast_offsets[i] = Vector2.ZERO; breast_vels[i] = Vector2.ZERO
	for i in range(butt_offsets.size()): butt_offsets[i] = Vector2.ZERO; butt_vels[i] = Vector2.ZERO
	_apply_physics_to_nodes()

func _reset_breast_press_state():
	breast_press_time = 0.0
	breast_press_state = 0
	breast_press_state_time = 0.0
	breast_press_amount = 0.0
	breast_press_inward_amount = 0.0
	breast_press_cycle_progress = 0.0
	breast_press_inward_progress = 0.0

func _start_breast_press_cycle():
	breast_press_time = 0.0
	breast_press_state_time = 0.0
	breast_press_state = 1
	breast_press_amount = 0.0
	breast_press_inward_amount = 0.0
	breast_press_cycle_progress = 0.0
	breast_press_inward_progress = 0.0

func _update_breast_press_state(delta: float):
	breast_press_time += delta
	breast_press_state_time += delta
	var cycle = max(0.08, 1.0 / _get_current_b_press_freq())
	var attack_dur = max(0.02, cycle * clamp(b_press_attack_ratio, 0.05, 0.95))
	var release_dur = max(0.02, cycle * clamp(b_press_release_ratio, 0.05, 0.95))
	var delay_dur = max(0.0, b_press_contact_delay)
	match breast_press_state:
		0:
			breast_press_amount = 0.0
			breast_press_inward_amount = 0.0
			breast_press_cycle_progress = 0.0
			breast_press_inward_progress = 0.0
		1:
			breast_press_amount = 0.0
			breast_press_inward_amount = 0.0
			breast_press_cycle_progress = 0.0
			breast_press_inward_progress = 0.0
			if breast_press_state_time >= delay_dur:
				breast_press_state = 2
				breast_press_state_time = 0.0
		2:
			var t = clamp(breast_press_state_time / attack_dur, 0.0, 1.0)
			var cycle_progress = t * 0.5
			breast_press_cycle_progress = cycle_progress
			breast_press_inward_progress = clamp((cycle_progress - 0.5) * 2.0, 0.0, 1.0)
			breast_press_amount = _pulse01(cycle_progress)
			breast_press_inward_amount = _pulse01(breast_press_inward_progress)
			if breast_press_state_time >= attack_dur:
				breast_press_state = 3
				breast_press_state_time = 0.0
				breast_press_amount = 1.0
		3:
			var t = clamp(breast_press_state_time / release_dur, 0.0, 1.0)
			var cycle_progress = 0.5 + (t * 0.5)
			breast_press_cycle_progress = cycle_progress
			breast_press_inward_progress = clamp((cycle_progress - 0.5) * 2.0, 0.0, 1.0)
			breast_press_amount = _pulse01(cycle_progress)
			breast_press_inward_amount = _pulse01(breast_press_inward_progress)
			if breast_press_state_time >= release_dur:
				breast_press_state = 0
				breast_press_state_time = 0.0
				breast_press_amount = 0.0
				breast_press_inward_amount = 0.0
				breast_press_cycle_progress = 0.0
				breast_press_inward_progress = 0.0

func _pulse01(p: float) -> float:
	var t = clamp(p, 0.0, 1.0)
	if t < 0.5:
		var up = t / 0.5
		return up * up * (3.0 - 2.0 * up)
	var down = (t - 0.5) / 0.5
	return 1.0 - (down * down * (3.0 - 2.0 * down))

func _find_node_by_name_recursive(root: Node, node_name: String) -> Node:
	if root.name == node_name: return root
	for i in range(root.get_child_count()):
		var found = _find_node_by_name_recursive(root.get_child(i), node_name)
		if found: return found
	return null

func _auto_setup_nodes():
	if not pose_root: pose_root = get_node_or_null("H_Pose_01")
	if not animation_player: animation_player = get_node_or_null("AnimationPlayer_H")
	if not normal_visual:
		var p = get_parent()
		if p:
			normal_visual = p.get_node_or_null("Normal_Visual")
			if normal_visual == null:
				normal_visual = p.find_child("Normal_Visual", true, false)

func _resolve_pose_animation_player() -> AnimationPlayer:
	# 各姿勢自己的 AnimationPlayer_H；Controller 上的 export 可能是空的
	if pose_root:
		var ap := pose_root.get_node_or_null("AnimationPlayer_H") as AnimationPlayer
		if ap:
			return ap
	return animation_player

func _play_pose_animation_from_start() -> void:
	var ap := _resolve_pose_animation_player()
	if ap == null:
		return
	animation_player = ap
	_reset_animation_player(ap)
	if h_animation_name != "" and ap.has_animation(h_animation_name):
		ap.play(h_animation_name)
		ap.seek(0.0, true)

func _stop_pose_animation() -> void:
	var ap := _resolve_pose_animation_player()
	if ap == null:
		return
	animation_player = ap
	_reset_animation_player(ap)

func _reset_animation_player(ap: AnimationPlayer) -> void:
	if ap == null:
		return
	# keep_state=false：停在開頭，不要保留半截姿勢
	ap.stop(false)
	if ap.has_animation(&"RESET"):
		ap.play(&"RESET")
		ap.seek(0.0, true)
		ap.advance(0.0)
		ap.stop(false)

## 靜音清除粒子：禁止在可見時 restart()（會重新發射）
## 半空中的粒子用 amount=0 重建緩衝 + 隱藏，避免中途退出再進還在噴
func _silence_h_fx(fx: GPUParticles2D) -> void:
	if fx == null or not is_instance_valid(fx):
		return
	fx.emitting = false
	fx.one_shot = true
	fx.visible = false
	var kept: int = maxi(fx.amount, 1)
	fx.amount = 0
	fx.amount = kept

func _silence_all_pose_fx() -> void:
	for pose in _collect_warmup_pose_roots():
		var fx := _find_node_by_name_recursive(pose, "H_FX") as GPUParticles2D
		_silence_h_fx(fx)
	_silence_h_fx(fx_particles)

## 掐斷胸／臀／骨盆軟體動能（速度、位移、餘震），並貼回靜止姿勢
func _kill_softbody_motion() -> void:
	b_ripple_energy = 0.0
	h_ripple_energy = 0.0
	_reset_breast_press_state()
	torso_vel = Vector2.ZERO
	torso_offset = Vector2.ZERO
	pelvis_vel = Vector2.ZERO
	pelvis_offset = Vector2.ZERO
	for i in range(breast_vels.size()):
		breast_vels[i] = Vector2.ZERO
		breast_offsets[i] = Vector2.ZERO
	for i in range(butt_vels.size()):
		butt_vels[i] = Vector2.ZERO
		butt_offsets[i] = Vector2.ZERO
	if pose_root != null and _softbody_rest_by_pose.has(String(pose_root.name)):
		_apply_softbody_snapshot(_softbody_rest_by_pose[String(pose_root.name)])
	elif not initial_breast_pos.is_empty() or pelvis_node != null or torso_node != null:
		_apply_physics_to_nodes()
	_snap_softbody_scales_and_rotations()

func _snap_softbody_scales_and_rotations() -> void:
	# 還原「姿勢場景原始旋轉／縮放」，禁止強制歸零（H_Pose_04 Pelvis≈1.72rad 會被掰成站立）
	for i in range(nude_breasts.size()):
		var n: Node2D = nude_breasts[i]
		if n == null:
			continue
		if i < initial_breast_pos.size():
			n.position = initial_breast_pos[i]
		if i < initial_breast_rot.size():
			n.rotation = initial_breast_rot[i]
		if i < initial_breast_scale.size():
			n.scale = initial_breast_scale[i]
	if pose_root:
		var hl := _find_node_by_name_recursive(pose_root, "Hip_L") as Node2D
		var hr := _find_node_by_name_recursive(pose_root, "Hip_R") as Node2D
		var hips: Array = [hl, hr]
		for i in range(hips.size()):
			if hips[i] == null:
				continue
			if i < initial_butt_pos.size():
				hips[i].position = initial_butt_pos[i]
			if i < initial_butt_rot.size():
				hips[i].rotation = initial_butt_rot[i]
			if i < initial_butt_scale.size():
				hips[i].scale = initial_butt_scale[i]
	if pelvis_node:
		pelvis_node.position = pelvis_initial_pos
		pelvis_node.rotation = pelvis_initial_rot
		pelvis_node.scale = pelvis_initial_scale
	if torso_node:
		torso_node.position = torso_initial_pos
		torso_node.rotation = torso_initial_rot
		torso_node.scale = torso_initial_scale

func _hard_reset_active_pose_motion() -> void:
	if pose_root == null:
		return
	_silence_h_fx(_find_node_by_name_recursive(pose_root, "H_FX") as GPUParticles2D)
	_reset_partner_thrust_under(pose_root)
	_stop_pose_animation()
	_prepare_softbody_for_h_session()
	_play_pose_animation_from_start()

func _hard_reset_all_h_visual_state() -> void:
	_silence_all_pose_fx()
	_reset_partner_thrust_under(self)
	for pose in _collect_warmup_pose_roots():
		var ap := pose.get_node_or_null("AnimationPlayer_H") as AnimationPlayer
		_reset_animation_player(ap)
		_reset_partner_thrust_under(pose)
	_kill_softbody_motion()

## 進 H 前：掐動能 → 貼靜止 → 重建 initial／零速度；靜止快照只記一次
func _prepare_softbody_for_h_session() -> void:
	b_ripple_energy = 0.0
	h_ripple_energy = 0.0
	_reset_breast_press_state()
	# 若快照曾被舊邏輯寫成 rot=0，進姿勢前先清掉，改從場景實際旋轉重建
	if pose_root != null:
		var key_chk := String(pose_root.name)
		if _softbody_rest_by_pose.has(key_chk):
			var old_snap: Dictionary = _softbody_rest_by_pose[key_chk]
			var pelvis_snap: Dictionary = old_snap.get("pelvis", {})
			var pelvis_n: Node2D = _find_node_by_name_recursive(pose_root, "Pelvis") as Node2D
			if pelvis_n and absf(float(pelvis_snap.get("rot", 0.0))) < 0.001 and absf(pelvis_n.rotation) > 0.2:
				_softbody_rest_by_pose.erase(key_chk)
				print("[OL_H] 丟棄錯誤的靜止快照（曾把姿勢旋轉歸零）: ", key_chk)
	if pose_root != null and _softbody_rest_by_pose.has(String(pose_root.name)):
		_apply_softbody_snapshot(_softbody_rest_by_pose[String(pose_root.name)])
	_initialize_physics_data()
	b_ripple_energy = 0.0
	h_ripple_energy = 0.0
	for i in range(breast_vels.size()):
		breast_vels[i] = Vector2.ZERO
		breast_offsets[i] = Vector2.ZERO
	for i in range(butt_vels.size()):
		butt_vels[i] = Vector2.ZERO
		butt_offsets[i] = Vector2.ZERO
	torso_vel = Vector2.ZERO
	torso_offset = Vector2.ZERO
	pelvis_vel = Vector2.ZERO
	pelvis_offset = Vector2.ZERO
	_apply_physics_to_nodes()
	_snap_softbody_scales_and_rotations()
	if pose_root != null:
		var key := String(pose_root.name)
		if not _softbody_rest_by_pose.has(key):
			_softbody_rest_by_pose[key] = _capture_softbody_snapshot()

func _capture_softbody_snapshot() -> Dictionary:
	var breasts: Array = []
	for i in range(nude_breasts.size()):
		var b: Node2D = nude_breasts[i]
		if b == null:
			continue
		var pos: Vector2 = initial_breast_pos[i] if i < initial_breast_pos.size() else b.position
		var rot: float = initial_breast_rot[i] if i < initial_breast_rot.size() else b.rotation
		var sc: Vector2 = initial_breast_scale[i] if i < initial_breast_scale.size() else b.scale
		breasts.append({"node": b, "pos": pos, "rot": rot, "scale": sc})
	var hips: Array = []
	if pose_root:
		var pair: Array = [
			_find_node_by_name_recursive(pose_root, "Hip_L"),
			_find_node_by_name_recursive(pose_root, "Hip_R")
		]
		for i in range(pair.size()):
			var h: Node2D = pair[i] as Node2D
			if h == null:
				continue
			var pos2: Vector2 = initial_butt_pos[i] if i < initial_butt_pos.size() else h.position
			var rot2: float = initial_butt_rot[i] if i < initial_butt_rot.size() else h.rotation
			var sc2: Vector2 = initial_butt_scale[i] if i < initial_butt_scale.size() else h.scale
			hips.append({"node": h, "pos": pos2, "rot": rot2, "scale": sc2})
	return {
		"pelvis": {
			"node": pelvis_node,
			"pos": pelvis_initial_pos if pelvis_node else Vector2.ZERO,
			"rot": pelvis_initial_rot,
			"scale": pelvis_initial_scale
		},
		"torso": {
			"node": torso_node,
			"pos": torso_initial_pos if torso_node else Vector2.ZERO,
			"rot": torso_initial_rot,
			"scale": torso_initial_scale
		},
		"breasts": breasts,
		"hips": hips,
	}

func _apply_softbody_snapshot(snap: Dictionary) -> void:
	for key in ["pelvis", "torso"]:
		if not snap.has(key):
			continue
		var d: Dictionary = snap[key]
		var n: Node2D = d.get("node") as Node2D
		if n and is_instance_valid(n):
			n.position = d.get("pos", n.position)
			n.rotation = float(d.get("rot", 0.0))
			n.scale = d.get("scale", Vector2.ONE)
	for arr_key in ["breasts", "hips"]:
		if not snap.has(arr_key):
			continue
		for d2 in snap[arr_key]:
			var n2: Node2D = d2.get("node") as Node2D
			if n2 and is_instance_valid(n2):
				n2.position = d2.get("pos", n2.position)
				n2.rotation = float(d2.get("rot", 0.0))
				n2.scale = d2.get("scale", Vector2.ONE)

func _reset_partner_thrust_under(root: Node) -> void:
	# 通知怪物 H 控制器瞬間歸零（中途退出後再進同一姿勢才不會延續半截）
	if root == null:
		return
	if root.has_method("reset_thrust_pose"):
		root.call("reset_thrust_pose")
	for c in root.get_children():
		_reset_partner_thrust_under(c)

func _await_h_warmup_finished() -> void:
	while _h_warmup_running and is_inside_tree():
		await get_tree().process_frame

## 供進 H 前呼叫：確保冷啟動預熱已結束，避免與顯示姿勢搶狀態
func ensure_h_warmup_finished() -> void:
	if _h_warmup_done:
		return
	# deferred 預熱可能尚未開跑
	if not _h_warmup_running and warmup_on_ready:
		await get_tree().process_frame
	await _await_h_warmup_finished()

## 離屏預熱：貼圖上 GPU、液體／馬賽克 Shader、粒子管線、音效解碼
func _run_h_cold_start_warmup() -> void:
	if _h_warmup_done or _h_warmup_running:
		return
	if not is_inside_tree():
		return
	_h_warmup_running = true
	print("[OL_H] 冷啟動預熱開始…")

	var saved_visible: bool = visible
	var saved_modulate: Color = modulate
	var saved_position: Vector2 = position
	var saved_pose_root: Node2D = pose_root
	var saved_fx: GPUParticles2D = fx_particles
	var visibility_restore: Array = [] # Dictionary: node, visible
	var warmed_fx: Array = [] # Dictionary: fx, amount

	# 離屏繪製（完全透明可能被跳過，故用遠處 + 不透明）
	position = Vector2(-20000, -20000)
	modulate = Color(1, 1, 1, 1)
	visible = true

	var poses: Array[Node2D] = _collect_warmup_pose_roots()
	for pose in poses:
		_record_canvas_visibility(pose, visibility_restore)
		pose.visible = true
		_force_show_canvas_tree(pose)
		_touch_textures_recursive(pose)
		var fx := _find_node_by_name_recursive(pose, "H_FX") as GPUParticles2D
		if fx:
			fx_particles = fx
			_apply_fx_liquid_look()
			# 預熱管線：短噴後立刻清乾淨，避免第一次正式進 H 還看得到殘粒
			var saved_amount: int = fx.amount
			fx.one_shot = true
			fx.amount = mini(4, maxi(1, saved_amount))
			fx.emitting = true
			fx.restart()
			warmed_fx.append({"fx": fx, "amount": saved_amount})

	_warmup_audio_silent()

	var frames: int = maxi(1, warmup_process_frames)
	for _i in frames:
		await get_tree().process_frame
		if warmup_force_draw:
			RenderingServer.force_draw(false)

	for entry in warmed_fx:
		var fx: GPUParticles2D = entry.get("fx") as GPUParticles2D
		if fx != null and is_instance_valid(fx):
			fx.amount = int(entry.get("amount", fx.amount))
			_silence_h_fx(fx)

	# 還原各節點原本可見性（含 NAKED／CLOTHED 等）
	for entry in visibility_restore:
		var n: CanvasItem = entry.get("node") as CanvasItem
		if n != null and is_instance_valid(n):
			n.visible = bool(entry.get("visible", false))

	# 還原可見性後再靜音一次：避免 H_FX 被還原成 visible 而露出預熱殘粒
	_silence_all_pose_fx()

	for pose in poses:
		if is_instance_valid(pose):
			pose.visible = false

	pose_root = saved_pose_root
	fx_particles = saved_fx
	position = saved_position
	modulate = saved_modulate
	visible = saved_visible
	if pose_root and is_h_active:
		pose_root.visible = true
		_update_pose_visual_layers()

	_h_warmup_done = true
	_h_warmup_running = false
	print("[OL_H] 冷啟動預熱完成（姿勢 ", poses.size(), " 個）")

func _collect_warmup_pose_roots() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for c in get_children():
		if not (c is Node2D):
			continue
		var n: String = String(c.name)
		if n.begins_with("H_Pose_") or n.begins_with("TITS_"):
			out.append(c as Node2D)
	return out

func _record_canvas_visibility(root: Node, out: Array) -> void:
	if root is CanvasItem:
		out.append({"node": root, "visible": (root as CanvasItem).visible})
	for c in root.get_children():
		_record_canvas_visibility(c, out)

func _force_show_canvas_tree(root: Node) -> void:
	if root is CanvasItem:
		(root as CanvasItem).visible = true
	for c in root.get_children():
		_force_show_canvas_tree(c)

func _touch_textures_recursive(root: Node) -> void:
	# 觸碰貼圖資源，促使解碼／上傳準備
	if root is Sprite2D:
		var spr := root as Sprite2D
		if spr.texture:
			spr.texture.get_size()
	elif root is TextureRect:
		var tr := root as TextureRect
		if tr.texture:
			tr.texture.get_size()
	if root is CanvasItem:
		var mat := (root as CanvasItem).material
		if mat is ShaderMaterial:
			var sm := mat as ShaderMaterial
			if sm.shader:
				sm.shader.get_rid()
	for c in root.get_children():
		_touch_textures_recursive(c)

func _warmup_audio_silent() -> void:
	# 靜音播極短一下，觸發解碼／混音器熱身；不走正式 play API 以免打亂 voice task
	for player in [sfx_player_water, sfx_player_semen, sfx_player_voice]:
		if player == null or player.stream == null:
			continue
		var old_db: float = player.volume_db
		var old_pitch: float = player.pitch_scale
		player.volume_db = -80.0
		player.pitch_scale = 1.0
		player.stop()
		player.play(0.0)
		player.stop()
		player.volume_db = old_db
		player.pitch_scale = old_pitch

func _rebuild_pose_config_map():
	pose_config_map.clear()
	for cfg in pose_config_resources:
		if cfg == null:
			continue
		var key := String(cfg.pose_name)
		if key == "":
			continue
		pose_config_map[key] = cfg
	pose_list = pose_config_map.keys()
	pose_list.sort()

func _apply_pose_config(cfg: PoseConfigResource, anim_override: String = ""):
	current_impact_dir_torso = cfg.torso_dir
	current_impact_dir_pelvis = cfg.pelvis_dir
	current_b_impact_mult = cfg.b_mult
	current_h_mult = cfg.h_mult
	current_breast_motion_type = cfg.motion_type
	b_expand_factor = cfg.b_expand
	b_press_freq_stages = cfg.b_press_freq_stages.duplicate()
	b_press_depth = cfg.b_press_depth
	b_press_rebound = cfg.b_press_rebound
	b_press_y_follow = cfg.b_press_y_follow
	b_press_phase_shift = cfg.b_press_phase_shift
	b_press_smooth = cfg.b_press_smooth
	b_press_inward_px = cfg.b_press_inward_px
	b_press_inward_scale = cfg.b_press_inward_scale
	b_press_vertical_stretch = cfg.b_press_vertical_stretch
	b_press_contact_delay = cfg.b_press_contact_delay
	b_press_attack_ratio = cfg.b_press_attack_ratio
	b_press_release_ratio = cfg.b_press_release_ratio
	current_trigger_vec = cfg.impact_vec
	current_semen_range = cfg.semen_range
	b_rotation_factor = cfg.b_rotation_factor
	h_animation_name = anim_override if anim_override != "" else cfg.anim
	_reset_breast_press_state()

func _get_current_b_press_freq() -> float:
	if b_press_freq_stages.size() < 3:
		return 8.0
	var idx := 0
	if auto_impact_interval > 0.0:
		if auto_impact_interval <= 0.35:
			idx = 2
		elif auto_impact_interval <= 0.8:
			idx = 1
	return max(0.01, float(b_press_freq_stages[idx]))
