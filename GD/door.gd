@tool
extends Area2D
## 場景傳送門：玩家進入範圍後按 **shop_open**（Enter）才轉場。
## 與商店／對話相同的互動方式。門洞能量場由 door_energy.gdshader + 遮罩裁切。
## 光圈：與電腦螢幕相同，使用圓形 radial 貼圖；Energy／顏色／位置／縮放請直接調 PointLight2D。
## Inspector 能量場參數會即時同步到 shader（含執行中遠端 Inspector、編輯器預覽）。

## 此門的 ID (用於重生定位)
@export var point_id: String = "Door_A"

@export_group("傳送目標")
## 目標場景
@export_file("*.tscn") var target_scene: String
## 目標場景中的門 ID
@export var target_door_id: String = "Door_A"
## 玩家傳送到此門時的位移 (防止重複觸發)
@export var spawn_offset: Vector2 = Vector2(50, -50)

@export_group("互動對話（取代轉場）")
## 非空時：按 Enter 播此對話，不切場景（起點門等）
@export var interact_dialogue_id: String = ""
## 是否只播一次（寫入 dlg_ + id；空白則每次可再播）
@export var interact_dialogue_once: bool = false

@export_group("轉場效果")
@export var fade_time: float = 0.5 # 轉場淡入淡出的時間 (秒)
@export var hold_time: float = 0.5 # 黑幕完全遮蓋後額外停留的時間 (秒，用來緩衝載入畫面)
@export var fade_color: Color = Color.BLACK

@export_group("進度")
## 進入此門時標記為已破關（寫入永久 NMO2.CLEARED；開新遊戲也不會消失）
@export var marks_game_cleared: bool = false

@export_group("能量場")
## 是否播放門洞紋路捲動
@export var energy_enabled: bool = true
## UV 捲動速度（紋路視覺移動為其反向；預設左下→右上）
@export var energy_scroll_speed: Vector2 = Vector2(-0.12, 0.12)
## 整面門洞內的格子密度（越大＝重複次數越多）
@export_range(0.5, 16.0, 0.05) var energy_density: float = 3.0
## 每一格內「單體紋路」大小（越大越放大；可 >1 重疊）
@export_range(0.05, 8.0, 0.01) var energy_motif_size: float = 0.75
## 發光強度
@export_range(0.0, 2.0, 0.01) var energy_strength: float = 1.0
## 忽略近黑像素的亮度門檻（PNG 已有 alpha 時可維持預設）
@export_range(0.0, 1.0, 0.01) var energy_black_cutoff: float = 0.08
## 能量場染色（白＝保留紋路原色）
@export var energy_tint: Color = Color(1.0, 1.0, 1.0, 1.0)

@export_group("燈光閃爍")
## 是否讓光圈閃爍提醒玩家
@export var flicker_enabled: bool = true
## 閃爍速度（每秒來回次數）
@export var flicker_speed: float = 1.6
## 最暗時為編輯器 Energy 的倍率
@export_range(0.0, 1.0, 0.01) var flicker_min_ratio: float = 0.55
## 最亮時為編輯器 Energy 的倍率
@export_range(0.0, 2.0, 0.01) var flicker_max_ratio: float = 1.15
## 額外亂閃程度（0=平滑呼吸燈）
@export_range(0.0, 1.0, 0.01) var flicker_random: float = 0.1

@export_group("提示字")
@export var prompt_text: String = "[ENTER]"
@export var prompt_offset: Vector2 = Vector2(0, -120)
@export var prompt_font_size: int = 10
@export var prompt_color: Color = Color(0.78, 0.42, 1.0, 1.0)
@export var prompt_outline_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0, 12, 1) var prompt_outline_size: int = 4
@export var prompt_z_index: int = 20

var _player_inside: bool = false
var _prompt: Label
var _prompt_was_visible: bool = false
var _energy: Sprite2D
var _energy_mat: ShaderMaterial
var _light: PointLight2D
var _editor_energy: float = 1.0
var _flicker_phase: float = 0.0


func _ready() -> void:
	_light = get_node_or_null("PointLight2D") as PointLight2D
	if _light:
		_editor_energy = _light.energy
	_flicker_phase = randf() * TAU
	_setup_energy()
	_sync_exported_visuals()

	if Engine.is_editor_hint():
		print("Door 編輯器預覽就緒 id=", point_id)
		return

	# 註冊到群組，讓 GlobalState 能找到我
	add_to_group("save_points")

	# 如果沒有連接過信號則連接
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	monitoring = true
	_setup_prompt()
	print("Door 就緒 point_id=", point_id, " target=", target_scene, " mask=", collision_mask)


func _process(delta: float) -> void:
	_sync_exported_visuals()
	if Engine.is_editor_hint():
		# 編輯器：不閃爍、不跑提示，只讓參數即時預覽
		if _light and not flicker_enabled:
			_light.energy = _editor_energy
		return
	_apply_flicker(delta)
	_update_prompt_visible()


## 每幀把 Inspector 數值套回 shader／可見性。
func _sync_exported_visuals() -> void:
	if _energy == null or _energy_mat == null:
		_setup_energy()
	if _light == null:
		_light = get_node_or_null("PointLight2D") as PointLight2D
		if _light:
			_editor_energy = _light.energy

	if _energy:
		_energy.visible = energy_enabled
	_apply_energy_params()


func _setup_energy() -> void:
	_energy = get_node_or_null("EnergyField") as Sprite2D
	if _energy == null:
		return
	# 避免多個 Door 實例共用同一份 SubResource 材質
	if _energy.material is ShaderMaterial:
		if not Engine.is_editor_hint() and _energy.material.resource_local_to_scene == false:
			_energy.material = _energy.material.duplicate()
		_energy_mat = _energy.material as ShaderMaterial
	if _energy_mat == null:
		return
	_apply_energy_params()
	_energy.visible = energy_enabled


func _apply_energy_params() -> void:
	if _energy_mat == null:
		return
	_energy_mat.set_shader_parameter("scroll_speed", energy_scroll_speed)
	_energy_mat.set_shader_parameter("pattern_density", energy_density)
	_energy_mat.set_shader_parameter("motif_size", energy_motif_size)
	_energy_mat.set_shader_parameter("pattern_strength", energy_strength)
	_energy_mat.set_shader_parameter("black_cutoff", energy_black_cutoff)
	_energy_mat.set_shader_parameter("tint", energy_tint)


func _apply_flicker(delta: float) -> void:
	if _light == null:
		return
	if not flicker_enabled:
		_light.energy = _editor_energy
		return
	_flicker_phase += delta * flicker_speed * TAU
	var wave: float = (sin(_flicker_phase) + 1.0) * 0.5
	if flicker_random > 0.0:
		wave = clampf(wave + randf_range(-flicker_random, flicker_random), 0.0, 1.0)
	_light.energy = _editor_energy * lerpf(flicker_min_ratio, flicker_max_ratio, wave)


func _setup_prompt() -> void:
	_prompt = get_node_or_null("PromptLabel") as Label
	if _prompt == null:
		_prompt = Label.new()
		_prompt.name = "PromptLabel"
		add_child(_prompt)
		_prompt.text = prompt_text
		_prompt.z_index = prompt_z_index
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_prompt.add_theme_color_override("font_color", prompt_color)
		_prompt.add_theme_color_override("font_outline_color", prompt_outline_color)
		_prompt.add_theme_constant_override("outline_size", prompt_outline_size)
		_prompt.add_theme_font_size_override("font_size", prompt_font_size)
		_prompt.reset_size()
		var sz: Vector2 = _prompt.get_minimum_size()
		if sz.x < 8.0:
			sz = Vector2(72.0, 16.0)
		_prompt.size = sz
		_prompt.position = prompt_offset - Vector2(sz.x * 0.5, sz.y)
		print("Door 提示字：場景沒有 Label，已用腳本預設建立")
	else:
		# 場景裡已有 PromptLabel：字級／顏色／位置全部沿用 Inspector
		print("Door 提示字沿用場景設定 font_size=", _prompt.get_theme_font_size("font_size"))
	_prompt.visible = false
	_prompt_was_visible = false


## 進範圍即可顯示提示（與商店相同）；不因 target 未填而隱藏。
func _can_show_prompt() -> bool:
	if not _player_inside:
		return false
	if GlobalState.changing_scene:
		return false
	if GlobalState.is_paused:
		return false
	if DialogueBox.is_dialogue_open:
		return false
	if ProgressionShop.is_shop_open:
		return false
	if HSystem.is_h_mode_active():
		return false
	return true


func _can_interact() -> bool:
	if not _can_show_prompt():
		return false
	if not interact_dialogue_id.is_empty():
		if interact_dialogue_once and GlobalState.has_dialogue_flag("dlg_" + interact_dialogue_id):
			return false
		return true
	if target_scene.is_empty():
		return false
	return true


func _update_prompt_visible() -> void:
	if _prompt == null:
		return
	# 對話門：已看過 once 時隱藏提示；轉場門：仍用可顯示條件
	var show: bool = _can_interact() if not interact_dialogue_id.is_empty() else _can_show_prompt()
	if show == _prompt_was_visible:
		_prompt.visible = show
		return
	_prompt_was_visible = show
	_prompt.visible = show
	print("Door 提示: ", "顯示" if show else "隱藏", " id=", point_id, " inside=", _player_inside)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_inside = true
		print("Door 進入範圍 id=", point_id)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_inside = false
		print("Door 離開範圍 id=", point_id)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not _player_inside:
		return
	if not event.is_action_pressed("shop_open"):
		return
	if not _can_show_prompt():
		return
	if not interact_dialogue_id.is_empty():
		_play_interact_dialogue()
		get_viewport().set_input_as_handled()
		return
	if target_scene.is_empty():
		print("Door 無法進入：target_scene 未設定 id=", point_id)
		get_viewport().set_input_as_handled()
		return
	_enter_door()
	get_viewport().set_input_as_handled()


func _play_interact_dialogue() -> void:
	if interact_dialogue_once and GlobalState.has_dialogue_flag("dlg_" + interact_dialogue_id):
		print("Door 對話已看過 id=", interact_dialogue_id)
		return
	var flag: String = ("dlg_" + interact_dialogue_id) if interact_dialogue_once else ""
	var ok: bool = DialogueBox.start(interact_dialogue_id, flag)
	print("Door 互動對話 id=", interact_dialogue_id, " ok=", ok)


func _enter_door() -> void:
	# 1. 暫停遊戲
	get_tree().paused = true

	if marks_game_cleared:
		GlobalState.mark_game_cleared()

	# 2. 僅告知 GlobalState 我要去哪扇門
	GlobalState.target_door_id = target_door_id
	print(GlobalState.target_door_id)

	# 3. 純切場景（不存檔；存檔留給 SAVE_POINT）
	GlobalState.change_scene(target_scene, fade_time, hold_time, fade_color, false, true, false)
	print("Door 進入轉場（不存檔） id=", point_id, " -> ", target_scene)
