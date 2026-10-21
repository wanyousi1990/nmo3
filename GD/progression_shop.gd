extends CanvasLayer
## 進度商店：覆蓋在畫面上，不換場景。方向鍵選格、Z（ui_accept）確認；**最下列「離開商店」**關閉（不使用 Esc，避免與暫停衝突）。
## 開啟時由 OL_Character 阻擋移動；靠近觸發區請用 **shop_open**（預設 Enter）開啟。
##
## 已購買旗標寫入 GlobalState.progression_owned，鍵名格式：
## hp_1 ~ hp_9, horny_1 ~ horny_9, semen_1 ~ semen_9,
## lewd_state, lewd_state_plus, paizuri_1, paizuri_2, paizuri_3
## 第0列消耗品（heal_hp_s/l、cool_horny_s/l）可重複購買，不寫入 progression_owned。

signal shop_opened
signal shop_closed

const STAT_COLS: int = 9
const CONSUMABLE_ROW_INDEX: int = 0
const EXIT_ROW_INDEX: int = 6
const ROW_COUNT: int = 7
const COLS_PER_ROW: Array[int] = [4, 9, 9, 9, 2, 3, 1]
const KEY_EXIT_SHOP := "__exit_shop__"

const KEY_HEAL_HP_S := "heal_hp_s"
const KEY_HEAL_HP_L := "heal_hp_l"
const KEY_COOL_HORNY_S := "cool_horny_s"
const KEY_COOL_HORNY_L := "cool_horny_l"

const KEY_LEWD_STATE := "lewd_state"
const KEY_LEWD_STATE_PLUS := "lewd_state_plus"
const KEY_PAIZURI_1 := "paizuri_1"
const KEY_PAIZURI_2 := "paizuri_2"
const KEY_PAIZURI_3 := "paizuri_3"

enum _UiState { BROWSE, CONFIRM }

@export var shop_canvas_layer: int = 126

@export_group("第1列 · 消耗品（可重複購買）")
@export var heal_hp_small: float = 20.0
@export var heal_hp_large: float = 50.0
@export var cool_horny_small: float = 20.0
@export var cool_horny_large: float = 50.0
@export var cost_heal_hp_s: float = 15.0
@export var cost_heal_hp_l: float = 35.0
@export var cost_cool_horny_s: float = 15.0
@export var cost_cool_horny_l: float = 35.0

@export_group("第2列 · HP（9段）")
## 每段增加的 HP 上限（陣列長度 9）
@export var hp_values: Array[float] = [10, 10, 15, 15, 20, 20, 25, 25, 30]
## 每段花費的 Semen（陣列長度 9）
@export var hp_costs: Array[float] = [20, 30, 40, 55, 70, 90, 110, 135, 160]

@export_group("第3列 · Horny（9段）")
@export var horny_values: Array[float] = [10, 10, 15, 15, 20, 20, 25, 25, 30]
@export var horny_costs: Array[float] = [20, 30, 40, 55, 70, 90, 110, 135, 160]

@export_group("第4列 · Semen 容量（9段）")
@export var semen_values: Array[float] = [50, 50, 80, 80, 100, 100, 150, 150, 200]
@export var semen_costs: Array[float] = [25, 35, 50, 65, 85, 105, 130, 160, 195]

@export_group("第5列 · 淫亂狀態")
@export var cost_lewd_state: float = 200.0
@export_multiline var desc_lewd_state_en: String = "Unlock Lewd State.\nHP damage at ejaculation ×2.\nSemen gain at Slow / Medium / Fast / Ejaculation ×1.5.\nEscape difficulty +0.25 per Horny."
@export_multiline var desc_lewd_state_ja: String = "淫乱状態を解放する。\n射精時のHPダメージ×2。\nSemen獲得が遅／中／速／射精で×1.5。\nHorny1あたりの脱出難易度+0.25。"
@export var cost_lewd_state_plus: float = 150.0
@export_multiline var desc_lewd_state_plus_en: String = "Lewd State+.\nPress [S] to toggle Clothed / Naked anytime."
@export_multiline var desc_lewd_state_plus_ja: String = "淫乱状態+。\n[S]キーでいつでも着衣／裸体を切り替えられる。"

@export_group("第6列 · 乳交")
@export var cost_paizuri_1: float = 100.0
@export var cost_paizuri_2: float = 180.0
@export var cost_paizuri_3: float = 260.0
@export_multiline var desc_paizuri_1_en: String = "Unlock Paizuri 1."
@export_multiline var desc_paizuri_1_ja: String = "パイズリ1を解放する。"
@export_multiline var desc_paizuri_2_en: String = "Unlock Paizuri 2."
@export_multiline var desc_paizuri_2_ja: String = "パイズリ2を解放する。"
@export_multiline var desc_paizuri_3_en: String = "Unlock Paizuri 3."
@export_multiline var desc_paizuri_3_ja: String = "パイズリ3を解放する。"

@export_group("介面")
@export var slot_size: Vector2 = Vector2(48, 48)
## 商店頁頂部預留高度，避免擋到 HSystem 的 HP／Horny／Semen HUD
@export var hud_top_reserve: float = 96.0
@export var shop_scroll_min_height: float = 120.0
## 左欄商品區佔可視高度的比例（已扣除頂部 HUD 預留）
@export_range(0.15, 0.85, 0.01) var shop_scroll_height_ratio: float = 0.55
@export var selection_border_color: Color = Color(0.78, 0.42, 1.0, 1.0)
@export_range(1, 10, 1) var selection_border_width: int = 4
@export var selection_fill_color: Color = Color(0.55, 0.2, 0.95, 0.18)
@export_range(0, 12, 1) var selection_corner_radius: int = 2
@export var locked_modulate: Color = Color(0.45, 0.45, 0.48, 0.85)
## 已購格子的底色（只染 Panel，不染圖示）
@export var bought_bg_color: Color = Color(0.25, 0.55, 0.28, 0.85)
@export var normal_modulate: Color = Color(1, 1, 1, 1)
## 暫停選單開啟時，商店頁整體透明度（表示操控權在暫停層）
@export_range(0.05, 1.0, 0.01) var paused_overlay_alpha: float = 0.35

var is_shop_open: bool:
	get:
		return _open

var _open: bool = false
var _ui_state: _UiState = _UiState.BROWSE
var _sel_row: int = 0
var _sel_col: int = 0
var _confirm_yes: bool = true

var _slots: Array[Panel] = []
var _selection_stylebox: StyleBoxFlat
var _bought_stylebox: StyleBoxFlat

@onready var _dim: ColorRect = %DimRect
@onready var _shop_root: Control = %ShopRoot
@onready var _info_label: Label = %InfoLabel
@onready var _hint_label: Label = %HintLabel
@onready var _rows_vbox: VBoxContainer = %RowsVBox
@onready var _shop_scroll: ScrollContainer = %ShopScroll
@onready var _exit_shop_panel: Panel = %ExitShopPanel
@onready var _exit_label: Label = %ExitLabel
@onready var _confirm_root: Control = %ConfirmRoot
@onready var _confirm_title: Label = %ConfirmTitle
@onready var _confirm_yes_lbl: Label = %ConfirmYesLabel
@onready var _confirm_no_lbl: Label = %ConfirmNoLabel


func _ready() -> void:
	layer = shop_canvas_layer
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_open = false
	_collect_slots()
	_update_hint_label()
	_confirm_root.visible = false
	_apply_hud_top_reserve()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.connect(_on_viewport_size_changed)
	_sync_selection_stylebox()


func _apply_hud_top_reserve() -> void:
	if _shop_root == null:
		return
	_shop_root.add_theme_constant_override("margin_top", maxi(0, int(hud_top_reserve)))


func _update_exit_label() -> void:
	if _exit_label == null:
		return
	_exit_label.text = "ショップを出る" if _is_ja() else "Exit Shop"


func _update_hint_label() -> void:
	if _hint_label == null:
		return
	if _is_ja():
		_hint_label.text = "方向キーで選択　Zで購入確認　最下段「ショップを出る」で閉じる"
	else:
		_hint_label.text = "Arrow keys to select | Z to confirm | Bottom row: Exit Shop"


func _sync_selection_stylebox() -> void:
	if _selection_stylebox == null:
		_selection_stylebox = StyleBoxFlat.new()
	var w: int = clampi(selection_border_width, 1, 12)
	var r: int = clampi(selection_corner_radius, 0, 16)
	_selection_stylebox.bg_color = selection_fill_color
	_selection_stylebox.border_color = selection_border_color
	_selection_stylebox.set_border_width_all(w)
	_selection_stylebox.corner_radius_top_left = r
	_selection_stylebox.corner_radius_top_right = r
	_selection_stylebox.corner_radius_bottom_right = r
	_selection_stylebox.corner_radius_bottom_left = r
	if _bought_stylebox == null:
		_bought_stylebox = StyleBoxFlat.new()
	_bought_stylebox.bg_color = bought_bg_color
	_bought_stylebox.border_color = Color(0, 0, 0, 0)
	_bought_stylebox.set_border_width_all(0)
	_bought_stylebox.corner_radius_top_left = r
	_bought_stylebox.corner_radius_top_right = r
	_bought_stylebox.corner_radius_bottom_right = r
	_bought_stylebox.corner_radius_bottom_left = r


func _apply_slot_panel_style(p: Panel, sel: bool, owned: bool, unlocked: bool = true) -> void:
	if sel:
		if owned:
			_selection_stylebox.bg_color = bought_bg_color
			_selection_stylebox.border_color = selection_border_color
		elif not unlocked:
			# 未解鎖：游標框與底一併變灰暗
			_selection_stylebox.bg_color = selection_fill_color * locked_modulate
			_selection_stylebox.border_color = selection_border_color * locked_modulate
		else:
			_selection_stylebox.bg_color = selection_fill_color
			_selection_stylebox.border_color = selection_border_color
		p.add_theme_stylebox_override("panel", _selection_stylebox)
	elif owned:
		p.add_theme_stylebox_override("panel", _bought_stylebox)
	else:
		p.remove_theme_stylebox_override("panel")


func _set_slot_icon_modulate(p: Panel, color: Color) -> void:
	var tex: CanvasItem = p.get_node_or_null("ItemTexture") as CanvasItem
	if tex:
		tex.modulate = color


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp and vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.disconnect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	if _open:
		_apply_shop_scroll_height()
		call_deferred("_deferred_scroll_to_selection")


func _collect_slots() -> void:
	_slots.clear()
	if _rows_vbox == null:
		push_error("ProgressionShop: 找不到 %RowsVBox")
		return
	for row_i in range(_rows_vbox.get_child_count()):
		var row_node: Node = _rows_vbox.get_child(row_i)
		if not (row_node is HBoxContainer):
			continue
		var h: HBoxContainer = row_node as HBoxContainer
		for c in h.get_children():
			if c is Panel:
				_slots.append(c as Panel)
	if _exit_shop_panel and _slots.find(_exit_shop_panel) < 0:
		_slots.append(_exit_shop_panel)
	var total_expected: int = 0
	for c in COLS_PER_ROW:
		total_expected += c
	if _slots.size() != total_expected:
		push_warning("ProgressionShop: 格數應為 %d，目前為 %d" % [total_expected, _slots.size()])


func open_shop() -> void:
	if _open:
		return
	if GlobalState.changing_scene:
		return
	if DialogueBox.is_dialogue_open:
		return
	_open = true
	visible = true
	_ui_state = _UiState.BROWSE
	_confirm_root.visible = false
	_sel_row = 0
	_sel_col = 0
	_clamp_cursor()
	_update_hint_label()
	_update_exit_label()
	_refresh_info()
	_refresh_slots_visual()
	_apply_shop_scroll_height()
	set_paused_dim(GlobalState.is_paused)
	call_deferred("_deferred_scroll_to_selection")
	shop_opened.emit()


func close_shop() -> void:
	if not _open:
		return
	visible = false
	_ui_state = _UiState.BROWSE
	_confirm_root.visible = false
	set_paused_dim(false)
	_deferred_close_open_flag()


## 暫停選單開啟／關閉時由 PauseMenu 呼叫；商店整體半透明表示操控權在暫停層。
func set_paused_dim(active: bool) -> void:
	var a: float = paused_overlay_alpha if active else 1.0
	for c in get_children():
		if c is CanvasItem:
			var item: CanvasItem = c as CanvasItem
			var m: Color = item.modulate
			m.a = a
			item.modulate = m


func _deferred_close_open_flag() -> void:
	await get_tree().process_frame
	_open = false
	shop_closed.emit()


func _apply_shop_scroll_height() -> void:
	if _shop_scroll == null:
		return
	_apply_hud_top_reserve()
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var available_h: float = maxf(0.0, vs.y - hud_top_reserve)
	var h: float = clampf(available_h * shop_scroll_height_ratio, shop_scroll_min_height, available_h * 0.85)
	_shop_scroll.custom_minimum_size.y = h


func _deferred_scroll_to_selection() -> void:
	if not _open or _shop_scroll == null:
		return
	if _sel_row == EXIT_ROW_INDEX:
		var sb: ScrollBar = _shop_scroll.get_v_scroll_bar()
		if sb and is_instance_valid(sb):
			_shop_scroll.scroll_vertical = int(sb.max_value)
		return
	var fi: int = _flat_index(_sel_row, _sel_col)
	if fi >= 0 and fi < _slots.size():
		var cell: Control = _slots[fi]
		if cell and is_instance_valid(cell):
			_shop_scroll.ensure_control_visible(cell)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	# 暫停中操控權在暫停選單，商店不處理輸入
	if GlobalState.is_paused:
		return

	if _ui_state == _UiState.CONFIRM:
		_input_confirm(event)
		return

	if event.is_action_pressed("ui_left"):
		_move_cursor(-1, 0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_move_cursor(1, 0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_move_cursor(0, -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_cursor(0, 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_try_begin_confirm()
		get_viewport().set_input_as_handled()


func _input_confirm(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_confirm_yes = true
		_refresh_confirm_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_confirm_yes = false
		_refresh_confirm_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		_confirm_yes = not _confirm_yes
		_refresh_confirm_labels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _confirm_yes:
			_do_purchase_at_cursor()
		_ui_state = _UiState.BROWSE
		_confirm_root.visible = false
		_refresh_slots_visual()
		_refresh_info()
		get_viewport().set_input_as_handled()
		call_deferred("_deferred_scroll_to_selection")


func _move_cursor(dx: int, dy: int) -> void:
	# 上下／左右循環：最上再上 → Exit Shop；最左再左 → 該列最右
	# 換列時欄位採絕對位置（同 col，超出則夾到該列最右），不做比例映射
	if dy != 0:
		_sel_row = posmod(_sel_row + dy, ROW_COUNT)
		_sel_col = mini(_sel_col, COLS_PER_ROW[_sel_row] - 1)
	if dx != 0:
		var cols: int = COLS_PER_ROW[_sel_row]
		_sel_col = posmod(_sel_col + dx, cols)
	_refresh_info()
	_refresh_slots_visual()
	call_deferred("_deferred_scroll_to_selection")


func _clamp_cursor() -> void:
	_sel_row = clampi(_sel_row, 0, ROW_COUNT - 1)
	_sel_col = clampi(_sel_col, 0, COLS_PER_ROW[_sel_row] - 1)


func _flat_index(row: int, col: int) -> int:
	var idx: int = 0
	for r in range(row):
		idx += COLS_PER_ROW[r]
	return idx + col


func _cell_key(row: int, col: int) -> String:
	if row == EXIT_ROW_INDEX:
		return KEY_EXIT_SHOP
	match row:
		0:
			match col:
				0: return KEY_HEAL_HP_S
				1: return KEY_HEAL_HP_L
				2: return KEY_COOL_HORNY_S
				3: return KEY_COOL_HORNY_L
		1:
			return "hp_%d" % (col + 1)
		2:
			return "horny_%d" % (col + 1)
		3:
			return "semen_%d" % (col + 1)
		4:
			match col:
				0: return KEY_LEWD_STATE
				1: return KEY_LEWD_STATE_PLUS
		5:
			match col:
				0: return KEY_PAIZURI_1
				1: return KEY_PAIZURI_2
				2: return KEY_PAIZURI_3
	return ""


func _is_consumable_key(key: String) -> bool:
	return key in [KEY_HEAL_HP_S, KEY_HEAL_HP_L, KEY_COOL_HORNY_S, KEY_COOL_HORNY_L]


func _cost_for_key(key: String) -> float:
	match key:
		KEY_HEAL_HP_S:
			return cost_heal_hp_s
		KEY_HEAL_HP_L:
			return cost_heal_hp_l
		KEY_COOL_HORNY_S:
			return cost_cool_horny_s
		KEY_COOL_HORNY_L:
			return cost_cool_horny_l
	if key.begins_with("hp_"):
		var idx: int = key.trim_prefix("hp_").to_int() - 1
		if idx >= 0 and idx < hp_costs.size():
			return hp_costs[idx]
	elif key.begins_with("horny_"):
		var idx: int = key.trim_prefix("horny_").to_int() - 1
		if idx >= 0 and idx < horny_costs.size():
			return horny_costs[idx]
	elif key.begins_with("semen_"):
		var idx: int = key.trim_prefix("semen_").to_int() - 1
		if idx >= 0 and idx < semen_costs.size():
			return semen_costs[idx]
	match key:
		KEY_LEWD_STATE:
			return cost_lewd_state
		KEY_LEWD_STATE_PLUS:
			return cost_lewd_state_plus
		KEY_PAIZURI_1:
			return cost_paizuri_1
		KEY_PAIZURI_2:
			return cost_paizuri_2
		KEY_PAIZURI_3:
			return cost_paizuri_3
	return 0.0


func _is_ja() -> bool:
	return GlobalState.language == GlobalState.Language.JA


func _desc_for_key(key: String) -> String:
	var ja: bool = _is_ja()
	match key:
		KEY_HEAL_HP_S:
			return ("HPを%.0f回復する。（繰り返し購入可）" % heal_hp_small) if ja else ("Restore %.0f HP. (Repeatable)" % heal_hp_small)
		KEY_HEAL_HP_L:
			return ("HPを%.0f回復する。（繰り返し購入可）" % heal_hp_large) if ja else ("Restore %.0f HP. (Repeatable)" % heal_hp_large)
		KEY_COOL_HORNY_S:
			return ("Hornyを%.0f下げる。（繰り返し購入可）" % cool_horny_small) if ja else ("Reduce Horny by %.0f. (Repeatable)" % cool_horny_small)
		KEY_COOL_HORNY_L:
			return ("Hornyを%.0f下げる。（繰り返し購入可）" % cool_horny_large) if ja else ("Reduce Horny by %.0f. (Repeatable)" % cool_horny_large)
	if key.begins_with("hp_"):
		var idx: int = key.trim_prefix("hp_").to_int() - 1
		if idx >= 0 and idx < hp_values.size():
			var v: float = hp_values[idx]
			return ("HP上限を%.0f増加させる。" % v) if ja else ("Increases max HP by %.0f." % v)
	elif key.begins_with("horny_"):
		var idx: int = key.trim_prefix("horny_").to_int() - 1
		if idx >= 0 and idx < horny_values.size():
			var v: float = horny_values[idx]
			return ("Horny上限を%.0f増加させる。満タン時は挣脱不可＋HPダメージ×1.5。" % v) if ja else ("Increases max Horny by %.0f. At max: cannot escape, HP damage ×1.5." % v)
	elif key.begins_with("semen_"):
		var idx: int = key.trim_prefix("semen_").to_int() - 1
		if idx >= 0 and idx < semen_values.size():
			var v: float = semen_values[idx]
			return ("精液容量の上限を%.0f増加させる。" % v) if ja else ("Increases max Semen capacity by %.0f." % v)
	match key:
		KEY_LEWD_STATE:
			return desc_lewd_state_ja if ja else desc_lewd_state_en
		KEY_LEWD_STATE_PLUS:
			return desc_lewd_state_plus_ja if ja else desc_lewd_state_plus_en
		KEY_PAIZURI_1:
			return desc_paizuri_1_ja if ja else desc_paizuri_1_en
		KEY_PAIZURI_2:
			return desc_paizuri_2_ja if ja else desc_paizuri_2_en
		KEY_PAIZURI_3:
			return desc_paizuri_3_ja if ja else desc_paizuri_3_en
	return ""


func _display_name_for_key(key: String) -> String:
	var ja: bool = _is_ja()
	if key == KEY_EXIT_SHOP:
		return "ショップを出る" if ja else "Exit Shop"
	match key:
		KEY_HEAL_HP_S:
			return "少量HP回復" if ja else "Small HP Restore"
		KEY_HEAL_HP_L:
			return "大量HP回復" if ja else "Large HP Restore"
		KEY_COOL_HORNY_S:
			return "少量Horny低下" if ja else "Small Horny Cool"
		KEY_COOL_HORNY_L:
			return "大量Horny低下" if ja else "Large Horny Cool"
	if key.begins_with("hp_"):
		var idx: int = key.trim_prefix("hp_").to_int()
		return "HP +%d" % idx
	elif key.begins_with("horny_"):
		var idx: int = key.trim_prefix("horny_").to_int()
		return "Horny +%d" % idx
	elif key.begins_with("semen_"):
		var idx: int = key.trim_prefix("semen_").to_int()
		return "Semen +%d" % idx
	match key:
		KEY_LEWD_STATE:
			return "淫乱状態" if ja else "Lewd State"
		KEY_LEWD_STATE_PLUS:
			return "淫乱状態+" if ja else "Lewd State+"
		KEY_PAIZURI_1:
			return "パイズリ1" if ja else "Paizuri 1"
		KEY_PAIZURI_2:
			return "パイズリ2" if ja else "Paizuri 2"
		KEY_PAIZURI_3:
			return "パイズリ3" if ja else "Paizuri 3"
	return key


func _is_unlocked(row: int, col: int) -> bool:
	if row == EXIT_ROW_INDEX:
		return true
	# 消耗品列：無解鎖鏈，皆可購買
	if row == CONSUMABLE_ROW_INDEX:
		return true
	for c in range(col):
		var prev_key: String = _cell_key(row, c)
		if prev_key == "":
			return false
		if not GlobalState.is_progression_item_owned(prev_key):
			return false
	return true


func _refresh_info() -> void:
	if _info_label == null:
		return
	var key: String = _cell_key(_sel_row, _sel_col)
	if key == KEY_EXIT_SHOP:
		if _is_ja():
			_info_label.text = "【ショップを出る】\n\nメニューを閉じて操作に戻る。\nZキーで即退出（確認不要）。"
		else:
			_info_label.text = "【Exit Shop】\n\nClose the shop and resume control.\nPress Z to leave (no confirmation needed)."
		return
	if key == "":
		_info_label.text = ""
		return
	var cost: float = _cost_for_key(key)
	var desc: String = _desc_for_key(key).strip_edges()
	var name_s: String = _display_name_for_key(key)
	var st: PackedStringArray = []
	st.append("【%s】" % name_s)
	st.append("")
	st.append(desc)
	st.append("")
	if _is_ja():
		st.append("消費 Semen：%.0f" % cost)
	else:
		st.append("Cost: %.0f Semen" % cost)
	if not _is_consumable_key(key) and GlobalState.is_progression_item_owned(key):
		st.append("（Purchased）" if not _is_ja() else "（購入済み）")
	elif not _is_unlocked(_sel_row, _sel_col):
		st.append("（Unlock previous item first）" if not _is_ja() else "（前の項目を先に購入してください）")
	elif HSystem.semen + 0.0001 < cost:
		st.append("（Not enough Semen）" if not _is_ja() else "（Semenが足りない）")
	_info_label.text = "\n".join(st)


func _row_col_from_flat(fi: int) -> Vector2i:
	var acc: int = 0
	for r in range(ROW_COUNT):
		var nc: int = COLS_PER_ROW[r]
		if fi < acc + nc:
			return Vector2i(r, fi - acc)
		acc += nc
	return Vector2i(0, 0)


func _refresh_slots_visual() -> void:
	_sync_selection_stylebox()
	for i in range(_slots.size()):
		var rc: Vector2i = _row_col_from_flat(i)
		var row: int = rc.x
		var col: int = rc.y
		var key: String = _cell_key(row, col)
		var p: Panel = _slots[i]
		var sel: bool = row == _sel_row and col == _sel_col
		p.modulate = Color.WHITE
		p.self_modulate = Color.WHITE
		if key == KEY_EXIT_SHOP:
			_apply_slot_panel_style(p, sel, false, true)
			continue
		var owned: bool = (not _is_consumable_key(key)) and GlobalState.is_progression_item_owned(key)
		var unlocked: bool = _is_unlocked(row, col)
		_apply_slot_panel_style(p, sel, owned, unlocked)
		# 圖示：已購保持原色；未解鎖才變灰
		if owned:
			_set_slot_icon_modulate(p, Color.WHITE)
		elif not unlocked:
			_set_slot_icon_modulate(p, locked_modulate)
		else:
			_set_slot_icon_modulate(p, Color.WHITE)


func _refresh_confirm_labels() -> void:
	if _confirm_yes_lbl:
		_confirm_yes_lbl.add_theme_color_override("font_color", selection_border_color if _confirm_yes else Color(0.35, 0.35, 0.35))
	if _confirm_no_lbl:
		_confirm_no_lbl.add_theme_color_override("font_color", selection_border_color if not _confirm_yes else Color(0.35, 0.35, 0.35))


func _try_begin_confirm() -> void:
	var key: String = _cell_key(_sel_row, _sel_col)
	if key == KEY_EXIT_SHOP:
		close_shop()
		return
	if key == "":
		return
	if not _is_consumable_key(key) and GlobalState.is_progression_item_owned(key):
		return
	if not _is_unlocked(_sel_row, _sel_col):
		return
	var cost: float = _cost_for_key(key)
	if HSystem.semen + 0.0001 < cost:
		return
	_ui_state = _UiState.CONFIRM
	_confirm_yes = true
	if _confirm_title:
		if _is_ja():
			_confirm_title.text = "%.0f Semenを消費して「%s」を購入しますか？" % [cost, _display_name_for_key(key)]
		else:
			_confirm_title.text = "Spend %.0f Semen to buy \"%s\"?" % [cost, _display_name_for_key(key)]
	_confirm_root.visible = true
	_refresh_confirm_labels()


func _do_purchase_at_cursor() -> void:
	var key: String = _cell_key(_sel_row, _sel_col)
	if key == KEY_EXIT_SHOP or key == "":
		return
	if not _is_consumable_key(key) and GlobalState.is_progression_item_owned(key):
		return
	if not _is_unlocked(_sel_row, _sel_col):
		return
	var cost: float = _cost_for_key(key)
	if HSystem.semen + 0.0001 < cost:
		return
	if _is_consumable_key(key):
		match key:
			KEY_HEAL_HP_S:
				HSystem.set_hp(HSystem.hp + heal_hp_small)
			KEY_HEAL_HP_L:
				HSystem.set_hp(HSystem.hp + heal_hp_large)
			KEY_COOL_HORNY_S:
				HSystem.set_horny(HSystem.horny - cool_horny_small)
			KEY_COOL_HORNY_L:
				HSystem.set_horny(HSystem.horny - cool_horny_large)
		HSystem.set_semen(HSystem.semen - cost)
		return
	if key.begins_with("hp_"):
		var idx: int = key.trim_prefix("hp_").to_int() - 1
		if idx >= 0 and idx < hp_values.size():
			HSystem.add_to_hp_max(hp_values[idx])
	elif key.begins_with("horny_"):
		var idx: int = key.trim_prefix("horny_").to_int() - 1
		if idx >= 0 and idx < horny_values.size():
			HSystem.add_to_horny_max(horny_values[idx])
	elif key.begins_with("semen_"):
		var idx: int = key.trim_prefix("semen_").to_int() - 1
		if idx >= 0 and idx < semen_values.size():
			HSystem.add_to_semen_max(semen_values[idx])
	GlobalState.mark_progression_item_owned(key)
	HSystem.set_semen(HSystem.semen - cost)
