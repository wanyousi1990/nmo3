extends CanvasLayer

# ==============================================================================
# PauseMenu
# 職責：處理遊戲暫停邏輯、發送暫停訊號以通知其他腳本（如主角）
# 修正：確保在有 LabelSettings 的情況下顏色仍能正確顯示
# ==============================================================================

# 定義訊號，讓主角或其他監聽者知道目前的暫停選單狀態
signal toggle_pause(active: bool)

@export_group("Settings")
@export_file("*.tscn") var main_menu_path: String = ""
@export var selected_color: Color = Color(1.0, 0.8, 0.0)
@export var default_color: Color = Color.WHITE

@export_group("Strings (EN)")
@export var resume_text_en: String = "Resume"
@export var back_text_en: String = "Back to Menu"
@export var settings_text_en: String = "Settings"
@export var quit_text_en: String = "Quit Game"
@export var back_to_menu_warning_en: String = "Return to main menu? Progress will be saved."
@export var quit_warning_en: String = "Quit the game?"
@export var yes_text_en: String = "YES"
@export var no_text_en: String = "NO"

@export_group("Strings (JA)")
@export var resume_text_ja: String = "再開"
@export var back_text_ja: String = "メインメニューへ"
@export var settings_text_ja: String = "設定"
@export var quit_text_ja: String = "ゲーム終了"
@export var back_to_menu_warning_ja: String = "メインメニューに戻りますか？進行はセーブされます。"
@export var quit_warning_ja: String = "ゲームを終了しますか？"
@export var yes_text_ja: String = "はい"
@export var no_text_ja: String = "いいえ"

enum MenuOption { RESUME, BACK, SETTINGS, QUIT }
enum WarnOption { YES, NO }

var current_index: int = 0
var in_warning: bool = false
var warn_index: int = 1
var pending_action: int = -1

# --- 節點引用 ---
@onready var pause_panel: Control = $PausePanel
@onready var resume_label: Label = $PausePanel/VBox/Resume
@onready var back_label: Label = $PausePanel/VBox/Back
@onready var settings_label: Label = $PausePanel/VBox/Settings
@onready var quit_label: Label = $PausePanel/VBox/Quit

@onready var warning_panel: Control = $WarningPanel
@onready var warning_text: Label = $WarningPanel/VBox/WarningText
@onready var yes_label: Label = $WarningPanel/VBox/VBox/Yes
@onready var no_label: Label = $WarningPanel/VBox/VBox/No

@onready var settings_panel = $SettingsPanel

func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if pause_panel: pause_panel.hide()
	if warning_panel: warning_panel.hide()
	if settings_panel:
		settings_panel.hide()
		if settings_panel.has_signal("closed") and not settings_panel.closed.is_connected(_on_settings_closed):
			settings_panel.closed.connect(_on_settings_closed)
	if not GlobalState.language_changed.is_connected(_on_language_changed):
		GlobalState.language_changed.connect(_on_language_changed)
	
	_apply_language()
	_update_menu_selection()
	_update_warning_selection()


func _is_ja() -> bool:
	return GlobalState.language == GlobalState.Language.JA


func _apply_language() -> void:
	var ja: bool = _is_ja()
	if resume_label:
		resume_label.text = resume_text_ja if ja else resume_text_en
	if back_label:
		back_label.text = back_text_ja if ja else back_text_en
	if settings_label:
		settings_label.text = settings_text_ja if ja else settings_text_en
	if quit_label:
		quit_label.text = quit_text_ja if ja else quit_text_en
	if yes_label:
		yes_label.text = yes_text_ja if ja else yes_text_en
	if no_label:
		no_label.text = no_text_ja if ja else no_text_en


func _on_language_changed() -> void:
	_apply_language()
	_update_menu_selection()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# 設定開啟時由 SettingsPanel 處理 Cancel
		if settings_panel and settings_panel.has_method("is_open") and settings_panel.is_open():
			return
		_handle_cancel_action()
		_consume_input()
		return

	# 注意：這裡使用 GlobalState 的變數來判斷是否消耗輸入
	if not GlobalState.is_paused:
		return

	# 設定面板開啟時不處理、也不消耗（由 SettingsPanel 先／自行處理）
	if settings_panel and settings_panel.has_method("is_open") and settings_panel.is_open():
		return

	if in_warning:
		_handle_warning_input(event)
	else:
		_handle_menu_input(event)
	
	# 強制消耗掉暫停期間的所有輸入，防止傳遞給主角
	_consume_input()

# --- 安全消耗輸入的方法 ---
func _consume_input() -> void:
	if get_viewport():
		get_viewport().set_input_as_handled()

# --- 輸入處理 ---

func _handle_cancel_action() -> void:
	if in_warning:
		_close_warning()
	elif GlobalState.is_paused:
		_resume()
	else:
		_open_pause()

func _handle_menu_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		current_index = posmod(current_index - 1, 4)
		_update_menu_selection()
	elif event.is_action_pressed("ui_down"):
		current_index = posmod(current_index + 1, 4)
		_update_menu_selection()
	elif _is_confirm_pressed(event):
		_confirm_selection()

func _handle_warning_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or \
	   event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		warn_index = 1 - warn_index
		_update_warning_selection()
	elif _is_confirm_pressed(event):
		if warn_index == WarnOption.YES:
			_execute_action()
		else:
			_close_warning()

func _is_confirm_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or \
		   (event is InputEventKey and event.keycode == KEY_Z and event.pressed)

# --- 邏輯執行 ---

func _open_pause() -> void:
	GlobalState.is_paused = true
	current_index = 0
	in_warning = false
	_apply_language()
	if pause_panel: pause_panel.show()
	if warning_panel: warning_panel.hide()
	if settings_panel: settings_panel.hide()
	get_tree().paused = true
	# 商店／對話仍開啟時半透明，表示操控權在暫停選單
	if ProgressionShop.is_shop_open:
		ProgressionShop.set_paused_dim(true)
	if DialogueBox.is_dialogue_open:
		DialogueBox.set_paused_dim(true)
	
	toggle_pause.emit(true)
	_update_menu_selection()

func _resume() -> void:
	if pause_panel: pause_panel.hide()
	if warning_panel: warning_panel.hide()
	if settings_panel and settings_panel.has_method("force_hide"):
		settings_panel.force_hide()
	elif settings_panel:
		settings_panel.hide()
	get_tree().paused = false
	
	# 延遲一幀釋放全域暫停狀態，避免當前幀的 Z 鍵觸發主角跳躍
	await get_tree().process_frame
	
	GlobalState.is_paused = false
	in_warning = false
	if ProgressionShop.is_shop_open:
		ProgressionShop.set_paused_dim(false)
	if DialogueBox.is_dialogue_open:
		DialogueBox.set_paused_dim(false)
	
	toggle_pause.emit(false)

func _confirm_selection() -> void:
	match current_index:
		MenuOption.RESUME:
			_resume()
		MenuOption.BACK:
			pending_action = MenuOption.BACK
			_open_warning(back_to_menu_warning_ja if _is_ja() else back_to_menu_warning_en)
		MenuOption.SETTINGS:
			_open_settings()
		MenuOption.QUIT:
			pending_action = MenuOption.QUIT
			_open_warning(quit_warning_ja if _is_ja() else quit_warning_en)

func _open_settings() -> void:
	if pause_panel:
		pause_panel.modulate.a = 0.2
	if settings_panel and settings_panel.has_method("open"):
		settings_panel.open()

func _on_settings_closed() -> void:
	if pause_panel:
		pause_panel.modulate.a = 1.0
		pause_panel.show()
	_apply_language()
	_update_menu_selection()

func _open_warning(text_content: String) -> void:
	in_warning = true
	warn_index = WarnOption.NO
	if warning_text: warning_text.text = text_content
	if warning_panel: warning_panel.show()
	_update_warning_selection()

func _close_warning() -> void:
	in_warning = false
	if warning_panel: warning_panel.hide()
	_update_menu_selection()

func _execute_action() -> void:
	match pending_action:
		MenuOption.BACK:
			if pause_panel: pause_panel.hide()
			if warning_panel: warning_panel.hide()
			GlobalState.from_pause = true
			GlobalState.is_paused = false
			if ProgressionShop.is_shop_open:
				ProgressionShop.close_shop()
			if DialogueBox.is_dialogue_open:
				DialogueBox.close()
			# 回主選單前清暫態；change_scene 仍會寫入當前存檔供 Continue
			GlobalState.prepare_for_main_menu()
			GlobalState.from_pause = true
			if GlobalState.has_method("change_scene"):
				GlobalState.change_scene(main_menu_path)
			else:
				get_tree().change_scene_to_file(main_menu_path)
				
		MenuOption.QUIT:
			get_tree().quit()

# --- UI 更新 ---

# 輔助函式：確保顏色能穿透 LabelSettings 或是 Theme
func _set_label_color(label: Label, color: Color) -> void:
	if not label: return
	
	# 如果有使用 LabelSettings，直接修改 Settings 的顏色 (注意：這會影響所有共用此 Settings 的 Label)
	# 如果不希望連動，建議在編輯器將每個 Label 的 LabelSettings 設為 "Make Unique"
	if label.label_settings:
		label.label_settings.font_color = color
	else:
		# 如果沒有 LabelSettings，使用標準的 Theme Override
		label.add_theme_color_override("font_color", color)

func _update_menu_selection() -> void:
	var show_select = not in_warning
	var settings_open: bool = settings_panel and settings_panel.has_method("is_open") and settings_panel.is_open()
	if settings_open:
		show_select = false
	
	_set_label_color(resume_label, selected_color if (current_index == MenuOption.RESUME and show_select) else default_color)
	_set_label_color(back_label, selected_color if (current_index == MenuOption.BACK and show_select) else default_color)
	_set_label_color(settings_label, selected_color if (current_index == MenuOption.SETTINGS and show_select) else default_color)
	_set_label_color(quit_label, selected_color if (current_index == MenuOption.QUIT and show_select) else default_color)

func _update_warning_selection() -> void:
	_set_label_color(yes_label, selected_color if warn_index == WarnOption.YES else default_color)
	_set_label_color(no_label, selected_color if warn_index == WarnOption.NO else default_color)
