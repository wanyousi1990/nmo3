extends Area2D

## 此存檔點的唯一 ID
@export var point_id: String = "Save_01"

## 玩家載入此點時的位移偏移
@export var spawn_offset: Vector2 = Vector2(50, -50)

## 是否觸碰即存檔 (如果是 false, 則需要按鍵觸發)
@export var touch_to_save: bool = true

@export_group("電腦外觀")
## 目前重生點（寫入此點後）用藍色螢幕
@export var texture_active: Texture2D
## 是存檔點、但不是目前重生點時用粉紅色螢幕
@export var texture_inactive: Texture2D

@export_group("燈光顏色")
## 成為目前重生點時的燈光色（藍）。Energy／位置／縮放請直接調 PointLight2D，不會被腳本蓋掉。
@export var light_color_active: Color = Color(0.45, 0.78, 1.0, 1.0)

@export_group("燈光閃爍")
## 是否讓光圈閃爍提醒玩家
@export var flicker_enabled: bool = true
## 閃爍速度（每秒來回次數）
@export var flicker_speed: float = 2.2
## 最暗時為編輯器 Energy 的倍率
@export_range(0.0, 1.0, 0.01) var flicker_min_ratio: float = 0.4
## 最亮時為編輯器 Energy 的倍率
@export_range(0.0, 2.0, 0.01) var flicker_max_ratio: float = 1.15
## 額外亂閃程度（0=平滑呼吸燈，越大越像燈管故障）
@export_range(0.0, 1.0, 0.01) var flicker_random: float = 0.08

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _light: PointLight2D = $PointLight2D

## 進場時從 PointLight2D 記住的編輯器顏色（粉／未啟用）
var _editor_light_color: Color = Color(1.0, 0.45, 0.75, 1.0)
## 進場時從 PointLight2D 記住的編輯器 Energy（閃爍以此為基準）
var _editor_energy: float = 0.85
var _flicker_phase: float = 0.0


func _ready():
	# 註冊到群組，讓 GlobalState 載入時能找到我
	add_to_group("save_points")
	if _light:
		_editor_light_color = _light.color
		_editor_energy = _light.energy
	_flicker_phase = randf() * TAU
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	refresh_active_visual()
	print("存檔點閃爍: enabled=", flicker_enabled, " energy基準=", _editor_energy)


func _process(delta: float) -> void:
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

func _on_body_entered(body):
	if body.is_in_group("Player"):
		if touch_to_save:
			execute_save()

## 執行存檔邏輯
func execute_save():
	# 1. 更新 GlobalState 的重生點 ID
	GlobalState.target_door_id = point_id
	
	# 2. 呼叫全域存檔 (會寫入 JSON)
	GlobalState.save_game()
	
	# 3. 播放視覺回饋
	GlobalState.play_save_effects()
	
	print("進度已儲存於存檔點: ", point_id)

## 只切換電腦圖與燈光顏色（藍／粉）。Energy、position、offset、scale、texture_scale 一律沿用編輯器設定。
func refresh_active_visual() -> void:
	var is_active: bool = (point_id != "" and point_id == GlobalState.target_door_id)
	if _sprite:
		if is_active and texture_active:
			_sprite.texture = texture_active
		elif texture_inactive:
			_sprite.texture = texture_inactive
	if _light:
		_light.color = light_color_active if is_active else _editor_light_color
	print("存檔點視覺: ", point_id, " 目前重生點=", is_active)
