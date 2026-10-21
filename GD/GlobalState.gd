extends Node

# --- 訊號定義 ---
## 當觸發換裝區域或指令時發出
## @param type: 0 (Toggle), 1 (Naked), 2 (Clothed)
signal request_appearance_change(type: int)
## Shirt Open 狀態改變時發出（true=進入 OPEN，false=結束 OPEN）
signal shirt_open_state_changed(active: bool)
## Lewd 開關改變時發出（需已購買 lewd_state；true=ON，false=OFF）
signal lewd_active_changed(active: bool)
## 語言變更後發出（選單等可即時刷新）
signal language_changed
## 劇情／守關旗標寫入時送出（energy_barrier 等監聽）
signal dialogue_flag_changed(key: String)

# --- 列舉型別定義 ---
enum AppearanceMode { NAKED, CLOTHED }
enum Language { EN, JA }
enum DisplayMode { FULLSCREEN, WINDOW_1080P, WINDOW_540P }

## 外觀模式改變時發出（NAKED／CLOTHED）
signal appearance_mode_changed(mode: AppearanceMode)

# --- 角色與行為設定 ---
var current_outfit: String = "default" ## 目前服裝／外觀套組識別字串
var current_mode: AppearanceMode = AppearanceMode.CLOTHED ## 目前外觀模式（NAKED／CLOTHED）
var enable_H_keys: bool = false ## 是否啟用 H 相關快捷鍵
var enable_cloth_keys: bool = false ## 是否啟用換裝快捷鍵
var changing_scene: bool = false ## 是否正在進行場景轉場（阻擋重入）
var is_paused: bool = false ## 遊戲是否處於暫停狀態
var from_pause: bool = false ## 是否從暫停選單離開／返回（流程旗標）
var game_cleared: bool = false ## 是否已破關（永久寫入 NMO2.CLEARED；主選單女主圖等可讀取）
var progression_owned: Dictionary = {} ## 進度商店已購買項目（key 見 progression_shop.gd 常數）
var dialogue_flags: Dictionary = {} ## 劇情對話已看過旗標（key 由 StoryTrigger／DialogueBox 決定）
var target_door_id: String = "" ## 下一個要出現的門或存檔點 ID
## Lewd 狀態是否開啟（僅在已購買 ProgressionShop.KEY_LEWD_STATE / "lewd_state" 時可切換）
var is_lewd_active: bool = false

# --- 視覺相關 ---
var _overlay_layer: CanvasLayer ## 轉場黑幕用 CanvasLayer
var _color_rect: ColorRect ## 轉場全螢幕黑色遮罩
var _saving_label: Label ## 「SAVING」文字標籤
var _saving_canvas: CanvasLayer ## 存檔提示用 CanvasLayer
var _time_canvas: CanvasLayer ## 遊玩時間顯示用 CanvasLayer

# --- Shirt Open（由 HSystem Horny 達上限觸發；倒數／閃爍在此；視覺腳本只讀 is_shirt_open）---
const SHIRT_OPEN_CONFIG_PATH := "res://TRES/horny_shirt_open.tres"
var _shirt_flash_layer: CanvasLayer ## Shirt Open 閃爍用 CanvasLayer
var _shirt_flash_rect: ColorRect ## Shirt Open 全螢幕閃爍色塊
var _shirt_flash_tween: Tween ## Shirt Open 閃爍淡入淡出 Tween
var is_shirt_open: bool = false ## 目前是否處於 Shirt Open（與著衣／裸體無關；僅 H 中暫停倒數）
var _shirt_open_timer: float = 0.0 ## OPEN 剩餘秒數
var _shirt_open_duration: float = 30.0 ## 來自 horny_shirt_open.tres 的維持秒數

# --- 遊玩時間相關 ---
var _total_play_seconds: float = 0.0 ## 累積的總遊玩秒數（已寫入存檔部分）
var _session_seconds: float = 0.0 ## 本次開啟遊戲後的秒數（尚未寫入存檔）
var _time_label: Label ## 左上角遊玩時間顯示用 Label
var _time_update_timer: float = 0.0 ## 每秒更新一次 Label 的計時器


@export_group("Language（語言）")
@export var language: Language = Language.EN ## 遊戲語言（EN／JA）

@export_group("Settings（系統設定，獨立於存檔）")
@export var display_mode: DisplayMode = DisplayMode.WINDOW_1080P ## 顯示模式
@export_range(0, 10, 1) var volume_level: int = 8 ## 音量階數（0~10，對應 bgm_volume）

@export_file("*.tscn") var default_start_scene: String = "" ## 預設開場／繼續遊戲場景路徑

@export var time_label_font_size: int = 24 ## 遊玩時間字級
@export var time_label_color: Color = Color(1.0, 1.0, 1.0, 0.85) ## 遊玩時間文字色（白色半透明）
@export var time_label_outline_size: int = 3 ## 遊玩時間描邊粗細
@export var time_label_outline_color: Color = Color(0.0, 0.0, 0.0, 1.0) ## 遊玩時間描邊色（黑色）
@export var time_label_offset: Vector2 = Vector2(-100, 0) ## 遊玩時間距右上角的像素偏移

# --- 背景音樂 ---
@export var bgm_stream: AudioStream ## 拖入 BGM 音樂檔案
var _bgm_player: AudioStreamPlayer ## 實際播放 BGM 的 AudioStreamPlayer
@export_range(0.0, 1.0, 0.05) var bgm_volume: float = 0.8 ## BGM 音量（0.0~1.0）
var _last_bgm_volume: float = -1.0 ## 上一幀 BGM 音量（用來偵測 Inspector 是否有變動）

# --- DEBUG：執行時於自動載入節點 Inspector 切換（正式版請關閉同步）---
@export_group("DEBUG（Inspector）")
@export var debug_sync_inspector_to_runtime: bool = false ## 勾選後每幀將下方 DEBUG 覆寫到 runtime（外觀僅在欄位變更時套用）
@export var debug_game_cleared: bool = false ## DEBUG：覆寫 game_cleared
@export var debug_enable_H_keys: bool = false ## DEBUG：覆寫 enable_H_keys（通關／畫廊後不會再蓋成 false）
@export var debug_enable_cloth_keys: bool = false ## DEBUG：覆寫 enable_cloth_keys（通關／畫廊後不會再蓋成 false）
@export var debug_appearance_mode: AppearanceMode = AppearanceMode.CLOTHED ## DEBUG：覆寫外觀模式（僅欄位變更時套用）
var _debug_prev_appearance_mode: AppearanceMode = AppearanceMode.CLOTHED ## DEBUG：上一幀外觀選項（偵測 Inspector 是否改動）

@export_group("GAME OVER")
@export var enable_game_over: bool = true ## 關閉時 HP 歸零不會進入結束流程（方便測試）
@export_file("*.tscn") var game_over_scene: String = "res://TSCN/game_over.tscn" ## HP <= 0 時進入的 GAME OVER 場景（停留後再進主選單）

@export_group("UI Layers（由下而上）")
## 125 Shirt Open 閃爍 → 126 商店 → 127 對話／HUD → 128 轉場 → 129 存檔 → 130 暫停 → 131 時間
@export var layer_shirt_open_flash: int = 125 ## Shirt Open 全螢幕閃爍 CanvasLayer
@export var layer_transition: int = 128 ## 場景轉場黑幕 CanvasLayer
@export var layer_saving: int = 129 ## 存檔 SAVING 提示 CanvasLayer
@export var layer_play_time: int = 131 ## 遊玩時間顯示 CanvasLayer

@export_group("Corner Toast（Loading／SAVING／Gallery）")
## 右下角提示字級（Gallery mode on 過長可改小）
@export var corner_toast_font_size: int = 22
@export var corner_toast_font_color: Color = Color.WHITE
## PRESET_BOTTOM_RIGHT 的邊距（越大越往內）
@export var corner_toast_margin: int = 50
## 額外像素偏移（負 X＝往左）
@export var corner_toast_extra_offset: Vector2 = Vector2(-8, -8)

@export_group("Shirt Open Flash")
@export var shirt_open_flash_start_color: Color = Color(1.0, 0.45, 0.75, 1.0) ## 進入 OPEN 時的閃爍色（粉紅）
@export var shirt_open_flash_end_color: Color = Color(0.78, 0.78, 0.78, 1.0) ## 結束 OPEN 時的閃爍色（淺灰）
@export_range(0.0, 1.0, 0.01) var shirt_open_flash_peak_alpha: float = 0.35 ## 閃爍最高不透明度
@export var shirt_open_flash_fade_in: float = 0.08 ## 閃爍淡入秒數
@export var shirt_open_flash_fade_out: float = 0.25 ## 閃爍淡出秒數

@export_group("Save Flash")
## 觸碰存檔時全畫面閃爍色（與 Computer_Blue 螢幕相同）
@export var save_flash_color: Color = Color(118.0 / 255.0, 240.0 / 255.0, 255.0 / 255.0, 1.0)

# --- 存檔相關設定（統一 NMO2. 命名）---
const SAVE_PATH = "user://NMO2.SAVE" ## 遊戲進度存檔
const SETTINGS_PATH = "user://NMO2.SETTING" ## 系統設定（與存檔分離）
const CLEARED_PATH = "user://NMO2.CLEARED" ## 永久破關旗標（開新遊戲也不清除）

## 舊檔名 → 新檔名（首次啟動遷移）
const _LEGACY_SAVE_PATH = "user://autosave.save"
const _LEGACY_SETTINGS_PATH = "user://settings.save"

func is_progression_item_owned(key: String) -> bool:
	return progression_owned.get(key, false) == true


func mark_progression_item_owned(key: String) -> void:
	progression_owned[key] = true


## 是否已解鎖商店 SlotLewd（lewd_state）
func is_lewd_unlocked() -> bool:
	return is_progression_item_owned("lewd_state")


## 是否已解鎖 Lewd State+（按 S 切換著衣／裸體）
func is_cloth_keys_unlocked() -> bool:
	return is_progression_item_owned("lewd_state_plus")


## 目前是否可用 S 鍵換裝（商店解鎖或 debug／劇情強制開啟 enable_cloth_keys）
func can_use_cloth_keys() -> bool:
	return enable_cloth_keys or is_cloth_keys_unlocked()


## 設定 Lewd ON/OFF（未解鎖則強制 OFF；回傳是否實際變更）
func set_lewd_active(active: bool) -> bool:
	var next: bool = active and is_lewd_unlocked()
	if is_lewd_active == next:
		return false
	is_lewd_active = next
	lewd_active_changed.emit(is_lewd_active)
	print("[GlobalState] Lewd → ", "ON" if is_lewd_active else "OFF")
	return true


## 切換 Lewd ON/OFF（未解鎖則無效）
func toggle_lewd_active() -> bool:
	if not is_lewd_unlocked():
		return false
	return set_lewd_active(not is_lewd_active)


func has_dialogue_flag(key: String) -> bool:
	if key.is_empty():
		return false
	return dialogue_flags.get(key, false) == true


func set_dialogue_flag(key: String) -> void:
	if key.is_empty():
		return
	dialogue_flags[key] = true
	print("[DialogueFlag] set: ", key)
	dialogue_flag_changed.emit(key)


func _ready():
	_debug_prev_appearance_mode = debug_appearance_mode
	# 必須在這裡初始化所有 UI
	_migrate_legacy_user_files()
	_load_shirt_open_config()
	_setup_shirt_open_flash_ui()
	_setup_transition_ui()
	_setup_saving_ui()
	load_cleared_flag() ## 永久破關旗標（不依賴進度存檔）
	load_settings() ## 先讀系統設定，再套用顯示／音量
	_setup_bgm()
	_setup_time_ui()  # 初始化時間顯示
	apply_display_mode()
	if HSystem.hp_depleted.is_connected(_on_hsystem_hp_depleted) == false:
		HSystem.hp_depleted.connect(_on_hsystem_hp_depleted)

func _on_hsystem_hp_depleted() -> void:
	if not enable_game_over:
		print("[DEBUG] GAME OVER 已停用（enable_game_over = false），HP 已歸零。")
		return
	_set_player_movement_locked(true)
	call_deferred("_deferred_game_over")

func _deferred_game_over() -> void:
	if changing_scene:
		return
	prepare_for_main_menu()
	var path: String = game_over_scene
	if path == "":
		path = "res://TSCN/game_over.tscn"
	print("[GlobalState] GAME OVER → ", path)
	await change_scene(path, 0.5, 0.0, Color.BLACK, false, false, false)

## 初始化左上角遊玩時間顯示
func _setup_time_ui():
	_time_canvas = CanvasLayer.new()
	_time_canvas.layer = layer_play_time
	add_child(_time_canvas)
	
	_time_label = Label.new()
	_time_label.text = "00:00:00"
	
	var l_settings = LabelSettings.new()
	l_settings.font_size = time_label_font_size
	l_settings.font_color = time_label_color
	l_settings.outline_size = time_label_outline_size
	l_settings.outline_color = time_label_outline_color
	_time_label.label_settings = l_settings
	
	# 錨點設在左上角，再用 offset 微調位置
	_time_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_time_label.position = time_label_offset
	
	_time_canvas.add_child(_time_label)

## 將總秒數格式化為 HH:MM:SS
func _format_time(total_seconds: float) -> String:
	var secs = int(total_seconds)
	var h = secs / 3600
	var m = (secs % 3600) / 60
	var s = secs % 60
	return "%02d:%02d:%02d" % [h, m, s]

func _process(delta):
	if debug_sync_inspector_to_runtime:
		# 通關／畫廊開啟後，關卡強制開的 H／換裝鍵不可被 DEBUG 覆寫關掉
		if not game_cleared:
			game_cleared = debug_game_cleared
			enable_H_keys = debug_enable_H_keys
			enable_cloth_keys = debug_enable_cloth_keys
		else:
			# 已通關：DEBUG 只能「額外打開」，不能關掉
			if debug_game_cleared:
				game_cleared = true
			if debug_enable_H_keys:
				enable_H_keys = true
			if debug_enable_cloth_keys:
				enable_cloth_keys = true
		if debug_appearance_mode != _debug_prev_appearance_mode:
			_debug_prev_appearance_mode = debug_appearance_mode
			current_mode = debug_appearance_mode
			request_appearance_change.emit(1 if current_mode == AppearanceMode.NAKED else 2)
			appearance_mode_changed.emit(current_mode)
	
	# --- BGM 音量即時調整 ---
	if bgm_volume != _last_bgm_volume:
		_last_bgm_volume = bgm_volume
		if _bgm_player:
			_bgm_player.volume_db = linear_to_db(maxf(bgm_volume, 0.0001)) if bgm_volume > 0.0 else -80.0
	
	# --- 累積遊玩時間 ---
	_session_seconds += delta
	_time_update_timer += delta
	if _time_update_timer >= 1.0:
		_time_update_timer = 0.0
		if _time_label:
			_time_label.text = _format_time(_total_play_seconds + _session_seconds)

	# --- Shirt Open 倒數（僅 H 中暫停；非 H 時裸／著衣都消耗）---
	_process_shirt_open_timer(delta)

## 讀取共用開襯衫維持秒數（TRES/horny_shirt_open.tres）
func _load_shirt_open_config() -> void:
	var cfg := load(SHIRT_OPEN_CONFIG_PATH) as HornyShirtOpenConfig
	if cfg:
		_shirt_open_duration = maxf(cfg.duration_seconds, 0.05)
	else:
		_shirt_open_duration = 30.0
		push_warning("GlobalState: 找不到 horny_shirt_open.tres，OPEN 秒數用 30")

## 初始化 Shirt Open 全螢幕閃爍（layer 最低於商店／HUD／轉場等）
func _setup_shirt_open_flash_ui() -> void:
	_shirt_flash_layer = CanvasLayer.new()
	_shirt_flash_layer.layer = layer_shirt_open_flash
	_shirt_flash_layer.name = "ShirtOpenFlashLayer"
	add_child(_shirt_flash_layer)

	_shirt_flash_rect = ColorRect.new()
	_shirt_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shirt_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shirt_flash_rect.color = Color.WHITE
	_shirt_flash_rect.modulate.a = 0.0
	_shirt_flash_layer.add_child(_shirt_flash_rect)

## 由 HSystem 呼叫：Horny 剛達上限 → 進入 OPEN，或已 OPEN 則重設倒數（不重閃）
func notify_horny_reached_max_for_shirt_open() -> void:
	var was_open: bool = is_shirt_open
	is_shirt_open = true
	_shirt_open_timer = _shirt_open_duration
	print("[GlobalState] Shirt Open：Horny 達上限 → OPEN，timer=", _shirt_open_timer)
	if was_open:
		return
	shirt_open_state_changed.emit(true)
	_play_shirt_open_flash(shirt_open_flash_start_color)

func _process_shirt_open_timer(delta: float) -> void:
	if not is_shirt_open:
		return
	if get_tree().paused:
		return
	if changing_scene:
		return
	# 僅 H 進行中暫停倒數；非 H 的裸體／著衣都繼續倒數
	if HSystem.is_h_mode_active():
		return
	_shirt_open_timer -= delta
	if _shirt_open_timer <= 0.0:
		_end_shirt_open_from_timer()

func _end_shirt_open_from_timer() -> void:
	if not is_shirt_open:
		return
	is_shirt_open = false
	_shirt_open_timer = 0.0
	print("[GlobalState] Shirt Open：倒數結束 → 非 OPEN")
	shirt_open_state_changed.emit(false)
	_play_shirt_open_flash(shirt_open_flash_end_color)

## 強制清除 Shirt Open 全域狀態與閃爍（回主選單／GAME OVER／讀檔前用；不發結束閃爍）
func clear_shirt_open_runtime(emit_signal: bool = true) -> void:
	var was_open: bool = is_shirt_open
	is_shirt_open = false
	_shirt_open_timer = 0.0
	if _shirt_flash_tween and _shirt_flash_tween.is_valid():
		_shirt_flash_tween.kill()
	if _shirt_flash_rect:
		_shirt_flash_rect.modulate.a = 0.0
	if emit_signal and was_open:
		shirt_open_state_changed.emit(false)

## 回主選單／GAME OVER：清掉會殘留的暫態（Shirt Open、H 旗標、HUD）
func prepare_for_main_menu() -> void:
	clear_shirt_open_runtime(true)
	HSystem.set_h_mode_active(false)
	HSystem.show_h_stats_ui = false
	is_paused = false
	from_pause = false
	if DialogueBox.is_dialogue_open:
		DialogueBox.close()
	print("[GlobalState] prepare_for_main_menu：已重設 Shirt Open／H 旗標／HUD／對話")

func _play_shirt_open_flash(flash_color: Color) -> void:
	play_full_screen_flash(flash_color, shirt_open_flash_peak_alpha, shirt_open_flash_fade_in, shirt_open_flash_fade_out)

## 全螢幕淡入淡出閃爍（Horny OPEN／醫藥箱等共用同一層 ColorRect + Tween）
func play_full_screen_flash(flash_color: Color, peak_alpha: float, fade_in: float, fade_out: float) -> void:
	if _shirt_flash_rect == null:
		return
	if _shirt_flash_tween and _shirt_flash_tween.is_valid():
		_shirt_flash_tween.kill()
	_shirt_flash_rect.color = flash_color
	_shirt_flash_rect.modulate.a = 0.0
	_shirt_flash_tween = create_tween()
	_shirt_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_shirt_flash_tween.tween_property(_shirt_flash_rect, "modulate:a", peak_alpha, maxf(fade_in, 0.0)).set_trans(Tween.TRANS_SINE)
	_shirt_flash_tween.tween_property(_shirt_flash_rect, "modulate:a", 0.0, maxf(fade_out, 0.0)).set_trans(Tween.TRANS_SINE)

## 初始化轉場用的遮罩 UI
func _setup_transition_ui():
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = layer_transition
	
	_color_rect = ColorRect.new()
	_color_rect.color = Color.BLACK
	_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_color_rect.modulate.a = 0.0
	
	_overlay_layer.add_child(_color_rect)
	add_child(_overlay_layer)

## 初始化右下角 SAVING 提示
func _setup_saving_ui():
	_saving_canvas = CanvasLayer.new()
	_saving_canvas.layer = layer_saving
	add_child(_saving_canvas)
	
	_saving_label = Label.new()
	_saving_label.text = "Loading..." ## 過場預設；存檔點會暫時改成 SAVING...
	
	# 設定文字樣式（字級／顏色可在 Inspector → Corner Toast 調）
	var l_settings = LabelSettings.new()
	l_settings.font_size = corner_toast_font_size
	l_settings.font_color = corner_toast_font_color
	l_settings.outline_size = 0
	l_settings.outline_color = Color.BLACK
	_saving_label.label_settings = l_settings
	
	# 設定錨點為右下角
	_saving_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, corner_toast_margin)
	_saving_label.offset_left += corner_toast_extra_offset.x
	_saving_label.offset_top += corner_toast_extra_offset.y
	_saving_label.offset_right += corner_toast_extra_offset.x
	_saving_label.offset_bottom += corner_toast_extra_offset.y
	
	# 預設完全透明
	_saving_label.modulate.a = 0.0 
	_saving_canvas.add_child(_saving_label)


## 套用 Corner Toast 字級／顏色／位置（執行中也可再呼叫）
func apply_corner_toast_style() -> void:
	if _saving_label == null:
		return
	var ls: LabelSettings = _saving_label.label_settings
	if ls == null:
		ls = LabelSettings.new()
		_saving_label.label_settings = ls
	ls.font_size = corner_toast_font_size
	ls.font_color = corner_toast_font_color
	_saving_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, corner_toast_margin)
	_saving_label.offset_left += corner_toast_extra_offset.x
	_saving_label.offset_top += corner_toast_extra_offset.y
	_saving_label.offset_right += corner_toast_extra_offset.x
	_saving_label.offset_bottom += corner_toast_extra_offset.y

## 執行存檔視覺回饋 (閃爍 + 文字)
func play_save_effects():
	if not _color_rect or not _saving_label: return
	
	# 1. 螢幕閃爍
	_color_rect.color = save_flash_color
	var tween = create_tween()
	tween.tween_property(_color_rect, "modulate:a", 0.3, 0.1)
	tween.tween_property(_color_rect, "modulate:a", 0.0, 0.2)
	
	# 2. 右下角文字淡入淡出（存檔點專用 SAVING）
	_saving_label.text = "SAVING..."
	var t_label = create_tween()
	t_label.tween_property(_saving_label, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	t_label.tween_interval(0.5)
	t_label.tween_property(_saving_label, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)


## 右下角狀態文字（與 Loading／SAVING 同位置字體）；不暫停時間
func play_corner_toast(text: String, fade_in: float = 0.3, hold: float = 1.2, fade_out: float = 0.5) -> void:
	if _saving_label == null:
		return
	apply_corner_toast_style()
	_saving_label.text = text
	_saving_label.modulate.a = 0.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_saving_label, "modulate:a", 1.0, maxf(fade_in, 0.01)).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(maxf(hold, 0.0))
	tw.tween_property(_saving_label, "modulate:a", 0.0, maxf(fade_out, 0.01)).set_trans(Tween.TRANS_SINE)
	print("[GlobalState] corner toast: ", text)

## 依目前 target_door_id 更新存檔點電腦：藍=目前重生點，粉=其他存檔點
func refresh_save_point_visuals() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var points = tree.get_nodes_in_group("save_points")
	for p in points:
		if is_instance_valid(p) and p.has_method("refresh_active_visual"):
			p.refresh_active_visual()
	print("[GlobalState] 已更新存檔點視覺，目前重生點 ID: ", target_door_id)

## 鎖定 Player 節點（GAME OVER 轉場前呼叫；換場後舊場景會釋放，無需解鎖）
func _set_player_movement_locked(locked: bool) -> void:
	var p: Node = get_tree().get_first_node_in_group("Player")
	if p == null:
		return
	if locked:
		if p is CharacterBody2D:
			(p as CharacterBody2D).velocity = Vector2.ZERO
		p.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		p.process_mode = Node.PROCESS_MODE_INHERIT

## 執行場景轉換與自動定位
## save_on_transition：轉場前／後是否寫入 NMO2.SAVE（GAME OVER 應為 false）
## teleport_after_change：載入場景後是否依存檔定位玩家（主選單／GAME OVER 應為 false）
## reveal_h_stats_ui_after_fade：黑幕淡出完成後才顯示 HP／Horny／Semen 條（主選單進關卡用 true）
func change_scene(
	scene_path: String,
	duration: float = 0.5,
	hold_time: float = 0.5,
	fade_color: Color = Color.BLACK,
	save_on_transition: bool = true,
	teleport_after_change: bool = true,
	reveal_h_stats_ui_after_fade: bool = false
):
	if changing_scene: return
	changing_scene = true
	if DialogueBox.is_dialogue_open:
		DialogueBox.close()
	
	_color_rect.color = fade_color
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_color_rect, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	
	await tween.finished
	
	# 過場右下角一律顯示 Loading...（存檔與否與文字無關）
	if _saving_label:
		_saving_label.text = "Loading..."
		var t_show = create_tween()
		t_show.tween_property(_saving_label, "modulate:a", 1.0, 0.2)
	
	if !from_pause and save_on_transition:
		save_game()
	
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("場景轉換失敗")
		get_tree().paused = false
		_color_rect.modulate.a = 0.0
		if _saving_label: _saving_label.modulate.a = 0.0
		changing_scene = false
		if not save_on_transition:
			_set_player_movement_locked(false)
		return
		
	get_tree().paused = false
	
	if hold_time > 0:
		await get_tree().create_timer(hold_time, true, false, true).timeout
	
	if teleport_after_change:
		teleport_player_to_target()

	# 黑幕仍蓋著時強制相機對準玩家，避免 position_smoothing 從舊座標／原點滑過去
	await get_tree().process_frame
	_snap_player_camera()
	await get_tree().physics_frame
	_snap_player_camera()
	
	await get_tree().create_timer(hold_time, true, false, true).timeout
	if !from_pause and save_on_transition:
		save_game()
	
	if _saving_label:
		var t_hide = create_tween()
		t_hide.tween_property(_saving_label, "modulate:a", 0.0, 0.2)

	var tween_out = create_tween()
	tween_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_out.tween_property(_color_rect, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	
	await tween_out.finished
	if reveal_h_stats_ui_after_fade:
		HSystem.show_h_stats_ui = true
	changing_scene = false
	from_pause = false

## 轉場後立刻把 Camera2D 對準玩家（不關掉平常的 smoothing）
func _snap_player_camera() -> void:
	var player: Node = get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var cam: Camera2D = null
	if "camera" in player and player.camera is Camera2D:
		cam = player.camera as Camera2D
	else:
		cam = player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		push_warning("[GlobalState] 找不到玩家 Camera2D，略過對準")
		return
	if player.has_method("reset_physics_interpolation"):
		player.reset_physics_interpolation()
	if cam.has_method("reset_physics_interpolation"):
		cam.reset_physics_interpolation()
	cam.reset_smoothing()
	cam.force_update_scroll()
	print("[GlobalState] 相機已對準玩家 @ ", player.global_position)

## 核心定位功能
func teleport_player_to_target():
	# spawn_id：本次要出現的位置（門傳送會先設好）
	var spawn_id: String = target_door_id
	# 存檔內的重生點（SAVE_POINT）；門不存檔，定位後還原以免污染後續存檔
	var saved_spawn_id: String = ""
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data: Variant = json.get_data()
			if typeof(data) == TYPE_DICTIONARY:
				saved_spawn_id = str(data.get("target_door_id", ""))
	
	if spawn_id == "":
		spawn_id = saved_spawn_id
	
	if spawn_id == "":
		print("[GlobalState] 無目標 ID")
		return

	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		push_warning("[GlobalState] 找不到玩家節點")
		return

	var points = get_tree().get_nodes_in_group("save_points")
	var found = false
	
	for p in points:
		if "point_id" in p and p.point_id == spawn_id:
			var offset = Vector2.ZERO
			if "spawn_offset" in p:
				offset = p.spawn_offset
			
			player.global_position = p.global_position + offset
			found = true
			print("[GlobalState] 定位成功: ", spawn_id)
			break
	
	if not found:
		push_warning("[GlobalState] 找不到 ID: " + spawn_id)
	
	# 還原為存檔重生點（若有），讓 SAVE_POINT 藍燈／Continue 不被門 ID 覆蓋
	if saved_spawn_id != "":
		target_door_id = saved_spawn_id
	else:
		target_door_id = spawn_id
	refresh_save_point_visuals()

func save_game():
	# 存檔：位置／著衣、HP／Horny／Semen（含上限）、商店已購、遊玩時間
	# 不存 Shirt Open 剩餘秒數：視覺由 horny + current_mode 在讀檔後重算即可，避免半透明／OPEN 不同步
	var save_data = {
		"current_outfit": current_outfit,
		"current_mode": int(current_mode),
		"enable_H_keys": enable_H_keys,
		"enable_cloth_keys": enable_cloth_keys,
		"target_door_id": target_door_id,
		"current_scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
		"total_play_seconds": _total_play_seconds + _session_seconds,
		"game_cleared": game_cleared,
		"h_hp": HSystem.hp,
		"h_horny": HSystem.horny,
		"h_semen": HSystem.semen,
		"h_hp_max": HSystem.hp_max,
		"h_horny_max": HSystem.horny_max,
		"h_semen_max": HSystem.semen_max,
		"progression_owned": progression_owned.duplicate(true),
		"dialogue_flags": dialogue_flags.duplicate(true),
		"is_lewd_active": is_lewd_active
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_line(JSON.stringify(save_data))
		file.close()
		_total_play_seconds += _session_seconds
		_session_seconds = 0.0
		print("[Save] ID: ", target_door_id,
			" | HP:", HSystem.hp, "/", HSystem.hp_max,
			" Horny:", HSystem.horny, "/", HSystem.horny_max,
			" Semen:", HSystem.semen, "/", HSystem.semen_max,
			" | 商店:", progression_owned.size(),
			" | 對話旗標:", dialogue_flags.size(),
			" | 時間: ", _format_time(_total_play_seconds))
		refresh_save_point_visuals()
		if game_cleared:
			save_cleared_flag()

func load_game():
	if not FileAccess.file_exists(SAVE_PATH): return
	# 讀檔前清掉暫態，避免上一局 OPEN／H 殘留影響 Sprite
	clear_shirt_open_runtime(false)
	HSystem.set_h_mode_active(false)
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			current_outfit = data.get("current_outfit", "default")
			current_mode = int(data.get("current_mode", AppearanceMode.CLOTHED)) as AppearanceMode
			enable_H_keys = data.get("enable_H_keys", true)
			enable_cloth_keys = data.get("enable_cloth_keys", false)
			target_door_id = data.get("target_door_id", "")
			# 破關旗標：存檔為 true 或永久破關檔存在 → 皆視為已破關（不可被存檔 false 蓋掉）
			if data.get("game_cleared", false) or FileAccess.file_exists(CLEARED_PATH):
				mark_game_cleared()
			else:
				game_cleared = false
			_total_play_seconds = float(data.get("total_play_seconds", 0.0))
			_session_seconds = 0.0
			# 先還原上限（商店加點後的結果），再還原當前值
			if data.has("h_hp_max"):
				HSystem.hp_max = float(data["h_hp_max"])
			if data.has("h_horny_max"):
				HSystem.horny_max = float(data["h_horny_max"])
			if data.has("h_semen_max"):
				HSystem.semen_max = float(data["h_semen_max"])
			var po: Variant = data.get("progression_owned", {})
			if typeof(po) == TYPE_DICTIONARY:
				progression_owned = (po as Dictionary).duplicate(true)
			else:
				progression_owned.clear()
			var df: Variant = data.get("dialogue_flags", {})
			if typeof(df) == TYPE_DICTIONARY:
				dialogue_flags = (df as Dictionary).duplicate(true)
			else:
				dialogue_flags.clear()
			# 未購買 SlotLewd 時強制 OFF（舊存檔無此欄位則預設 false）
			is_lewd_active = bool(data.get("is_lewd_active", false)) and is_lewd_unlocked()
			lewd_active_changed.emit(is_lewd_active)
			HSystem.load_stats(
				float(data.get("h_hp", HSystem.hp_max)),
				float(data.get("h_horny", 0.0)),
				float(data.get("h_semen", 0.0))
			)
			print("[Load] ID: ", target_door_id,
				" | HP:", HSystem.hp, "/", HSystem.hp_max,
				" Horny:", HSystem.horny, "/", HSystem.horny_max,
				" Semen:", HSystem.semen, "/", HSystem.semen_max,
				" | 商店:", progression_owned.size(),
				" | 對話旗標:", dialogue_flags.size(),
				" | 時間: ", _format_time(_total_play_seconds))
			refresh_save_point_visuals()

func reset_game():
	clear_shirt_open_runtime(false)
	HSystem.set_h_mode_active(false)
	current_outfit = "default"
	current_mode = AppearanceMode.CLOTHED
	target_door_id = ""
	# game_cleared 不重設：永久破關後主選單女主永遠保持過關姿
	enable_H_keys = true
	enable_cloth_keys = false
	_total_play_seconds = 0.0
	_session_seconds = 0.0
	if _time_label:
		_time_label.text = "00:00:00"
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	progression_owned.clear()
	dialogue_flags.clear()
	is_lewd_active = false
	lewd_active_changed.emit(false)
	if DialogueBox.is_dialogue_open:
		DialogueBox.close()
	HSystem.reset_to_defaults()
	await change_scene(default_start_scene, 0.5, 0.5, Color.BLACK, true, true, true)


## 主選單開啟時讀取永久破關旗標（不載入場景、不定位玩家、不改著衣狀態）
func peek_save_for_main_menu() -> void:
	load_cleared_flag()

# ==============================================================================
# 永久破關旗標（NMO2.CLEARED；與進度存檔／設定分離）
# ==============================================================================

## 標記已破關並寫入永久檔（開新遊戲／刪存檔也不會消失）
func mark_game_cleared() -> void:
	game_cleared = true
	save_cleared_flag()


## 寫入 NMO2.CLEARED
func save_cleared_flag() -> void:
	var data := {"game_cleared": true}
	var file := FileAccess.open(CLEARED_PATH, FileAccess.WRITE)
	if file:
		file.store_line(JSON.stringify(data))
		file.close()
		print("[Cleared] 已記錄永久破關 → ", CLEARED_PATH)


## 讀取 NMO2.CLEARED（存在即視為已破關）
func load_cleared_flag() -> void:
	if not FileAccess.file_exists(CLEARED_PATH):
		return
	game_cleared = true
	print("[Cleared] 已載入永久破關旗標")


## 舊檔名遷移為 NMO2.*（僅第一次）
func _migrate_legacy_user_files() -> void:
	_migrate_user_file(_LEGACY_SAVE_PATH, SAVE_PATH)
	_migrate_user_file(_LEGACY_SETTINGS_PATH, SETTINGS_PATH)
	# 若舊存檔已破關，補寫永久破關檔
	if not FileAccess.file_exists(CLEARED_PATH) and FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data: Variant = json.get_data()
				if typeof(data) == TYPE_DICTIONARY and data.get("game_cleared", false):
					save_cleared_flag()


func _migrate_user_file(old_path: String, new_path: String) -> void:
	if FileAccess.file_exists(new_path):
		return
	if not FileAccess.file_exists(old_path):
		return
	var src := FileAccess.open(old_path, FileAccess.READ)
	if src == null:
		return
	var text: String = src.get_as_text()
	src.close()
	var dst := FileAccess.open(new_path, FileAccess.WRITE)
	if dst:
		dst.store_string(text)
		dst.close()
		print("[Migrate] ", old_path, " → ", new_path)


# ==============================================================================
# 系統設定（獨立於 NMO2.SAVE；寫入方式與存檔相同：user:// JSON）
# ==============================================================================

## 讀取系統設定並套用到 runtime（啟動時呼叫）
func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		bgm_volume = float(volume_level) / 10.0
		print("[Settings] 無設定檔，使用預設值")
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("[Settings] 設定檔解析失敗")
		return
	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return
	var lang_i: int = int(data.get("language", int(language)))
	language = Language.JA if lang_i == int(Language.JA) else Language.EN
	var mode_i: int = int(data.get("display_mode", int(display_mode)))
	mode_i = clampi(mode_i, 0, int(DisplayMode.WINDOW_540P))
	display_mode = mode_i as DisplayMode
	volume_level = clampi(int(data.get("volume_level", volume_level)), 0, 10)
	bgm_volume = float(volume_level) / 10.0
	print("[Settings] 已載入 language=", language, " display=", display_mode, " volume=", volume_level)


## 寫入系統設定（不碰 NMO2.SAVE）
func save_settings() -> void:
	var data := {
		"language": int(language),
		"display_mode": int(display_mode),
		"volume_level": volume_level,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_line(JSON.stringify(data))
		file.close()
		print("[Settings] 已記錄 language=", language, " display=", display_mode, " volume=", volume_level)


## 套用顯示模式（全螢幕／視窗 1080P／視窗 540P）
func apply_display_mode() -> void:
	match display_mode:
		DisplayMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayMode.WINDOW_1080P:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
			_center_window()
		DisplayMode.WINDOW_540P:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(960, 540))
			_center_window()


func _center_window() -> void:
	var screen: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
	var win_size: Vector2i = DisplayServer.window_get_size()
	var pos: Vector2i = (screen_size - win_size) / 2
	DisplayServer.window_set_position(pos)


## 設定顯示模式並立即記錄
func set_display_mode(mode: DisplayMode) -> void:
	display_mode = mode
	apply_display_mode()
	save_settings()


## 設定音量階數（0~10）並立即記錄
func set_volume_level(level: int) -> void:
	volume_level = clampi(level, 0, 10)
	bgm_volume = float(volume_level) / 10.0
	if _bgm_player:
		_bgm_player.volume_db = linear_to_db(maxf(bgm_volume, 0.0001)) if volume_level > 0 else -80.0
	_last_bgm_volume = bgm_volume
	save_settings()


## 設定語言並立即記錄
func set_language(lang: Language) -> void:
	if language == lang:
		return
	language = lang
	save_settings()
	language_changed.emit()
	print("[Settings] 語言切換 → ", "JA" if language == Language.JA else "EN")

	
## 初始化背景音樂播放器
func _setup_bgm():
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.stream = bgm_stream
	_bgm_player.autoplay = true
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS  # 暫停時也繼續播
	_bgm_player.volume_db = linear_to_db(bgm_volume)
	add_child(_bgm_player)
	
	# 設定循環
	if bgm_stream is AudioStreamOggVorbis:
		bgm_stream.loop = true
	elif bgm_stream is AudioStreamMP3:
		bgm_stream.loop = true
	elif bgm_stream is AudioStreamWAV:
		bgm_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
