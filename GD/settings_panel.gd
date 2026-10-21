extends Panel
## 共用「設定」面板：顯示／語言／音量／Back，左右調整；變更即寫入 user://NMO2.SETTING（與存檔分離）

signal closed

@export_group("視覺")
@export var selected_color: Color = Color(0.847059, 0.501961, 1, 1)
@export var default_color: Color = Color.WHITE
## 半透明黑底不透明度（僅該版面，非全螢幕）
@export_range(0.0, 1.0, 0.05) var panel_alpha: float = 0.5
## 紫框（與對話框一致）
@export var panel_border_color: Color = Color(0.78, 0.42, 1.0, 0.85)
@export_range(0, 8, 1) var panel_border_width: int = 2
@export_range(0, 12, 1) var panel_corner_radius: int = 4

@export_group("Strings (EN)")
@export var label_display_en: String = "Display"
@export var label_language_en: String = "Language"
@export var label_volume_en: String = "Volume"
@export var label_back_en: String = "Back"
@export var val_fullscreen_en: String = "Fullscreen"
@export var val_window_1080_en: String = "Window 1080P"
@export var val_window_540_en: String = "Window 540P"
@export var val_ja_en: String = "Japanese"
@export var val_en_en: String = "English"

@export_group("Strings (JA)")
@export var label_display_ja: String = "表示"
@export var label_language_ja: String = "言語"
@export var label_volume_ja: String = "音量"
@export var label_back_ja: String = "戻る"
@export var val_fullscreen_ja: String = "フルスクリーン"
@export var val_window_1080_ja: String = "ウィンドウ1080P"
@export var val_window_540_ja: String = "ウィンドウ540P"
@export var val_ja_ja: String = "日本語"
@export var val_en_ja: String = "英語"

enum Option { DISPLAY, LANGUAGE, VOLUME, BACK }

var _index: int = 0
var _active: bool = false

@onready var display_label: Label = $VBox/Display
@onready var language_label: Label = $VBox/Language
@onready var volume_label: Label = $VBox/Volume
@onready var back_label: Label = $VBox/Back


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_panel_style()
	hide()
	_active = false


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, panel_alpha)
	style.border_color = panel_border_color
	style.set_border_width_all(panel_border_width)
	var r: int = panel_corner_radius
	style.corner_radius_top_left = r
	style.corner_radius_top_right = r
	style.corner_radius_bottom_right = r
	style.corner_radius_bottom_left = r
	add_theme_stylebox_override("panel", style)


func open() -> void:
	_index = 0
	_active = true
	_apply_panel_style()
	show()
	_refresh_texts()
	_update_selection()
	print("[SettingsPanel] 開啟設定")


func close() -> void:
	if not _active:
		return
	_active = false
	hide()
	closed.emit()
	print("[SettingsPanel] 關閉設定")


## 強制關閉且不發 closed（例如暫停選單直接 Resume）
func force_hide() -> void:
	_active = false
	hide()


func is_open() -> bool:
	return _active


func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		_consume()
		return

	if event.is_action_pressed("ui_up"):
		_index = posmod(_index - 1, 4)
		_update_selection()
		_consume()
	elif event.is_action_pressed("ui_down"):
		_index = posmod(_index + 1, 4)
		_update_selection()
		_consume()
	elif event.is_action_pressed("ui_left"):
		if _index != Option.BACK:
			_adjust(-1)
		_consume()
	elif event.is_action_pressed("ui_right"):
		if _index != Option.BACK:
			_adjust(1)
		_consume()
	elif event.is_action_pressed("ui_accept") or \
			(event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Z):
		# Back 選中時確認＝與 Esc 相同；其餘確認鍵僅消耗輸入
		if _index == Option.BACK:
			close()
		_consume()


func _consume() -> void:
	if get_viewport():
		get_viewport().set_input_as_handled()


func _is_ja() -> bool:
	return GlobalState.language == GlobalState.Language.JA


func _adjust(dir: int) -> void:
	match _index:
		Option.DISPLAY:
			var modes: Array = [
				GlobalState.DisplayMode.FULLSCREEN,
				GlobalState.DisplayMode.WINDOW_1080P,
				GlobalState.DisplayMode.WINDOW_540P,
			]
			var cur: int = modes.find(GlobalState.display_mode)
			if cur < 0:
				cur = 1
			cur = posmod(cur + dir, modes.size())
			GlobalState.set_display_mode(modes[cur])
		Option.LANGUAGE:
			# 順序：日文 → 英文
			var langs: Array = [GlobalState.Language.JA, GlobalState.Language.EN]
			var cur_l: int = langs.find(GlobalState.language)
			if cur_l < 0:
				cur_l = 0
			cur_l = posmod(cur_l + dir, langs.size())
			GlobalState.set_language(langs[cur_l])
		Option.VOLUME:
			GlobalState.set_volume_level(GlobalState.volume_level + dir)
		Option.BACK:
			return
	_refresh_texts()
	_update_selection()


func _refresh_texts() -> void:
	var ja: bool = _is_ja()
	var disp_name: String = label_display_ja if ja else label_display_en
	var lang_name: String = label_language_ja if ja else label_language_en
	var vol_name: String = label_volume_ja if ja else label_volume_en
	var back_name: String = label_back_ja if ja else label_back_en

	var disp_val: String
	match GlobalState.display_mode:
		GlobalState.DisplayMode.FULLSCREEN:
			disp_val = val_fullscreen_ja if ja else val_fullscreen_en
		GlobalState.DisplayMode.WINDOW_1080P:
			disp_val = val_window_1080_ja if ja else val_window_1080_en
		_:
			disp_val = val_window_540_ja if ja else val_window_540_en

	var lang_val: String
	if GlobalState.language == GlobalState.Language.JA:
		lang_val = val_ja_ja if ja else val_ja_en
	else:
		lang_val = val_en_ja if ja else val_en_en

	if display_label:
		display_label.text = "%s: < %s >" % [disp_name, disp_val]
	if language_label:
		language_label.text = "%s: < %s >" % [lang_name, lang_val]
	if volume_label:
		volume_label.text = "%s: < %d >" % [vol_name, GlobalState.volume_level]
	if back_label:
		back_label.text = back_name


func _set_label_color(label: Label, color: Color) -> void:
	if not label:
		return
	if label.label_settings:
		label.label_settings.font_color = color
	else:
		label.add_theme_color_override("font_color", color)


func _update_selection() -> void:
	_set_label_color(display_label, selected_color if _index == Option.DISPLAY else default_color)
	_set_label_color(language_label, selected_color if _index == Option.LANGUAGE else default_color)
	_set_label_color(volume_label, selected_color if _index == Option.VOLUME else default_color)
	_set_label_color(back_label, selected_color if _index == Option.BACK else default_color)
