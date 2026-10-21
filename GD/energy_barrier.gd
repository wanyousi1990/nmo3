extends Node2D
## 能量屏障：守關條件未達成前以 StaticBody2D 一般碰撞阻擋女主；
## 條件達成後立即消失。碰撞請在編輯器直接調 CollisionShape2D（執行時不改寫）。
## 視覺：energy_barrier_game.png；光圈上下拉長橢圓，色同能量門粉紅。

@export_group("守關條件")
## 對應守關怪 awakened_flag_key（例如 gate_m01_awakened）
@export var clear_flag_key: String = "gate_m01_awakened"

@export_group("燈光閃爍")
@export var flicker_enabled: bool = true
@export var flicker_speed: float = 1.4
@export_range(0.0, 1.0, 0.01) var flicker_min_ratio: float = 0.65
@export_range(0.0, 2.0, 0.01) var flicker_max_ratio: float = 1.2
@export_range(0.0, 1.0, 0.01) var flicker_random: float = 0.08

var _body: StaticBody2D
var _light: PointLight2D
var _sprite: Sprite2D
var _editor_energy: float = 1.0
var _flicker_phase: float = 0.0
var _cleared: bool = false


func _ready() -> void:
	_body = get_node_or_null("BarrierBody") as StaticBody2D
	_light = get_node_or_null("PointLight2D") as PointLight2D
	_sprite = get_node_or_null("BarrierSprite") as Sprite2D
	if _light:
		_editor_energy = _light.energy
	_flicker_phase = randf() * TAU

	if not GlobalState.dialogue_flag_changed.is_connected(_on_dialogue_flag_changed):
		GlobalState.dialogue_flag_changed.connect(_on_dialogue_flag_changed)

	if GlobalState.has_dialogue_flag(clear_flag_key):
		_clear_barrier(false)
	else:
		print("[EnergyBarrier] 就緒 | clear_flag=", clear_flag_key)


func _process(delta: float) -> void:
	if _cleared:
		return
	_update_flicker(delta)


func _update_flicker(delta: float) -> void:
	if not flicker_enabled or _light == null:
		return
	_flicker_phase += delta * flicker_speed * TAU
	var wave: float = (sin(_flicker_phase) + 1.0) * 0.5
	var ratio: float = lerpf(flicker_min_ratio, flicker_max_ratio, wave)
	if flicker_random > 0.0:
		ratio += (randf() * 2.0 - 1.0) * flicker_random * 0.15
	_light.energy = _editor_energy * clampf(ratio, 0.0, 2.5)


func _on_dialogue_flag_changed(key: String) -> void:
	if _cleared:
		return
	if key == clear_flag_key:
		_clear_barrier(true)


func _clear_barrier(animate_log: bool) -> void:
	_cleared = true
	if animate_log:
		print("[EnergyBarrier] 守關條件達成 → 屏障消失 key=", clear_flag_key)
	if _body:
		_body.set_deferred("collision_layer", 0)
		_body.set_deferred("collision_mask", 0)
	visible = false
	queue_free()
