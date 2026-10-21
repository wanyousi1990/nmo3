extends Control

# 選項定義
enum MenuState { MAIN, CONFIRM, SETTINGS, BUSY }
var current_state: MenuState = MenuState.MAIN

# --- 可編輯參數 (Export) ---

@export_group("視覺顏色設定")
## 當選項被選中時的顏色
@export var color_selected: Color = Color.YELLOW
## 未選中時的基礎顏色
@export var color_normal: Color = Color.WHITE
## 無法選擇 (如無存檔) 時的顏色
@export var color_disabled: Color = Color.GRAY
## 無法選擇時的透明度
@export var disabled_alpha: float = 0.3

@export_group("Menu Text (EN)")
@export var text_continue_en: String = "Continue"
@export var text_new_game_en: String = "New Game"
@export var text_settings_en: String = "Settings"
@export var text_quit_en: String = "Quit"
@export var text_confirm_continue_en: String = "Continue the game?"
@export_multiline var text_confirm_new_game_en: String = "Start a new game?\n(Warning: existing save will be lost!)"
@export var text_confirm_quit_en: String = "Quit the game?"
@export var text_confirm_btn_en: String = "Confirm"
@export var text_cancel_btn_en: String = "Cancel"

@export_group("Menu Text (JA)")
@export var text_continue_ja: String = "つづきから"
@export var text_new_game_ja: String = "はじめから"
@export var text_settings_ja: String = "設定"
@export var text_quit_ja: String = "終了"
@export var text_confirm_continue_ja: String = "ゲームを再開しますか？"
@export_multiline var text_confirm_new_game_ja: String = "新しいゲームを始めますか？\n（注意：既存のセーブデータは消えます！）"
@export var text_confirm_quit_ja: String = "ゲームを終了しますか？"
@export var text_confirm_btn_ja: String = "決定"
@export var text_cancel_btn_ja: String = "キャンセル"

@export_group("路徑設定")
## 新遊戲或找不到存檔場景時的預設起始場景
@export_file("*.tscn") var default_start_scene: String = ""

@export_group("主選單背景疊圖")
## 主選單最上層 MENU 圖的不透明度（降低可透出下層女主立繪）
@export_range(0.0, 1.0, 0.05) var main_menu_texture_overlay_alpha: float = 1.0

# --- 內部變數 ---

# 主選單索引：Continue / New Game / Settings / Quit
var main_index: int = 0
var main_options: Array[String] = ["Continue", "New Game", "Settings", "Quit"]

# 確認選單索引
var confirm_index: int = 1
var confirm_options: Array[String] = ["Confirm", "Cancel"]

# 節點引用
@onready var main_menu_container = $MainMenuContainer
@onready var confirm_dialog = $ConfirmDialog
@onready var confirm_label = $ConfirmDialog/MessageLabel
@onready var _backdrop_texture_rect: TextureRect = $TextureRect
@onready var settings_panel = $SettingsPanel

func _is_ja() -> bool:
	return GlobalState.language == GlobalState.Language.JA


func _apply_language() -> void:
	var ja: bool = _is_ja()
	main_options = [
		text_continue_ja if ja else text_continue_en,
		text_new_game_ja if ja else text_new_game_en,
		text_settings_ja if ja else text_settings_en,
		text_quit_ja if ja else text_quit_en,
	]
	confirm_options = [
		text_confirm_btn_ja if ja else text_confirm_btn_en,
		text_cancel_btn_ja if ja else text_cancel_btn_en,
	]
	for i in main_menu_container.get_child_count():
		var label: Label = main_menu_container.get_child(i) as Label
		if label and i < main_options.size():
			label.text = main_options[i]
	var btn_container = $ConfirmDialog/ButtonContainer
	if btn_container:
		for i in btn_container.get_child_count():
			var label: Label = btn_container.get_child(i) as Label
			if label and i < confirm_options.size():
				label.text = confirm_options[i]


func _ready():
	_fix_ui_layout()
	
	if _backdrop_texture_rect:
		_backdrop_texture_rect.modulate.a = main_menu_texture_overlay_alpha
	
	GlobalState.peek_save_for_main_menu()
	var heroine: Node = get_node_or_null("HeroinMenuVisual")
	if heroine and heroine.has_method("refresh_from_global_state"):
		heroine.call("refresh_from_global_state")
	
	if not FileAccess.file_exists(GlobalState.SAVE_PATH):
		main_index = 1
	
	if settings_panel and settings_panel.has_signal("closed"):
		if not settings_panel.closed.is_connected(_on_settings_closed):
			settings_panel.closed.connect(_on_settings_closed)
	if not GlobalState.language_changed.is_connected(_on_language_changed):
		GlobalState.language_changed.connect(_on_language_changed)
	
	_apply_language()
	_update_menu_visuals()
	confirm_dialog.hide()
	if settings_panel:
		settings_panel.hide()
	HSystem.show_h_stats_ui = false

func _fix_ui_layout():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = get_viewport_rect().size

func _input(event):
	# 轉場／執行中鎖定，避免確定後仍可移動游標
	if current_state == MenuState.BUSY:
		if get_viewport():
			get_viewport().set_input_as_handled()
		return
	# 設定面板開啟時由 SettingsPanel 自行處理
	if current_state == MenuState.SETTINGS:
		return
	if event.is_action_pressed("ui_cancel") and current_state == MenuState.CONFIRM:
		_back_to_main()
		return
	if event.is_action_pressed("ui_up"):
		_navigate(-1)
	elif event.is_action_pressed("ui_down"):
		_navigate(1)
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_Z and event.pressed):
		await _select()

func _navigate(dir: int):
	if current_state == MenuState.MAIN:
		var next_index = posmod(main_index + dir, main_options.size())
		
		# 邏輯鎖定：如果沒有存檔且移動到了 Continue (0)，則跳過它
		if next_index == 0 and not FileAccess.file_exists(GlobalState.SAVE_PATH):
			# 根據移動方向再跳一格
			main_index = posmod(next_index + dir, main_options.size())
		else:
			main_index = next_index
			
	elif current_state == MenuState.CONFIRM:
		confirm_index = posmod(confirm_index + dir, confirm_options.size())
	
	_update_menu_visuals()

func _select():
	if current_state == MenuState.MAIN:
		# 雙重保險：如果當前是 Continue 且沒存檔，不允許進入確認視窗
		if main_index == 0 and not FileAccess.file_exists(GlobalState.SAVE_PATH):
			return
		# Settings：直接開啟設定面板（不經確認）
		if main_index == 2:
			_open_settings()
			return
			
		current_state = MenuState.CONFIRM
		confirm_index = 1 
		_show_confirm_dialog()
	elif current_state == MenuState.CONFIRM:
		if confirm_index == 0:
			await _execute_main_option()
		else:
			_back_to_main()

func _open_settings() -> void:
	current_state = MenuState.SETTINGS
	main_menu_container.modulate.a = 0.2
	if settings_panel and settings_panel.has_method("open"):
		settings_panel.open()

func _on_settings_closed() -> void:
	current_state = MenuState.MAIN
	main_menu_container.modulate.a = 1.0
	_apply_language()
	_update_menu_visuals()

func _on_language_changed() -> void:
	_apply_language()
	_update_menu_visuals()

func _update_menu_visuals():
	# 主選單視覺處理
	var has_save = FileAccess.file_exists(GlobalState.SAVE_PATH)
	
	for i in main_menu_container.get_child_count():
		var label = main_menu_container.get_child(i)
		
		# 處理 Continue (索引 0) 的特殊外觀
		if i == 0 and not has_save:
			label.modulate = color_disabled
			label.modulate.a = disabled_alpha
		else:
			# 選中項應用選中顏色，其餘應用一般顏色
			label.modulate = color_selected if i == main_index else color_normal
			label.modulate.a = 1.0
	
	# 確認選單視覺
	if confirm_dialog.visible:
		var btn_container = $ConfirmDialog/ButtonContainer
		for i in btn_container.get_child_count():
			var btn = btn_container.get_child(i)
			btn.modulate = color_selected if i == confirm_index else color_normal

func _show_confirm_dialog():
	main_menu_container.modulate.a = 0.2 
	confirm_dialog.show()
	var ja: bool = _is_ja()
	match main_index:
		0: confirm_label.text = text_confirm_continue_ja if ja else text_confirm_continue_en
		1: confirm_label.text = text_confirm_new_game_ja if ja else text_confirm_new_game_en
		3: confirm_label.text = text_confirm_quit_ja if ja else text_confirm_quit_en
	_update_menu_visuals()

func _back_to_main():
	current_state = MenuState.MAIN
	confirm_dialog.hide()
	main_menu_container.modulate.a = 1.0

func _execute_main_option():
	# 一按下確定就鎖定輸入，避免轉場期間仍可選單
	current_state = MenuState.BUSY
	if confirm_dialog:
		confirm_dialog.hide()
	match main_index:
		0: 
			GlobalState.load_game()
			await _start_loading_save()
		1: 
			await GlobalState.reset_game()
		3: 
			get_tree().quit()

func _start_loading_save() -> void:
	var file = FileAccess.open(GlobalState.SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		json.parse(file.get_as_text())
		var data = json.get_data()
		
		# 1. 先從存檔提取目標位置 ID (這步最重要！)
		GlobalState.target_door_id = data.get("target_door_id", "")
		
		# 2. 再切換場景
		var path = data.get("current_scene", default_start_scene)
		await GlobalState.change_scene(path, 0.5, 0.5, Color.BLACK, true, true, true)
