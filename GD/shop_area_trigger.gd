extends Area2D
## 玩家進入此區域時可按 **shop_open**（預設 Enter）開啟進度商店。
## 請在子節點放 CollisionShape2D／CollisionPolygon2D，並確認 collision_mask 能偵測到玩家所在層。
## 燈光 Energy／顏色／位置／縮放請直接調 PointLight2D，腳本不會蓋掉。

@export_group("梯形光圈")
## 梯形上邊寬度（相對貼圖，0~1，較窄像燈管）
@export_range(0.05, 1.0, 0.01) var trap_top_width: float = 0.32
## 梯形下邊寬度（相對貼圖，0~1，較寬像往下灑光）
@export_range(0.05, 1.0, 0.01) var trap_bottom_width: float = 0.92
## 邊緣柔化程度
@export_range(0.01, 0.45, 0.01) var trap_softness: float = 0.14
## 梯形貼圖解析度
@export var trap_texture_size: int = 256

@export_group("燈光閃爍")
## 是否讓光圈閃爍提醒玩家
@export var flicker_enabled: bool = true
## 閃爍速度（每秒來回次數）
@export var flicker_speed: float = 2.0
## 最暗時為編輯器 Energy 的倍率
@export_range(0.0, 1.0, 0.01) var flicker_min_ratio: float = 0.45
## 最亮時為編輯器 Energy 的倍率
@export_range(0.0, 2.0, 0.01) var flicker_max_ratio: float = 1.2
## 額外亂閃程度（0=平滑呼吸燈，越大越像燈管故障）
@export_range(0.0, 1.0, 0.01) var flicker_random: float = 0.12

@export_group("提示字")
## 進入觸發範圍時顯示的文字
@export var prompt_text: String = "[ENTER]"
## 相對販賣機中心的位置（負 Y 為上方）
@export var prompt_offset: Vector2 = Vector2(0, -96)
@export var prompt_font_size: int = 10
## 字色（與商店選取框同紫）
@export var prompt_color: Color = Color(0.78, 0.42, 1.0, 1.0)
## 白邊
@export var prompt_outline_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0, 12, 1) var prompt_outline_size: int = 4
@export var prompt_z_index: int = 20

var _player_inside: bool = false
@onready var _light: PointLight2D = $PointLight2D
## 進場時從 PointLight2D 記住的編輯器 Energy（閃爍以此為基準）
var _editor_energy: float = 1.15
var _flicker_phase: float = 0.0
var _prompt: Label
var _prompt_was_visible: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if _light:
		_editor_energy = _light.energy
	_flicker_phase = randf() * TAU
	_setup_prompt()
	_apply_light()
	print("販賣機閃爍: enabled=", flicker_enabled, " energy基準=", _editor_energy)


func _process(delta: float) -> void:
	_apply_flicker(delta)
	_update_prompt_visible()


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


func _apply_light() -> void:
	if _light == null:
		return
	# 只換梯形貼圖，不改 color／energy／position／offset／scale／texture_scale
	_light.texture = _make_trapezoid_texture()
	print("販賣機梯形燈光已套用 top=", trap_top_width, " bottom=", trap_bottom_width)


func _make_trapezoid_texture() -> Texture2D:
	var size: int = maxi(trap_texture_size, 32)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var inv: float = 1.0 / float(size - 1)
	var soft: float = clampf(trap_softness, 0.01, 0.45)
	var top_w: float = clampf(trap_top_width, 0.05, 1.0)
	var bot_w: float = clampf(trap_bottom_width, 0.05, 1.0)
	for y in size:
		var ty: float = float(y) * inv
		var half: float = lerpf(top_w, bot_w, ty) * 0.5
		for x in size:
			var tx: float = float(x) * inv
			var n: float = absf(tx - 0.5) / maxf(half, 0.0001)
			var edge: float = 0.0
			if n < 1.0:
				edge = 1.0 - smoothstep(1.0 - soft, 1.0, n)
			var top_fade: float = smoothstep(0.0, soft, ty)
			var bot_fade: float = 1.0 - smoothstep(1.0 - soft, 1.0, ty)
			var vert: float = 1.0 - ty * 0.28
			var a: float = clampf(edge * top_fade * bot_fade * vert, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _setup_prompt() -> void:
	_prompt = get_node_or_null("PromptLabel") as Label
	if _prompt == null:
		_prompt = Label.new()
		_prompt.name = "PromptLabel"
		add_child(_prompt)
		_prompt.text = prompt_text
		_prompt.z_index = prompt_z_index
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_prompt.add_theme_color_override("font_color", prompt_color)
		_prompt.add_theme_color_override("font_outline_color", prompt_outline_color)
		_prompt.add_theme_constant_override("outline_size", prompt_outline_size)
		_prompt.add_theme_font_size_override("font_size", prompt_font_size)
		_prompt.reset_size()
		var sz: Vector2 = _prompt.get_minimum_size()
		if sz.x < 8.0:
			sz = Vector2(72.0, 16.0)
		_prompt.size = sz
		_prompt.position = prompt_offset - Vector2(sz.x * 0.5, sz.y)
		print("販賣機提示字：場景沒有 Label，已用腳本預設建立")
	else:
		# 場景裡已有 PromptLabel：字級／顏色／位置全部沿用 Inspector，不要蓋掉
		print("販賣機提示字沿用場景設定 font_size=", _prompt.get_theme_font_size("font_size"))
	_prompt.visible = false
	_prompt_was_visible = false


func _update_prompt_visible() -> void:
	if _prompt == null:
		return
	var show: bool = _player_inside and not ProgressionShop.is_shop_open and not DialogueBox.is_dialogue_open
	if show == _prompt_was_visible:
		_prompt.visible = show
		return
	_prompt_was_visible = show
	_prompt.visible = show
	print("販賣機提示: ", "顯示" if show else "隱藏")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_inside = true
		print("販賣機範圍: 進入")


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_inside = false
		print("販賣機範圍: 離開")


func _input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if ProgressionShop.is_shop_open:
		return
	if DialogueBox.is_dialogue_open:
		return
	if event.is_action_pressed("shop_open"):
		ProgressionShop.open_shop()
		get_viewport().set_input_as_handled()
