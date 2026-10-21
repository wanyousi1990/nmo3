extends CanvasLayer
## 全遊戲唯一對話框 UI（Autoload）。
## 佔畫面下方約 1/4；左側預留約 55×55 頭像；女主發言時顯示女主頭像。
## 以 dialogue_id 從 DialogueTable 總表讀取內容；ui_accept（Z／Enter／Space）翻頁／結束。

signal dialogue_started(dialogue_id: String)
signal dialogue_finished(dialogue_id: String)
signal choice_selected(choice_index: int) ## 0=第一選項、1=第二選項

const DEFAULT_TABLE_PATH := "res://TRES/dialogue_table.tres"
const DEFAULT_HEROINE_FACE := "res://ART/OL_LARGE/OL_LAY_OK1-Face.png"

@export_group("資料")
@export var dialogue_table: DialogueTable
@export_file("*.tres") var dialogue_table_path: String = DEFAULT_TABLE_PATH

@export_group("圖層")
## 126 商店 → 127 對話／HUD → 128 轉場 → 130 暫停
@export var dialogue_canvas_layer: int = 127

@export_group("版面")
## 對話框佔可視高度比例（下方對齊）
@export_range(0.15, 0.45, 0.01) var box_height_ratio: float = 0.25
@export var box_margin_left: int = 12
@export var box_margin_right: int = 12
@export var box_margin_bottom: int = 10
@export var panel_padding: int = 10
@export var content_separation: int = 8

@export_group("頭像框")
## 頭像槽位基礎尺寸（再乘 portrait_scale）
@export var portrait_size: Vector2 = Vector2(55, 55)
## 頭像框整體縮放（含框與圖）
@export_range(0.25, 4.0, 0.05) var portrait_scale: float = 1.0
@export var portrait_bg_color: Color = Color(0.12, 0.1, 0.16, 0.95)
@export var portrait_border_color: Color = Color(0.78, 0.42, 1.0, 1.0)
@export_range(0, 6, 1) var portrait_border_width: int = 2

@export_group("女主頭像")
## 女主預設頭像貼圖（可在 Inspector 更換）
@export var heroine_portrait: Texture2D
## 是否用下方 region 裁切（關閉則顯示整張貼圖）
@export var use_heroine_portrait_region: bool = true
## Face 圖若含大片黑邊，用此區域裁切（像素）
@export var heroine_portrait_region: Rect2 = Rect2(8, 0, 120, 120)
## 頭像圖在框內的額外縮放（1=貼齊框）
@export_range(0.25, 4.0, 0.05) var heroine_portrait_scale: float = 1.0

@export_group("面板樣式")
@export var panel_bg_color: Color = Color(0.06, 0.05, 0.1, 0.92)
@export var panel_border_color: Color = Color(0.78, 0.42, 1.0, 0.85)
@export_range(0, 8, 1) var panel_border_width: int = 2
@export_range(0, 12, 1) var panel_corner_radius: int = 4

@export_group("文字")
@export var speaker_font_size: int = 14
@export var body_font_size: int = 12
@export var hint_font_size: int = 10
@export var speaker_color: Color = Color(0.92, 0.78, 1.0, 1.0)
@export var body_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var hint_color: Color = Color(0.78, 0.42, 1.0, 1.0)
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export_range(0, 8, 1) var outline_size: int = 3
@export var hint_text_en: String = "[Z] / [ENTER]"
@export var hint_text_ja: String = "[Z] / [ENTER]"

@export_group("選項（紫框游標）")
@export var choice_cursor_color: Color = Color(0.78, 0.42, 1.0, 1.0) ## 選取框邊框（同商店）
@export var choice_cursor_fill_color: Color = Color(0.55, 0.2, 0.95, 0.18) ## 選取底色淡紫（同商店 selection_fill）
@export var choice_idle_border_color: Color = Color(0.45, 0.35, 0.55, 0.55)
@export var choice_idle_fill_color: Color = Color(0.12, 0.1, 0.16, 0.45) ## 未選取底色
@export var choice_text_en_a: String = "Yes"
@export var choice_text_en_b: String = "No"
@export var choice_text_ja_a: String = "する"
@export var choice_text_ja_b: String = "しない"
@export var choice_hint_en: String = "[↑↓] [Z]"
@export var choice_hint_ja: String = "[↑↓] [Z]"

@export_group("提示位置（對話框外）")
## 相對對話框「右上角外側」的偏移（負 Y = 再往上）
@export var hint_outside_offset: Vector2 = Vector2(0, -4)

@export_group("暫停半透明")
@export_range(0.05, 1.0, 0.01) var paused_overlay_alpha: float = 0.35

@export_group("結束防誤觸")
## 對話關閉後鎖定玩家輸入的毫秒數（避免最後一擊 Z 同時觸發跳躍）
@export_range(0, 500, 1) var post_close_lock_ms: int = 150

var is_dialogue_open: bool:
	get:
		return _open

## 對話中，或剛結束的短鎖定期間：玩家不可跳／移動操控
var blocks_player_input: bool:
	get:
		return _open or _post_close_lock_left > 0.0

var _open: bool = false
var _current_id: String = ""
var _lines: Array[DialogueLine] = []
var _line_index: int = 0
var _ignore_accept_frames: int = 0
var _pending_flag_key: String = ""
var _heroine_atlas: AtlasTexture
var _post_close_lock_left: float = 0.0
var _choice_mode: bool = false
var _choice_index: int = 0
var _choice_labels: PackedStringArray = PackedStringArray()
var _choice_panels: Array[Panel] = []
var _choice_label_nodes: Array[Label] = []
var _choice_root: VBoxContainer

@onready var _root: Control = %DialogueRoot
@onready var _panel: Panel = %DialoguePanel
@onready var _content_root: Control = %ContentRoot
@onready var _portrait_frame: Panel = %PortraitFrame
@onready var _portrait: TextureRect = %PortraitRect
@onready var _text_vbox: VBoxContainer = %TextVBox
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _body_label: Label = %BodyLabel
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
	layer = dialogue_canvas_layer
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_open = false
	_ensure_table()
	_ensure_heroine_portrait()
	_ensure_choice_ui()
	_apply_panel_style()
	_apply_portrait_frame_style()
	_apply_label_styles()
	_layout_box()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.connect(_on_viewport_size_changed)
	if not GlobalState.language_changed.is_connected(_on_language_changed):
		GlobalState.language_changed.connect(_on_language_changed)
	print("DialogueBox 就緒 | 總表條目=", _table_count())


func _process(delta: float) -> void:
	if _ignore_accept_frames > 0:
		_ignore_accept_frames -= 1
	if _post_close_lock_left > 0.0:
		_post_close_lock_left = maxf(0.0, _post_close_lock_left - delta)


func _ensure_table() -> void:
	if dialogue_table != null:
		return
	if dialogue_table_path.is_empty():
		return
	if ResourceLoader.exists(dialogue_table_path):
		var res: Resource = load(dialogue_table_path)
		if res is DialogueTable:
			dialogue_table = res as DialogueTable
			print("DialogueBox 已載入總表: ", dialogue_table_path)
		else:
			push_warning("DialogueBox: 路徑不是 DialogueTable: ", dialogue_table_path)
	else:
		push_warning("DialogueBox: 找不到總表 ", dialogue_table_path)


func _ensure_heroine_portrait() -> void:
	if heroine_portrait == null and ResourceLoader.exists(DEFAULT_HEROINE_FACE):
		heroine_portrait = load(DEFAULT_HEROINE_FACE) as Texture2D
	_rebuild_heroine_atlas()


func _rebuild_heroine_atlas() -> void:
	_heroine_atlas = null
	if heroine_portrait == null:
		return
	if not use_heroine_portrait_region:
		return
	_heroine_atlas = AtlasTexture.new()
	_heroine_atlas.atlas = heroine_portrait
	_heroine_atlas.region = heroine_portrait_region


func _portrait_slot_size() -> Vector2:
	return portrait_size * maxf(portrait_scale, 0.01)


func _table_count() -> int:
	if dialogue_table == null:
		return 0
	return dialogue_table.story_entries.size() + dialogue_table.talk_entries.size()


func _is_ja() -> bool:
	return GlobalState.language == GlobalState.Language.JA


## 開始播放指定 id 的對話。flag_key 非空時，開始播放即寫入 dialogue_flags（once 劇情用）。
## allow_during_h：教學等特例允許在 H 進行中顯示對話（預設仍阻擋）。
func start(dialogue_id: String, flag_key: String = "", allow_during_h: bool = false) -> bool:
	if _open:
		print("DialogueBox: 已在對話中，忽略 start(", dialogue_id, ")")
		return false
	if GlobalState.changing_scene:
		return false
	if GlobalState.is_paused:
		return false
	if ProgressionShop.is_shop_open:
		print("DialogueBox: 商店開啟中，無法開始對話")
		return false
	if HSystem.is_h_mode_active() and not allow_during_h:
		print("DialogueBox: H 模式中，無法開始對話")
		return false
	_ensure_table()
	if dialogue_table == null:
		push_error("DialogueBox: 無 DialogueTable")
		return false
	var entry: DialogueEntry = dialogue_table.get_entry(dialogue_id)
	if entry == null:
		push_warning("DialogueBox: 找不到對話 id=", dialogue_id)
		return false
	if entry.lines.is_empty():
		push_warning("DialogueBox: 對話無內容 id=", dialogue_id)
		return false

	_current_id = dialogue_id
	_lines = entry.lines.duplicate()
	_line_index = 0
	_pending_flag_key = flag_key
	if not flag_key.is_empty():
		GlobalState.set_dialogue_flag(flag_key)

	_choice_mode = false
	_set_choice_ui_visible(false)
	_open = true
	visible = true
	_ignore_accept_frames = 2
	set_paused_dim(GlobalState.is_paused)
	_show_current_line()
	dialogue_started.emit(_current_id)
	print("DialogueBox 開始: ", _current_id, " lines=", _lines.size(), " flag=", flag_key)
	return true


func close() -> void:
	if not _open:
		return
	# 選項模式中途關閉視為取消（-1）
	if _choice_mode:
		_finish_choice(-1)
		return
	var finished_id: String = _current_id
	_open = false
	visible = false
	_lines.clear()
	_line_index = 0
	_current_id = ""
	_pending_flag_key = ""
	_portrait.texture = null
	_set_choice_ui_visible(false)
	set_paused_dim(false)
	# 關閉後短暫鎖輸入，避免同一擊 Z 觸發跳躍
	_post_close_lock_left = float(post_close_lock_ms) * 0.001
	print("DialogueBox 結束: ", finished_id, " | 防誤觸鎖=", post_close_lock_ms, "ms")
	dialogue_finished.emit(finished_id)


## 顯示二選一（紫框游標）。回傳 0=第一選項、1=第二選項、取消=-1。
## 空字串則使用 export 預設（Yes／No 或 する／しない）。
func prompt_choice(
	option_a_en: String = "",
	option_b_en: String = "",
	option_a_ja: String = "",
	option_b_ja: String = ""
) -> int:
	if _choice_mode:
		push_warning("DialogueBox: 已在選項中，忽略 prompt_choice")
		return -1
	if GlobalState.changing_scene or GlobalState.is_paused or ProgressionShop.is_shop_open:
		return -1
	_ensure_choice_ui()
	var a_en: String = option_a_en if not option_a_en.is_empty() else choice_text_en_a
	var b_en: String = option_b_en if not option_b_en.is_empty() else choice_text_en_b
	var a_ja: String = option_a_ja if not option_a_ja.is_empty() else choice_text_ja_a
	var b_ja: String = option_b_ja if not option_b_ja.is_empty() else choice_text_ja_b
	_choice_labels = PackedStringArray([
		a_ja if _is_ja() else a_en,
		b_ja if _is_ja() else b_en,
	])
	_choice_mode = true
	_choice_index = 0
	_current_id = "__choice__"
	_lines.clear()
	_line_index = 0
	_open = true
	visible = true
	_ignore_accept_frames = 2
	set_paused_dim(GlobalState.is_paused)
	_speaker_label.text = ""
	_body_label.text = ""
	_hint_label.text = choice_hint_ja if _is_ja() else choice_hint_en
	_portrait.texture = null
	_refresh_choice_labels()
	_set_choice_ui_visible(true)
	_update_choice_cursor()
	call_deferred("_deferred_layout_after_text")
	print("DialogueBox 選項: ", _choice_labels)
	var picked: int = await choice_selected
	return picked


## 暫停選單開啟／關閉時呼叫；半透明表示操控權在暫停層。
func set_paused_dim(active: bool) -> void:
	var a: float = paused_overlay_alpha if active else 1.0
	for c in get_children():
		if c is CanvasItem:
			var item: CanvasItem = c as CanvasItem
			var m: Color = item.modulate
			m.a = a
			item.modulate = m


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if GlobalState.is_paused:
		return
	if _ignore_accept_frames > 0:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("shop_open") \
				or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
			get_viewport().set_input_as_handled()
		return
	if _choice_mode:
		if event.is_action_pressed("ui_up"):
			_choice_index = maxi(0, _choice_index - 1)
			_update_choice_cursor()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_down"):
			_choice_index = mini(_choice_labels.size() - 1, _choice_index + 1)
			_update_choice_cursor()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("shop_open"):
			_finish_choice(_choice_index)
			get_viewport().set_input_as_handled()
			return
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("shop_open"):
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	_line_index += 1
	if _line_index >= _lines.size():
		close()
		return
	_show_current_line()


func _show_current_line() -> void:
	if _line_index < 0 or _line_index >= _lines.size():
		return
	var line: DialogueLine = _lines[_line_index]
	if line == null:
		_advance()
		return
	_set_choice_ui_visible(false)
	_speaker_label.text = line.speaker_ja if _is_ja() else line.speaker_en
	_body_label.text = line.text_ja if _is_ja() else line.text_en
	_hint_label.text = hint_text_ja if _is_ja() else hint_text_en
	_apply_portrait(line)
	# deferred：等 Label 換行算完再釘左上／提示外置
	call_deferred("_deferred_layout_after_text")
	print("DialogueBox 句 ", _line_index + 1, "/", _lines.size(), " speaker=", _speaker_label.text)


func _ensure_choice_ui() -> void:
	if _choice_root != null and is_instance_valid(_choice_root):
		return
	if _content_root == null:
		return
	_choice_root = VBoxContainer.new()
	_choice_root.name = "ChoiceRoot"
	_choice_root.visible = false
	_choice_root.add_theme_constant_override("separation", 6)
	_content_root.add_child(_choice_root)
	_choice_panels.clear()
	_choice_label_nodes.clear()
	for i in 2:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(160, 28)
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(lbl)
		_choice_root.add_child(panel)
		_choice_panels.append(panel)
		_choice_label_nodes.append(lbl)


func _set_choice_ui_visible(show: bool) -> void:
	if _choice_root == null:
		return
	_choice_root.visible = show
	if _text_vbox:
		_text_vbox.visible = not show


func _refresh_choice_labels() -> void:
	for i in _choice_label_nodes.size():
		var lbl: Label = _choice_label_nodes[i]
		if i < _choice_labels.size():
			lbl.text = _choice_labels[i]
		else:
			lbl.text = ""
		_style_label(lbl, body_font_size, body_color)


func _update_choice_cursor() -> void:
	for i in _choice_panels.size():
		var panel: Panel = _choice_panels[i]
		var sb := StyleBoxFlat.new()
		var selected: bool = (i == _choice_index)
		# 選取底色同商店游標淡紫；未選取用較暗底
		sb.bg_color = choice_cursor_fill_color if selected else choice_idle_fill_color
		sb.border_color = choice_cursor_color if selected else choice_idle_border_color
		sb.set_border_width_all(2 if selected else 1)
		sb.corner_radius_top_left = 2
		sb.corner_radius_top_right = 2
		sb.corner_radius_bottom_right = 2
		sb.corner_radius_bottom_left = 2
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		panel.add_theme_stylebox_override("panel", sb)


func _finish_choice(index: int) -> void:
	if not _choice_mode:
		return
	_choice_mode = false
	_set_choice_ui_visible(false)
	_open = false
	visible = false
	_current_id = ""
	_portrait.texture = null
	set_paused_dim(false)
	_post_close_lock_left = float(post_close_lock_ms) * 0.001
	print("DialogueBox 選項結果=", index)
	choice_selected.emit(index)


func _layout_choice_ui() -> void:
	if _choice_root == null or _content_root == null or not _choice_root.visible:
		return
	var slot: Vector2 = _portrait_slot_size()
	var gap: float = float(content_separation)
	var text_x: float = slot.x + gap
	var area_w: float = maxf(40.0, _content_root.size.x - text_x)
	_choice_root.position = Vector2(text_x, 4.0)
	_choice_root.size = Vector2(area_w, _content_root.size.y - 8.0)


func _deferred_layout_after_text() -> void:
	if not _open:
		return
	_layout_content()
	_layout_choice_ui()
	_layout_hint_outside()


func _apply_portrait(line: DialogueLine) -> void:
	var tex: Texture2D = null
	var img_scale: float = 1.0
	if line.portrait != null:
		tex = line.portrait
	elif line.show_heroine_portrait:
		_rebuild_heroine_atlas()
		tex = _heroine_atlas if _heroine_atlas != null else heroine_portrait
		img_scale = heroine_portrait_scale
	_portrait.texture = tex
	_portrait.visible = tex != null
	_apply_portrait_image_scale(img_scale)


func _apply_portrait_image_scale(img_scale: float) -> void:
	if _portrait == null:
		return
	if _portrait_frame:
		_portrait_frame.clip_contents = true
	var s: float = maxf(img_scale, 0.01)
	# 框內置中縮放；clip 後不會溢出框外
	_portrait.pivot_offset = _portrait.size * 0.5
	_portrait.scale = Vector2(s, s)


func _on_language_changed() -> void:
	if _open:
		_show_current_line()
	_hint_label.text = hint_text_ja if _is_ja() else hint_text_en


func _on_viewport_size_changed() -> void:
	_layout_box()


func _layout_box() -> void:
	if _root == null or _panel == null:
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var box_h: float = maxf(80.0, vs.y * box_height_ratio)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = float(box_margin_left)
	_panel.offset_right = float(-box_margin_right)
	_panel.offset_top = -box_h - float(box_margin_bottom)
	_panel.offset_bottom = float(-box_margin_bottom)
	_panel.clip_contents = true
	_layout_content()
	_layout_hint_outside()


## 頭像＋內文：固定釘在對話框內左上，多行只往下長（不用 Container 垂直置中）。
func _layout_content() -> void:
	if _content_root == null or _panel == null:
		return
	var pad: float = float(panel_padding)
	_content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_root.offset_left = pad
	_content_root.offset_top = pad
	_content_root.offset_right = -pad
	_content_root.offset_bottom = -pad

	var slot: Vector2 = _portrait_slot_size()
	if _portrait_frame:
		_portrait_frame.position = Vector2.ZERO
		_portrait_frame.size = slot
		_portrait_frame.custom_minimum_size = slot
		_portrait_frame.clip_contents = true
	if _portrait:
		_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_portrait.offset_left = 0.0
		_portrait.offset_top = 0.0
		_portrait.offset_right = 0.0
		_portrait.offset_bottom = 0.0
		if _open and _line_index >= 0 and _line_index < _lines.size():
			var cur: DialogueLine = _lines[_line_index]
			var img_s: float = heroine_portrait_scale if (cur != null and cur.show_heroine_portrait and cur.portrait == null) else 1.0
			_apply_portrait_image_scale(img_s)
		else:
			_apply_portrait_image_scale(1.0)

	if _text_vbox:
		var gap: float = float(content_separation)
		var text_x: float = slot.x + gap
		var area_w: float = maxf(40.0, _content_root.size.x - text_x)
		_text_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		_text_vbox.position = Vector2(text_x, 0.0)
		_text_vbox.size = Vector2(area_w, 0.0)
		if _speaker_label:
			_speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			_speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _body_label:
			_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_body_label.custom_minimum_size.x = area_w
		# 依內容決定高度，從頂往下長
		_text_vbox.reset_size()
		var text_h: float = _text_vbox.get_combined_minimum_size().y
		_text_vbox.size = Vector2(area_w, text_h)


## [Z]/[ENTER] 獨立節點：釘在對話框外右上，不受內文長度影響。
func _layout_hint_outside() -> void:
	if _hint_label == null or _panel == null or _root == null:
		return
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint_label.reset_size()
	var hint_sz: Vector2 = _hint_label.get_combined_minimum_size()
	if hint_sz.x < 8.0:
		hint_sz = Vector2(96.0, 16.0)
	_hint_label.size = hint_sz
	# 對齊對話框右上角外側
	var panel_rect: Rect2 = _panel.get_rect()
	var x: float = panel_rect.position.x + panel_rect.size.x - hint_sz.x + hint_outside_offset.x
	var y: float = panel_rect.position.y - hint_sz.y + hint_outside_offset.y
	_hint_label.position = Vector2(x, y)
	_hint_label.visible = _open


func _apply_panel_style() -> void:
	if _panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = panel_bg_color
	sb.border_color = panel_border_color
	sb.set_border_width_all(panel_border_width)
	var r: int = panel_corner_radius
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_right = r
	sb.corner_radius_bottom_left = r
	# 內距改由 _layout_content 的 ContentRoot offset 處理，避免 StyleBox margin 干擾
	sb.content_margin_left = 0
	sb.content_margin_top = 0
	sb.content_margin_right = 0
	sb.content_margin_bottom = 0
	_panel.add_theme_stylebox_override("panel", sb)


func _apply_portrait_frame_style() -> void:
	if _portrait_frame == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = portrait_bg_color
	sb.border_color = portrait_border_color
	sb.set_border_width_all(portrait_border_width)
	_portrait_frame.add_theme_stylebox_override("panel", sb)
	_portrait_frame.custom_minimum_size = _portrait_slot_size()


func _apply_label_styles() -> void:
	_style_label(_speaker_label, speaker_font_size, speaker_color)
	_style_label(_body_label, body_font_size, body_color)
	_style_label(_hint_label, hint_font_size, hint_color)
	_hint_label.text = hint_text_ja if _is_ja() else hint_text_en


func _style_label(lbl: Label, font_size: int, color: Color) -> void:
	if lbl == null:
		return
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", outline_color)
	lbl.add_theme_constant_override("outline_size", outline_size)
