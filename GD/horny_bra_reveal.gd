extends Sprite2D
## Horny 值超過閾值時，逐漸透出胸罩 Sprite。
## 掛在 Breast_R（或 Breast_L）底下的 Sprite2D 節點上。
## 共用參數請改 TRES/horny_bra_reveal.tres（所有掛載此腳本的節點同步生效）。
## 脫衣（NAKED）時強制隱藏；全域 Shirt Open 時隱藏胸罩；OPEN 結束後恢復半透明胸罩。

const DEFAULT_CONFIG_PATH := "res://TRES/horny_bra_reveal.tres"

@export_group("Horny Bra Reveal")
## 共用參數 Resource；未指定時自動使用 TRES/horny_bra_reveal.tres
@export var config: HornyBraRevealConfig

var _cfg: HornyBraRevealConfig
var _was_clothed: bool = true


func _ready() -> void:
	_cfg = config if config != null else load(DEFAULT_CONFIG_PATH) as HornyBraRevealConfig
	if _cfg == null:
		_cfg = HornyBraRevealConfig.new()
		push_warning("horny_bra_reveal: 找不到共用設定，使用預設值")
	modulate.a = 0.0
	_was_clothed = _is_clothed()
	if not HSystem.horny_changed.is_connected(_on_horny_changed):
		HSystem.horny_changed.connect(_on_horny_changed)
	_apply_bra_visual(HSystem.horny)


func _exit_tree() -> void:
	if HSystem.horny_changed.is_connected(_on_horny_changed):
		HSystem.horny_changed.disconnect(_on_horny_changed)


func _process(_delta: float) -> void:
	var clothed: bool = _is_clothed()
	if clothed != _was_clothed:
		_was_clothed = clothed
	_apply_bra_visual(HSystem.horny)


func _is_clothed() -> bool:
	return GlobalState.current_mode == GlobalState.AppearanceMode.CLOTHED


func _on_horny_changed(current: float, _maximum: float) -> void:
	_apply_bra_visual(current)


## 由同側 horny_shirt_open 在開始／結束時呼叫，立即同步胸罩顯示
func refresh_from_shirt_open() -> void:
	_apply_bra_visual(HSystem.horny)


func _apply_bra_visual(current: float) -> void:
	if _cfg == null:
		return
	# 脫衣，或全域 Shirt Open：胸罩強制隱藏
	if not _is_clothed() or GlobalState.is_shirt_open:
		visible = false
		modulate.a = 0.0
		return

	visible = true
	if current >= _cfg.threshold_b:
		modulate.a = _cfg.alpha_b
	elif current >= _cfg.threshold_a:
		var t: float = (current - _cfg.threshold_a) / maxf(_cfg.threshold_b - _cfg.threshold_a, 0.01)
		modulate.a = lerpf(_cfg.alpha_a, _cfg.alpha_b, t)
	else:
		modulate.a = 0.0
