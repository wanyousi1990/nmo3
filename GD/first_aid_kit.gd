extends Area2D
## 醫藥箱：女主觸碰後恢復 HP、全螢幕綠閃，然後從本關消失。
## 不寫入存檔／旗標；離開地圖再進來會重新載入場景，箱子會再現。
## 光圈 Energy／位置／縮放請直接調 PointLight2D，腳本只做閃爍倍率。

@export_group("恢復")
@export var heal_hp: float = 20.0 ## 觸碰時恢復的 HP（會被 HSystem 上限 clamp）

@export_group("全螢幕閃爍（同 Horny OPEN 的 ColorRect + Tween）")
@export var flash_color: Color = Color(0.25, 0.95, 0.4, 1.0) ## 閃爍色（綠）
@export_range(0.0, 1.0, 0.01) var flash_peak_alpha: float = 0.35 ## 閃爍最高不透明度
@export var flash_fade_in: float = 0.08 ## 閃爍淡入秒數
@export var flash_fade_out: float = 0.25 ## 閃爍淡出秒數

@export_group("燈光閃爍")
@export var flicker_enabled: bool = true ## 是否讓綠色光圈閃爍提醒玩家
@export var flicker_speed: float = 1.8 ## 閃爍速度（每秒來回次數）
@export_range(0.0, 1.0, 0.01) var flicker_min_ratio: float = 0.55 ## 最暗時為編輯器 Energy 的倍率
@export_range(0.0, 2.0, 0.01) var flicker_max_ratio: float = 1.15 ## 最亮時為編輯器 Energy 的倍率
@export_range(0.0, 1.0, 0.01) var flicker_random: float = 0.08 ## 額外亂閃程度（0=平滑呼吸燈）

@onready var _light: PointLight2D = $PointLight2D

var _editor_energy: float = 0.5 ## 進場時從 PointLight2D 記住的編輯器 Energy
var _flicker_phase: float = 0.0
var _consumed: bool = false ## 本關是否已被撿走（不持久化）


func _ready() -> void:
	if _light:
		_editor_energy = _light.energy
	_flicker_phase = randf() * TAU
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	print("[FirstAidKit] 就緒 heal_hp=", heal_hp)


func _process(delta: float) -> void:
	if _consumed:
		return
	_apply_flicker(delta)


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


func _on_body_entered(body: Node) -> void:
	if _consumed:
		return
	if not body.is_in_group("Player"):
		return
	_consume()


func _consume() -> void:
	_consumed = true
	set_deferred("monitoring", false)
	var before: float = HSystem.hp
	HSystem.set_hp(HSystem.hp + heal_hp)
	GlobalState.play_full_screen_flash(flash_color, flash_peak_alpha, flash_fade_in, flash_fade_out)
	print("[FirstAidKit] 觸碰回血 ", before, " → ", HSystem.hp, "（+", heal_hp, "）")
	visible = false
	queue_free()
