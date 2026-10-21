extends Node
## HSystem：集中管理 HP / Horny / Semen 數值與簡易 HUD。
## 抽插階段對應 OL_H_Controller.sequence_stage：0=慢、1=中、2=快、3=射精

signal hp_changed(current: float, maximum: float)
signal horny_changed(current: float, maximum: float)
signal semen_changed(current: float, maximum: float)
signal hp_depleted

@export_group("數值上限")
@export var hp_max: float = 100.0
@export var horny_max: float = 100.0
@export var semen_max: float = 9999.0

@export_group("即時數值（編輯器／執行 Remote DEBUG）")
## 執行遊戲時開「遠端」場景樹選 /root/HSystem，在此即時改數值；會套用 clamp 並刷新 HUD
@export_range(0.0, 999999.0, 0.25, "or_less", "or_greater") var hp: float = 100.0:
	get:
		return _hp
	set(value):
		_assign_hp(value)

@export_range(0.0, 999999.0, 0.25, "or_less", "or_greater") var horny: float = 0.0:
	get:
		return _horny
	set(value):
		_assign_horny(value)

@export_range(0.0, 999999.0, 0.25, "or_less", "or_greater") var semen: float = 0.0:
	get:
		return _semen
	set(value):
		_assign_semen(value)

@export_group("Horny → 掙脫難度")
## 每 1 點 Horny 額外需要的「左右交替」次數（可為小數，會進位）
@export var horny_escape_extra_presses_per_unit: float = 0.35
## Horny 達上限時禁止掙脫（符合規則「滿值不可掙脫」）
@export var lock_escape_when_horny_full: bool = true
## Horny 已達上限時，該下抽插的 HP 傷害倍率（與 Lewd 射精倍率相乘）
@export var horny_full_hp_mult: float = 1.5

@export_group("Horny · 非 H 緩慢下降")
## 關閉則非 H 時 Horny 不會隨時間下降
@export var horny_decay_outside_h_enabled: bool = true
## 非 H 模式下，每隔此秒數降低一次（H 開啟時計時暫停且不降）
@export var horny_decay_outside_h_interval_sec: float = 4.0
## 每次降低的 Horny 數值
@export var horny_decay_outside_h_amount: float = 0.5

@export_group("每次抽插 · HP 消耗（慢／中／快／射精）")
@export var hp_cost_slow: float = 2.0
@export var hp_cost_medium: float = 4.0
@export var hp_cost_fast: float = 6.0
@export var hp_cost_ejaculation: float = 8.0

@export_group("每次抽插 · Semen 增加（慢／中／快／射精）")
@export var semen_gain_slow: float = 0.5
@export var semen_gain_medium: float = 1.0
@export var semen_gain_fast: float = 1.5
@export var semen_gain_ejaculation: float = 3.0

@export_group("每次抽插 · Horny 增加（慢／中／快／射精）")
@export var horny_gain_slow: float = 3.0
@export var horny_gain_medium: float = 5.0
@export var horny_gain_fast: float = 8.0
@export var horny_gain_ejaculation: float = 12.0

@export_group("Lewd 倍率（is_lewd_active）")
## Lewd ON 時，射精階段 HP 傷害倍率
@export var lewd_ejaculation_hp_mult: float = 2.0
## Lewd ON 時，慢／中／快／射精 Semen 獲得倍率
@export var lewd_semen_gain_mult: float = 2.0
## Lewd ON 時，疊加到「每點 Horny 額外掙脫次數」的增量（與 horny_escape_extra_presses_per_unit 相加）
@export var lewd_escape_extra_presses_per_unit: float = 0.25

@export_group("內建 HUD（場景節點）")
@export var show_builtin_hud: bool = true
## 是否顯示 HP／Horny／Semen 三條 UI（主選單、過場劇情等可改 false；數值仍照常計算）
@export var show_h_stats_ui: bool = true:
	get:
		return _show_h_stats_ui
	set(value):
		if _show_h_stats_ui == value:
			return
		_show_h_stats_ui = value
		_apply_h_stats_ui_visibility()
## 覆寫 `BuiltinHudCanvas` 的 layer（與場景裡 CanvasLayer.layer 一致時可不改）
@export var hud_layer: int = 127
## 左欄寬度（名稱標籤固定寬度，讓數值欄對齊）
@export var hud_label_column_width: float = 34.0
## 數值欄寬度（「50/100」固定寬度，讓條左緣垂直對齊）
@export var hud_value_column_width: float = 56.0
## 每列 HBox 內各欄的間距
@export_range(0, 64, 1) var hud_label_bar_gap: int = 4
## 左側 HP / Horny / Semen 文字大小（像素）；執行時套到三個 Label
@export_range(8, 64, 1) var hud_label_font_size: int = 14
## 條總寬（像素）≈ 該項上限 × 係數，再夾在最小／最大之間；上限變大時條會向右變長
@export var hud_bar_pixels_per_max: float = 1.2
@export var hud_bar_min_width: float = 80.0
@export var hud_bar_max_width: float = 520.0
## 條列高度（與場景 BarSlot 高度一致較佳）
@export var hud_bar_row_height: float = 14.0

@export_group("Lewd HUD（SlotLewd 購買後）")
## Inmon 圖示邊長（像素）
@export var lewd_icon_size: float = 14.0
## ON／OFF／[S] 文字大小
@export_range(8, 64, 1) var lewd_label_font_size: int = 10
## ON 文字色
@export var lewd_on_color: Color = Color(1.0, 0.55, 0.75, 1.0)
## OFF 文字色
@export var lewd_off_color: Color = Color(0.75, 0.75, 0.75, 1.0)
## [S] Naked 文字色
@export var cloth_naked_color: Color = Color(1.0, 0.7, 0.85, 1.0)
## [S] Clothed 文字色
@export var cloth_clothed_color: Color = Color(0.7, 0.85, 1.0, 1.0)
## 圖示與文字間距
@export_range(0, 32, 1) var lewd_row_separation: int = 4

var _hp: float = 100.0
var _horny: float = 0.0
var _semen: float = 0.0

var _hud_canvas: CanvasLayer
var _label_hp: Label
var _label_horny: Label
var _label_semen: Label
var _value_hp: Label
var _value_horny: Label
var _value_semen: Label
var _hp_bar_slot: Control
var _horny_bar_slot: Control
var _semen_bar_slot: Control
var _hp_origin: Node2D
var _horny_origin: Node2D
var _semen_origin: Node2D
var _hp_track: Line2D
var _hp_fill: Line2D
var _horny_track: Line2D
var _horny_fill: Line2D
var _semen_track: Line2D
var _semen_fill: Line2D
var _hp_row: HBoxContainer
var _horny_row: HBoxContainer
var _semen_row: HBoxContainer
var _lewd_row: HBoxContainer
var _lewd_icon: TextureRect
var _lewd_state_label: Label
var _cloth_state_label: Label
var _bars_vbox: VBoxContainer
var _show_h_stats_ui: bool = true
var _h_mode_active: bool = false
## true 時抽插不扣 HP（結尾 Gallery 關卡等）
var suppress_hp_cost: bool = false
var _horny_decay_accumulator: float = 0.0
## 上一幀是否已達 Horny 上限（邊緣觸發 Shirt Open，避免讀檔／常駐滿值重複觸發）
var _was_horny_at_max: bool = false
## 上一幀是否已解鎖 Lewd（用來偵測剛購買後立刻顯示 HUD）
var _was_lewd_unlocked: bool = false
var _was_cloth_keys_usable: bool = false
## 場景載入時的預設上限（NEW GAME / reset 時還原用）
var _baseline_hp_max: float = 100.0
var _baseline_horny_max: float = 100.0
var _baseline_semen_max: float = 9999.0

func _ready() -> void:
	_baseline_hp_max = hp_max
	_baseline_horny_max = horny_max
	_baseline_semen_max = semen_max
	# 先同步旗標，避免 _ready 初次 assign 誤觸發 OPEN
	_sync_horny_at_max_flag()
	_assign_hp(_hp)
	_assign_horny(_horny)
	_assign_semen(_semen)
	_resolve_builtin_hud_from_scene()
	_refresh_hud()
	if not GlobalState.lewd_active_changed.is_connected(_on_lewd_active_changed):
		GlobalState.lewd_active_changed.connect(_on_lewd_active_changed)
	if not GlobalState.appearance_mode_changed.is_connected(_on_appearance_mode_changed):
		GlobalState.appearance_mode_changed.connect(_on_appearance_mode_changed)
	_was_lewd_unlocked = GlobalState.is_lewd_unlocked()
	_was_cloth_keys_usable = GlobalState.can_use_cloth_keys()
	_refresh_lewd_hud()


func _unhandled_input(event: InputEvent) -> void:
	# C 切換 Lewd：與換衣(S／visuals_manager)、H(H／OL_H_Controller) 不同檔；放在本檔因 HUD 在此
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_try_toggle_lewd_from_input()


func _on_lewd_active_changed(_active: bool) -> void:
	_refresh_lewd_hud()


func _on_appearance_mode_changed(_mode: GlobalState.AppearanceMode) -> void:
	_refresh_lewd_hud()


func _try_toggle_lewd_from_input() -> void:
	if not GlobalState.is_lewd_unlocked():
		return
	if _h_mode_active:
		print("[HSystem] H 進行中，無法切換 Lewd")
		return
	if get_tree().paused or GlobalState.is_paused:
		return
	if GlobalState.changing_scene:
		return
	if ProgressionShop.is_shop_open:
		return
	if DialogueBox.is_dialogue_open:
		return
	GlobalState.toggle_lewd_active()
	_refresh_lewd_hud()

func _process(delta: float) -> void:
	# 剛買下 SlotLewd／Lewd+ 時立刻刷新 Lewd HUD
	var unlocked: bool = GlobalState.is_lewd_unlocked()
	if unlocked != _was_lewd_unlocked:
		_was_lewd_unlocked = unlocked
		if not unlocked:
			GlobalState.set_lewd_active(false)
		_refresh_lewd_hud()
	var cloth_ok: bool = GlobalState.can_use_cloth_keys()
	if cloth_ok != _was_cloth_keys_usable:
		_was_cloth_keys_usable = cloth_ok
		_refresh_lewd_hud()
	if not horny_decay_outside_h_enabled:
		return
	if get_tree().paused:
		return
	if GlobalState.changing_scene:
		return
	if _h_mode_active:
		_horny_decay_accumulator = 0.0
		return
	if _horny <= 0.0001:
		_horny_decay_accumulator = 0.0
		return
	_horny_decay_accumulator += delta
	var interval: float = maxf(horny_decay_outside_h_interval_sec, 0.05)
	var amt: float = maxf(horny_decay_outside_h_amount, 0.0)
	if amt <= 0.0:
		return
	while _horny_decay_accumulator >= interval:
		_horny_decay_accumulator -= interval
		set_horny(_horny - amt)

## OL_H_Controller 在 H 模式開關時呼叫：H 中不進行非 H 緩降
func set_h_mode_active(active: bool) -> void:
	_h_mode_active = active
	if active:
		_horny_decay_accumulator = 0.0


## 目前是否處於 H（被抓／姿勢進行中）
func is_h_mode_active() -> bool:
	return _h_mode_active

func reset_to_defaults() -> void:
	hp_max = _baseline_hp_max
	horny_max = _baseline_horny_max
	semen_max = _baseline_semen_max
	_hp = clampf(hp_max, 0.0, hp_max)
	_horny = 0.0
	_semen = 0.0
	_horny_decay_accumulator = 0.0
	_sync_horny_at_max_flag()
	_emit_all_changed()
	_refresh_hud()


## 商店／存檔：增加 HP 上限（當前 HP 若超過新上限會被夾住）
func add_to_hp_max(delta: float) -> void:
	if delta == 0.0:
		return
	hp_max = maxf(0.0, hp_max + delta)
	_assign_hp(_hp)


## 商店／存檔：增加 Horny 上限
func add_to_horny_max(delta: float) -> void:
	if delta == 0.0:
		return
	horny_max = maxf(0.0, horny_max + delta)
	_assign_horny(_horny)


## 商店／存檔：增加 Semen「容量」上限（與花費的精液貨幣不同欄位）
func add_to_semen_max(delta: float) -> void:
	if delta == 0.0:
		return
	semen_max = maxf(0.0, semen_max + delta)
	_assign_semen(_semen)

func apply_thrust_for_sequence_stage(stage_index: int) -> void:
	var st: int = clampi(stage_index, 0, 3)
	var d_hp: float = 0.0 if suppress_hp_cost else _hp_cost_for_stage(st)
	var d_sem: float = _semen_gain_for_stage(st)
	var d_horn: float = _horny_gain_for_stage(st)
	# Lewd ON：射精傷害 ×N；各階段 Semen ×N
	if GlobalState.is_lewd_active:
		if st >= 3 and not suppress_hp_cost:
			d_hp *= lewd_ejaculation_hp_mult
		d_sem *= lewd_semen_gain_mult
	# Horny 已滿：無法掙脫之外，本下傷害再 ×N（本下才剛摸到上限則下一發才套用）
	if not suppress_hp_cost and _is_horny_at_max_value(_horny) and horny_full_hp_mult != 1.0:
		d_hp *= horny_full_hp_mult
	_assign_hp(_hp - d_hp)
	_assign_semen(_semen + d_sem)
	_assign_horny(_horny + d_horn)

func get_escape_presses_required(base_threshold: int) -> int:
	var base_i: int = maxi(1, base_threshold)
	if lock_escape_when_horny_full and horny >= horny_max - 0.001:
		return 999999
	var rate: float = horny_escape_extra_presses_per_unit
	if GlobalState.is_lewd_active:
		rate += lewd_escape_extra_presses_per_unit
	var extra: float = horny * rate
	return base_i + int(ceil(extra))

func is_escape_locked_by_horny() -> bool:
	return lock_escape_when_horny_full and horny >= horny_max - 0.001

func set_hp(v: float) -> void:
	_assign_hp(v)

func set_horny(v: float) -> void:
	_assign_horny(v)

func set_semen(v: float) -> void:
	_assign_semen(v)

func load_stats(p_hp: float, p_horny: float, p_semen: float) -> void:
	_hp = clampf(p_hp, 0.0, hp_max)
	_horny = clampf(p_horny, 0.0, horny_max)
	_semen = clampf(p_semen, 0.0, semen_max)
	# 讀檔同步旗標，不觸發 Shirt Open
	_sync_horny_at_max_flag()
	_emit_all_changed()
	_refresh_hud()


func _is_horny_at_max_value(v: float) -> bool:
	return v >= horny_max - 0.001


func _sync_horny_at_max_flag() -> void:
	_was_horny_at_max = _is_horny_at_max_value(_horny)


func _assign_hp(value: float) -> void:
	var nv := clampf(value, 0.0, hp_max)
	var old := _hp
	if is_equal_approx(old, nv):
		return
	_hp = nv
	hp_changed.emit(_hp, hp_max)
	_refresh_hud()
	if old > 0.0 and _hp <= 0.0:
		hp_depleted.emit()

func _assign_horny(value: float) -> void:
	var nv := clampf(value, 0.0, horny_max)
	var at_max: bool = _is_horny_at_max_value(nv)
	var reached_max_now: bool = at_max and not _was_horny_at_max
	_was_horny_at_max = at_max
	# 上限變動時也可能只改旗標、數值不變
	if not is_equal_approx(_horny, nv):
		_horny = nv
		horny_changed.emit(_horny, horny_max)
		_refresh_hud()
	# Horny 剛達上限 → 通知 GlobalState 進入／重開 Shirt Open（與著衣／裸體無關）
	if reached_max_now:
		GlobalState.notify_horny_reached_max_for_shirt_open()

func _assign_semen(value: float) -> void:
	var nv := clampf(value, 0.0, semen_max)
	if is_equal_approx(_semen, nv):
		return
	_semen = nv
	semen_changed.emit(_semen, semen_max)
	_refresh_hud()

func _emit_all_changed() -> void:
	hp_changed.emit(_hp, hp_max)
	horny_changed.emit(_horny, horny_max)
	semen_changed.emit(_semen, semen_max)

func _hp_cost_for_stage(st: int) -> float:
	match st:
		0: return hp_cost_slow
		1: return hp_cost_medium
		2: return hp_cost_fast
		_: return hp_cost_ejaculation

func _semen_gain_for_stage(st: int) -> float:
	match st:
		0: return semen_gain_slow
		1: return semen_gain_medium
		2: return semen_gain_fast
		_: return semen_gain_ejaculation

func _horny_gain_for_stage(st: int) -> float:
	match st:
		0: return horny_gain_slow
		1: return horny_gain_medium
		2: return horny_gain_fast
		_: return horny_gain_ejaculation

func _resolve_builtin_hud_from_scene() -> void:
	_hud_canvas = get_node_or_null("BuiltinHudCanvas") as CanvasLayer
	if _hud_canvas == null:
		push_warning("HSystem: 找不到子節點 BuiltinHudCanvas（請在 h_system.tscn 保留 HUD 結構）")
		return
	_hud_canvas.layer = hud_layer
	_hud_canvas.visible = show_builtin_hud
	_bars_vbox = get_node_or_null("BuiltinHudCanvas/BarsVBox") as VBoxContainer
	_hp_row = get_node_or_null("BuiltinHudCanvas/BarsVBox/HpRow") as HBoxContainer
	_horny_row = get_node_or_null("BuiltinHudCanvas/BarsVBox/HornyRow") as HBoxContainer
	_semen_row = get_node_or_null("BuiltinHudCanvas/BarsVBox/SemenRow") as HBoxContainer
	_label_hp = get_node_or_null("BuiltinHudCanvas/BarsVBox/HpRow/LabelHp") as Label
	_label_horny = get_node_or_null("BuiltinHudCanvas/BarsVBox/HornyRow/LabelHorny") as Label
	_label_semen = get_node_or_null("BuiltinHudCanvas/BarsVBox/SemenRow/LabelSemen") as Label
	_value_hp = _ensure_value_label(_hp_row, "ValueHp")
	_value_horny = _ensure_value_label(_horny_row, "ValueHorny")
	_value_semen = _ensure_value_label(_semen_row, "ValueSemen")
	_hp_bar_slot = get_node_or_null("BuiltinHudCanvas/BarsVBox/HpRow/BarSlot") as Control
	_horny_bar_slot = get_node_or_null("BuiltinHudCanvas/BarsVBox/HornyRow/BarSlot") as Control
	_semen_bar_slot = get_node_or_null("BuiltinHudCanvas/BarsVBox/SemenRow/BarSlot") as Control
	_hp_origin = get_node_or_null("BuiltinHudCanvas/BarsVBox/HpRow/BarSlot/Origin") as Node2D
	_horny_origin = get_node_or_null("BuiltinHudCanvas/BarsVBox/HornyRow/BarSlot/Origin") as Node2D
	_semen_origin = get_node_or_null("BuiltinHudCanvas/BarsVBox/SemenRow/BarSlot/Origin") as Node2D
	_hp_track = get_node_or_null("BuiltinHudCanvas/BarsVBox/HpRow/BarSlot/Origin/Track") as Line2D
	_hp_fill = get_node_or_null("BuiltinHudCanvas/BarsVBox/HpRow/BarSlot/Origin/Fill") as Line2D
	_horny_track = get_node_or_null("BuiltinHudCanvas/BarsVBox/HornyRow/BarSlot/Origin/Track") as Line2D
	_horny_fill = get_node_or_null("BuiltinHudCanvas/BarsVBox/HornyRow/BarSlot/Origin/Fill") as Line2D
	_semen_track = get_node_or_null("BuiltinHudCanvas/BarsVBox/SemenRow/BarSlot/Origin/Track") as Line2D
	_semen_fill = get_node_or_null("BuiltinHudCanvas/BarsVBox/SemenRow/BarSlot/Origin/Fill") as Line2D
	_lewd_row = get_node_or_null("BuiltinHudCanvas/BarsVBox/LewdRow") as HBoxContainer
	_lewd_icon = get_node_or_null("BuiltinHudCanvas/BarsVBox/LewdRow/IconLewd") as TextureRect
	_lewd_state_label = get_node_or_null("BuiltinHudCanvas/BarsVBox/LewdRow/LabelLewdState") as Label
	_cloth_state_label = get_node_or_null("BuiltinHudCanvas/BarsVBox/LewdRow/LabelClothState") as Label
	if _hp_track == null or _hp_fill == null:
		push_warning("HSystem: HP 條 Track/Fill 缺失，請檢查 h_system.tscn（HpRow/BarSlot/Origin）")
		return
	_apply_hud_label_bar_gap()
	_apply_h_stats_ui_visibility()
	_refresh_lewd_hud()

func _ensure_value_label(row: HBoxContainer, lbl_name: String) -> Label:
	if row == null:
		return null
	var existing: Label = row.get_node_or_null(lbl_name) as Label
	if existing:
		return existing
	var lbl := Label.new()
	lbl.name = lbl_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(lbl)
	row.move_child(lbl, 1)
	return lbl


func _apply_h_stats_ui_visibility() -> void:
	if _bars_vbox:
		_bars_vbox.visible = _show_h_stats_ui
	_refresh_lewd_hud()

func _apply_hud_label_bar_gap() -> void:
	var g: int = maxi(0, hud_label_bar_gap)
	for row in [_hp_row, _horny_row, _semen_row]:
		if row:
			row.add_theme_constant_override("separation", g)

func _bar_pixel_width_for(vmax: float) -> float:
	return clampf(vmax * hud_bar_pixels_per_max, hud_bar_min_width, hud_bar_max_width)

func _refresh_hud() -> void:
	_apply_h_stats_ui_visibility()
	if _hp_track == null:
		return
	_apply_hud_label_bar_gap()
	var fz: int = maxi(8, hud_label_font_size)
	var row_h: float = maxf(hud_bar_row_height, float(fz) + 4.0)
	var label_w: float = maxf(hud_label_column_width, 1.0)
	var value_w: float = maxf(hud_value_column_width, 1.0)
	_setup_name_label(_label_hp, "HP", fz, label_w, row_h)
	_setup_name_label(_label_horny, "Horny", fz, label_w, row_h)
	_setup_name_label(_label_semen, "Semen", fz, label_w, row_h)
	_setup_value_label(_value_hp, _hp, hp_max, fz, value_w, row_h)
	_setup_value_label(_value_horny, _horny, horny_max, fz, value_w, row_h)
	_setup_value_label(_value_semen, _semen, semen_max, fz, value_w, row_h)
	var w_hp: float = _bar_pixel_width_for(hp_max)
	var w_horny: float = _bar_pixel_width_for(horny_max)
	var w_semen: float = _bar_pixel_width_for(semen_max)
	_layout_one_bar_row(_hp_bar_slot, _hp_origin, _hp_track, _hp_fill, w_hp, row_h, _hp, hp_max)
	_layout_one_bar_row(_horny_bar_slot, _horny_origin, _horny_track, _horny_fill, w_horny, row_h, _horny, horny_max)
	_layout_one_bar_row(_semen_bar_slot, _semen_origin, _semen_track, _semen_fill, w_semen, row_h, _semen, semen_max)
	_refresh_lewd_hud()


func _refresh_lewd_hud() -> void:
	if _lewd_row == null:
		return
	var unlocked: bool = GlobalState.is_lewd_unlocked()
	# 與 HP／Horny／Semen 同一套 show_h_stats_ui 開關
	_lewd_row.visible = unlocked and _show_h_stats_ui and show_builtin_hud
	if not unlocked:
		return
	_lewd_row.add_theme_constant_override("separation", maxi(0, lewd_row_separation))
	var icon_sz: float = maxf(lewd_icon_size, 8.0)
	if _lewd_icon:
		_lewd_icon.custom_minimum_size = Vector2(icon_sz, icon_sz)
	var fz: int = maxi(8, lewd_label_font_size)
	if _lewd_state_label:
		var on: bool = GlobalState.is_lewd_active
		_lewd_state_label.text = "[C] ON" if on else "[C] OFF"
		_lewd_state_label.add_theme_font_size_override("font_size", fz)
		_lewd_state_label.add_theme_color_override("font_color", lewd_on_color if on else lewd_off_color)
	if _cloth_state_label:
		var cloth_ok: bool = GlobalState.can_use_cloth_keys()
		_cloth_state_label.visible = cloth_ok
		if cloth_ok:
			var naked: bool = GlobalState.current_mode == GlobalState.AppearanceMode.NAKED
			_cloth_state_label.text = "[S] Naked" if naked else "[S] Clothed"
			_cloth_state_label.add_theme_font_size_override("font_size", fz)
			_cloth_state_label.add_theme_color_override("font_color", cloth_naked_color if naked else cloth_clothed_color)


func _setup_name_label(lbl: Label, title: String, fz: int, w: float, h: float) -> void:
	if lbl == null:
		return
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", fz)
	lbl.custom_minimum_size = Vector2(w, h)


func _setup_value_label(lbl: Label, cur: float, vmax: float, fz: int, w: float, h: float) -> void:
	if lbl == null:
		return
	lbl.text = "%.0f/%.0f" % [cur, vmax]
	lbl.add_theme_font_size_override("font_size", fz)
	lbl.custom_minimum_size = Vector2(w, h)

func _layout_one_bar_row(
	slot: Control,
	origin: Node2D,
	track: Line2D,
	fill: Line2D,
	bar_width: float,
	row_h: float,
	cur: float,
	vmax: float
) -> void:
	if slot == null or origin == null or track == null or fill == null:
		return
	var w: float = maxf(bar_width, 1.0)
	slot.custom_minimum_size = Vector2(w, row_h)
	origin.position = Vector2(0.0, row_h * 0.5)
	track.points = PackedVector2Array([Vector2.ZERO, Vector2(w, 0)])
	var denom: float = maxf(vmax, 0.0001)
	var ratio: float = clampf(cur / denom, 0.0, 1.0)
	var x_end: float = w * ratio
	if ratio <= 0.001:
		x_end = minf(0.12, w)
	fill.points = PackedVector2Array([Vector2.ZERO, Vector2(x_end, 0)])
