extends CharacterBody2D

# ==============================================================================
# OL_Character (V1.8 - 物理優化版與coyote_time)
# 職責：處理玩家移動、跳躍、轉向，並作為 H 劇場的宿主。
# 修正：H 模式下僅鎖定「操控」，保留重力與物理運算，避免空中停滯。加入coyote_time
# ==============================================================================

enum DashAnimationVisualMode {
	USE_NORMAL_VISUAL_FOR_DASH,
	USE_DASH_VISUAL_FOR_DASH,
}

@export_group("Nodes Reference (節點引用)")
@export var normal_visual: Node2D       # 女主的地圖 Sprite (一般狀態)
@export var dash_visual: Node2D       # DASH 專用視覺（可選；配合 dash_animation_visual_mode）
@export var h_controller: Node2D       # 引用內部的 OL_H_Controller
@onready var visual_manager = $Visuals # 視覺管理器節點

@export_group("Dash Settings (衝刺)")
@export var dash_duration: float = 0.18 ## 衝刺總時長（秒）
@export var dash_invincible_duration: float = 0.12 ## 衝刺無敵持續秒數（獨立於 H 結束無敵）
@export var dash_speed: float = 520.0 ## 衝刺中段最高水平速度
@export var dash_cooldown: float = 0.55 ## 衝刺結束後冷卻秒數
@export var dash_ease_in: float = 0.08 ## 起步加速秒數（平滑開始）
@export var dash_ease_out: float = 0.10 ## 收尾減速秒數（平滑結束，終點速度為 0）
@export var dash_end_lean_degrees: float = 14.0 ## 結束時身體轉向角度（度）；右=順時針、左=逆時針
@export var dash_lean_window: float = 0.10 ## 結束前幾秒開始轉向
@export var dash_lean_in_speed: float = 16.0 ## 轉過去的跟隨速度
@export var dash_lean_recover: float = 10.0 ## 衝刺結束後回正速度
@export var dash_animation_visual_mode: DashAnimationVisualMode = DashAnimationVisualMode.USE_DASH_VISUAL_FOR_DASH ## 衝刺時用 Dash_Visual 或沿用 Normal_Visual

@export_group("Movement Settings (移動設定)")
@export var speed: float = 180.0
@export var jump_velocity: float = -400.0
@export var invincible_duration: float = 3.0
@export var max_fall_speed: float = 2000
@export var coyote_time: float = 0.12  # 離開地面後還能跳躍的緩衝時間(秒)
@export var jump_buffer: float = 0.1 ## 落地前預先按跳的緩衝時間（秒）
@export var gravity_scale: float = 1.0  # 相對於專案 Physics 2D / get_gravity() 的倍率（Inspector 可調）

@export_group("One-Way Platform (單向平台／桌子)")
@export var solid_collision_layer: int = 3 ## 實心地板（Godot 1-based；TileSet physics_layer_0 → collision_layer = 4）
@export var platform_collision_layer: int = 4 ## 單向平台（Godot 1-based；TileSet physics_layer_1 → collision_layer = 8）
@export var platform_drop_duration: float = 0.12 ## 下穿時暫時忽略單向層碰撞的秒數（夠穿過薄檯面即可）
@export var platform_drop_nudge: float = 8.0 ## 下穿時下移量，需超過檯面碰撞厚度

@export_group("Collision Fit (碰撞貼合)")
@export var body_collision: CollisionShape2D ## 本體碰撞；空白則自動抓取子節點 CollisionShape2D
@export var air_shorten_from_feet: float = 28.0 ## 離地／跳躍時從腳往上縮短（解決牆角視覺可過卻卡住）
@export var dash_air_shorten_from_feet: float = 36.0 ## 空中衝刺時從腳往上縮短（與 air 取較大）
@export var dash_ground_shorten_from_head: float = 22.0 ## 地面衝刺從頭頂往下縮（腳貼地，避免浮空／掉落）
@export var min_collision_height: float = 48.0 ## 縮短後最小高度，避免縮太狠穿牆穿地
@export var land_restore_duration: float = 0.12 ## 落地還原碰撞／上移的平滑時間（秒）；0＝瞬間

@export_group("Camera Settings")
@export var camera: Camera2D
@export var camera_offset_x: float = 50.0 # 相機偏移目標點
@export var camera_move_speed: float = 400.0 # 每秒移動的像素速度
@export var camera_run_weigh: float = 50

# 內部狀態
var is_in_h_mode: bool = false
var invincibility_timer: float = 0.0
var last_attacker: Node2D = null       # 記錄目前是哪隻怪物觸發了演出
var hand_h: bool = false
var current_facing: float = 1.0 # 1.0 為右, -1.0 為左
var camera_run: float = 0.0
var coyote_timer: float = 0.0  # Coyote Time 倒數計時器
var jump_buffer_timer: float = 0.0  # Jump Buffer 倒數計時器
var platform_drop_timer: float = 0.0  # 下穿單向平台倒數

# DASH（與 H 結束後無敵獨立計時）
var dash_timer: float = 0.0
var dash_total_time: float = 0.0
var dash_start_speed: float = 0.0
var dash_direction: float = 1.0
var dash_invincibility_timer: float = 0.0
var dash_cooldown_timer: float = 0.0

# 碰撞貼合快取（狀態縮短，非幾何自適應）
var _col_rect: RectangleShape2D = null
var _col_base_size: Vector2 = Vector2.ZERO
var _col_base_pos: Vector2 = Vector2.ZERO
var _col_apply_feet: float = 0.0 ## 上一幀實際從腳縮短的量（還原時用來抬角色，避免卡進地板）

func _ready():
	# 核心通訊機制：連結來自 H 控制器的訊號
	if h_controller:
		# 1. 連結自動進程結束訊號
		if h_controller.has_signal("h_mode_finished"):
			h_controller.h_mode_finished.connect(_on_h_sequence_finished)
		
		# 2. 連結手動切換訊號 (用於同步 is_in_h_mode)
		if h_controller.has_signal("h_mode_toggled"):
			h_controller.h_mode_toggled.connect(_on_h_mode_toggled)
			
		print("[OL_Character] 已成功連結 H 控制器相關訊號。")
		
	
	# 確保在 Player 群組以供怪物偵測
	add_to_group("Player")
	# 實心地板 + 單向平台分開層；怪物只碰實地，會穿過單向平台掉下
	set_collision_mask_value(solid_collision_layer, true)
	set_collision_mask_value(platform_collision_layer, true)
	_init_collision_fit()
	_refresh_dash_related_visuals()

func set_current_facing(f: float):
	current_facing = f

func _try_perform_jump() -> bool:
	# 地面或 Coyote 窗口內起跳；成功則清空 buffer
	if GlobalState.is_paused:
		return false
	if not (is_on_floor() or coyote_timer > 0):
		return false
	print(GlobalState.is_paused)
	velocity.y = jump_velocity
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	if visual_manager:
		visual_manager.on_jump_triggered()
	return true

## 是否站在 one_way 圖塊上（實心地板不可下穿）
func _is_standing_on_one_way() -> bool:
	for i in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		if col.get_normal().dot(Vector2.UP) < 0.5:
			continue
		var collider := col.get_collider()
		if not (collider is TileMapLayer):
			continue
		var tm := collider as TileMapLayer
		if tm.tile_set == null:
			continue
		var coords: Vector2i = tm.get_coords_for_body_rid(col.get_collider_rid())
		var td: TileData = tm.get_cell_tile_data(coords)
		if td == null:
			continue
		var layer_count: int = tm.tile_set.get_physics_layers_count()
		for p_layer in range(layer_count):
			for p in range(td.get_collision_polygons_count(p_layer)):
				if td.is_collision_polygon_one_way(p_layer, p):
					return true
	return false

## 方向鍵下 + 跳：暫時忽略單向平台碰撞，從桌子往下掉（實心地板不受影響）
func _try_drop_through_platform() -> bool:
	if GlobalState.is_paused:
		return false
	if not is_on_floor():
		return false
	if platform_drop_timer > 0:
		return false
	if not _is_standing_on_one_way():
		return false
	set_collision_mask_value(platform_collision_layer, false)
	platform_drop_timer = platform_drop_duration
	position.y += platform_drop_nudge
	if velocity.y < 120.0:
		velocity.y = 120.0
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	print("[OL_Character] 下穿單向平台（下+跳）")
	return true

func _update_platform_drop(delta: float) -> void:
	if platform_drop_timer <= 0:
		return
	platform_drop_timer -= delta
	if platform_drop_timer <= 0:
		platform_drop_timer = 0.0
		set_collision_mask_value(platform_collision_layer, true)
		print("[OL_Character] 恢復單向平台碰撞")

func _physics_process(delta: float) -> void:
	# 處理無敵時間倒數與視覺閃爍（H 結束無敵）
	if invincibility_timer > 0:
		invincibility_timer -= delta

	# DASH 無敵（獨立計時，不寫入 invincibility_timer）
	if dash_invincibility_timer > 0:
		dash_invincibility_timer -= delta

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	_update_flash_effect()

	var is_dashing = dash_timer > 0

	# --- 物理與移動處理 ---

	# 1. 重力：DASH 中忽略重力
	if not is_dashing and not is_on_floor():
		if velocity.y <= max_fall_speed:
			velocity += get_gravity() * gravity_scale * delta

	# 2. 判斷是否可以操控
	if is_in_h_mode or GlobalState.changing_scene or ProgressionShop.is_shop_open or DialogueBox.blocks_player_input:
		if is_dashing:
			_cancel_dash(false)
		# 對話剛結束的防誤觸期間清掉 Jump Buffer，避免同一擊 Z 補跳
		if DialogueBox.blocks_player_input:
			jump_buffer_timer = 0.0
		# H 模式下：鎖定操控，並讓水平速度自然減速到 0
		velocity.x = move_toward(velocity.x, 0, speed * delta * 5.0)
		if camera:
			camera.offset.x = lerp(camera.offset.x, 0.0, 0.02)
	elif is_dashing:
		velocity.x = dash_direction * _dash_current_speed()
		velocity.y = 0.0
		dash_timer -= delta
		if dash_timer <= 0:
			velocity.x = 0.0
			_finish_dash_natural()
		# 衝刺中預先按跳，結束落地後由 Jump Buffer 補跳
		if Input.is_action_just_pressed("ui_jump"):
			jump_buffer_timer = jump_buffer
		if camera:
			var target_offset_x = current_facing * (camera_offset_x + (camera_run * camera_run_weigh))
			camera.offset.x = lerp(camera.offset.x, target_offset_x, 0.02)
	else:
		
		if camera:
			var target_offset_x = current_facing * (camera_offset_x + (camera_run * camera_run_weigh))
			# 使用 move_toward 確保以恆定速度平滑到達指定位置
			camera.offset.x = lerp(camera.offset.x, target_offset_x, 0.02)#camera_move_speed * delta)
		
		# 正常模式：處理玩家輸入
		_try_start_dash()

		if dash_timer <= 0:
			# 處理跳躍／下穿：持續按「下」時，單向平台＝下穿；否則＝起跳（含 Jump Buffer）
			if Input.is_action_just_pressed("ui_jump"):
				if Input.is_action_pressed("ui_down"):
					# 按住下：只嘗試下穿；空中／尚未落地則寫入 buffer，落地再補穿
					if not _try_drop_through_platform():
						jump_buffer_timer = jump_buffer
				elif not _try_perform_jump():
					jump_buffer_timer = jump_buffer

			# 處理移動輸入
			var dir = Input.get_axis("ui_left", "ui_right")
			if dir != 0:
				velocity.x = dir * speed
				current_facing = dir # 更新角色朝向
				camera_run = 1.0
				if visual_manager:
					visual_manager.update_facing(dir)
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
				camera_run = 0.0

	# 碰撞貼合：在 move_and_slide 前套用，避免腳底掃到牆角
	_update_collision_fit(delta)
	_update_platform_drop(delta)

	# 3. 執行物理移動 (不論是否在 H 模式都執行，以確保重力生效)
	var was_on_floor = is_on_floor()
	move_and_slide()

	# Coyote Time 計時器
	if was_on_floor and not is_on_floor():
		coyote_timer = coyote_time
	elif coyote_timer > 0:
		coyote_timer -= delta

	# Jump Buffer：落地後補執行（持續按「下」→ 單向平台下穿；否則起跳）
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
		if dash_timer <= 0 and not is_in_h_mode and not GlobalState.changing_scene and not ProgressionShop.is_shop_open and not DialogueBox.blocks_player_input:
			if Input.is_action_pressed("ui_down"):
				if is_on_floor():
					if _try_drop_through_platform():
						pass
					else:
						# 實心地板：按住下不補跳，清掉 buffer
						jump_buffer_timer = 0.0
			else:
				_try_perform_jump()

	# 4. 落地偵測
	if is_on_floor() and not was_on_floor:
		if visual_manager:
			visual_manager.on_impact_landed()
	
	# 5. 相機位置，決定目標偏移值 (根據目前的朝向)
	_update_dash_body_lean(delta)

		
# --- H 模式控制介面 (由怪物觸發) ---

func start_h_event(attacker: Node2D = null, pose_tag: String = ""):
	if is_in_h_mode or invincibility_timer > 0:
		return

	_cancel_dash(false)
	jump_buffer_timer = 0.0
	# 進 H 時若正在下穿，恢復平台碰撞
	if platform_drop_timer > 0:
		platform_drop_timer = 0.0
		set_collision_mask_value(platform_collision_layer, true)
		
	print("[OL_Character] 進入 H 模式，暫停玩家操控。")
	is_in_h_mode = true
	last_attacker = attacker
	if visual_manager:
		visual_manager.rotation = 0.0
		# H 姿勢本身已含左右構圖；不依敵人／玩家方向翻轉，改由怪物隨機二選一
		visual_manager.scale.x = absf(visual_manager.scale.x)
		# 姿勢構圖固定朝 +X；同步 last_facing，避免出 H 後按住進場方向不翻面
		if "last_facing" in visual_manager:
			visual_manager.last_facing = 1.0
		current_facing = 1.0
	
	# 隱藏一般狀態的視覺管理器/Sprite
	if dash_visual:
		dash_visual.visible = false
	if normal_visual:
		normal_visual.visible = false
	
	# 啟動 H 劇場控制器（先等預熱；用單一入口 enter_h_mode，避免 toggle+switch 競態）
	if h_controller:
		if h_controller.has_method("ensure_h_warmup_finished"):
			await h_controller.ensure_h_warmup_finished()
		if h_controller.has_method("enter_h_mode"):
			await h_controller.enter_h_mode(pose_tag)
		else:
			h_controller.toggle_h_mode()
			h_controller.switch_pose(pose_tag)
		
	#if camera:
		#camera.offset.x = 0


## H 結束：用當下按住的左右對齊面向（按住不會產生 just_pressed，必須主動套用）
func _apply_facing_from_held_input() -> void:
	var dir: float = Input.get_axis("ui_left", "ui_right")
	if is_zero_approx(dir):
		dir = current_facing
	if is_zero_approx(dir):
		dir = 1.0
	current_facing = signf(dir)
	if visual_manager and visual_manager.has_method("update_facing"):
		visual_manager.update_facing(current_facing)
	print("[OL_Character] H 結束對齊面向：", current_facing)

## 依敵人 direction／視覺 scale 決定女主（Visuals）朝向
func _apply_h_facing_from_attacker(attacker: Node2D) -> void:
	if attacker == null:
		return
	var enemy_dir: float = 0.0
	if "direction" in attacker:
		enemy_dir = signf(float(attacker.direction))
	if enemy_dir == 0.0:
		var vis: Variant = attacker.get("visual_node")
		if vis is Node2D and absf((vis as Node2D).scale.x) > 0.001:
			enemy_dir = signf((vis as Node2D).scale.x)
	if enemy_dir == 0.0:
		enemy_dir = 1.0
	current_facing = enemy_dir
	if visual_manager and visual_manager.has_method("update_facing"):
		visual_manager.update_facing(enemy_dir)
	elif visual_manager:
		visual_manager.scale.x = absf(visual_manager.scale.x) * enemy_dir
	print("[OL_Character] H 朝向跟隨敵人：", enemy_dir)

# --- 接收來自 H 控制器的訊號 ---

func _on_h_mode_toggled(active: bool):
	if active:
		_cancel_dash(false)
	is_in_h_mode = active
	if dash_visual:
		dash_visual.visible = false
	if normal_visual:
		normal_visual.visible = !active
	if not active:
		_refresh_dash_related_visuals()
		_apply_facing_from_held_input()
	
	if active:
		print("[OL_Character] 手動切換：進入 H 模式，鎖定操控。")
		hand_h = true
	else:
		print("[OL_Character] 手動切換：離開 H 模式。")
		hand_h = false
		# 由怪物觸發 H 時進入分支曾設 hand_h = true，仍須喚醒怪物（舊版只在 hand_h == false 時喚醒會漏掉掙脫）
		if last_attacker and last_attacker.has_method("reactivate_monster"):
			last_attacker.reactivate_monster()
			last_attacker = null
		invincibility_timer = invincible_duration

func _on_h_sequence_finished():
	if not is_in_h_mode:
		return
		
	print("[OL_Character] H 演出結束，恢復玩家操控。")
	is_in_h_mode = false
	hand_h = false
	
	# 恢復視覺顯示
	if dash_visual:
		dash_visual.visible = false
	if normal_visual:
		normal_visual.visible = true
	_refresh_dash_related_visuals()
	_apply_facing_from_held_input()
	
	# 喚醒怪物
	if last_attacker and last_attacker.has_method("reactivate_monster"):
		last_attacker.reactivate_monster()
		last_attacker = null
	
	# 啟動無敵時間
	if !hand_h :
		invincibility_timer = invincible_duration

# --- 輔助功能 ---

func is_invincible() -> bool:
	return invincibility_timer > 0 or dash_invincibility_timer > 0

func _update_flash_effect():
	# 僅 H 結束後無敵閃爍；衝刺無敵不閃
	if invincibility_timer <= 0:
		self.modulate.a = 1.0
	else:
		self.modulate.a = 0.5 if Engine.get_frames_drawn() % 10 < 5 else 1.0

func _smoothstep01(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _dash_end_speed() -> float:
	# 衝刺期間忽略方向鍵；結束時速度歸零
	return 0.0

func _dash_current_speed() -> float:
	var total: float = maxf(dash_total_time, 0.01)
	var elapsed: float = clampf(total - dash_timer, 0.0, total)
	var ease_in: float = maxf(0.0, dash_ease_in)
	var ease_out: float = maxf(0.0, dash_ease_out)
	if ease_in + ease_out > total:
		var shrink: float = total / (ease_in + ease_out)
		ease_in *= shrink
		ease_out *= shrink
	var start_spd: float = dash_start_speed
	var peak_spd: float = dash_speed
	var end_spd: float = _dash_end_speed()
	if elapsed < ease_in and ease_in > 0.0001:
		var u: float = _smoothstep01(elapsed / ease_in)
		return lerpf(start_spd, peak_spd, u)
	if elapsed > total - ease_out and ease_out > 0.0001:
		var u: float = _smoothstep01((total - elapsed) / ease_out)
		return lerpf(end_spd, peak_spd, u)
	return peak_spd

func _dash_end_lean_weight() -> float:
	if dash_timer <= 0.0 or dash_total_time <= 0.0:
		return 0.0
	var total: float = dash_total_time
	var elapsed: float = clampf(total - dash_timer, 0.0, total)
	var window: float = clampf(dash_lean_window, 0.0, total)
	if window <= 0.0001:
		return 0.0
	if elapsed < total - window:
		return 0.0
	return _smoothstep01((elapsed - (total - window)) / window)

func _update_dash_body_lean(delta: float) -> void:
	if visual_manager == null:
		return
	if is_in_h_mode:
		visual_manager.rotation = 0.0
		return
	var target: float = 0.0
	var follow: float = dash_lean_recover
	if dash_timer > 0.0:
		# Godot 2D：正旋轉 = 順時針；右衝 * 正角度、左衝 * 負角度 = 逆時針
		target = deg_to_rad(dash_end_lean_degrees) * dash_direction * _dash_end_lean_weight()
		follow = dash_lean_in_speed
	visual_manager.rotation = lerp_angle(visual_manager.rotation, target, clampf(delta * follow, 0.0, 1.0))

func _init_collision_fit() -> void:
	# 複製 shape，避免改到場景共用的 SubResource
	if body_collision == null:
		body_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_collision == null or body_collision.shape == null:
		print("[OL_Character] Collision Fit：找不到 CollisionShape2D，略過。")
		return
	var rect := body_collision.shape as RectangleShape2D
	if rect == null:
		print("[OL_Character] Collision Fit：目前僅支援 RectangleShape2D。")
		return
	_col_rect = rect.duplicate() as RectangleShape2D
	body_collision.shape = _col_rect
	_col_base_size = _col_rect.size
	_col_base_pos = body_collision.position
	print("[OL_Character] Collision Fit 已初始化：size=", _col_base_size, " pos=", _col_base_pos)

func _update_collision_fit(delta: float) -> void:
	# 狀態縮短（非幾何自適應）：離地從腳縮、地面衝刺從頭頂縮
	if _col_rect == null or body_collision == null:
		return

	var target_feet: float = 0.0
	var target_head: float = 0.0

	if not is_in_h_mode:
		var is_dashing: bool = dash_timer > 0.0
		# 起跳當幀 is_on_floor 可能仍為 true，故一併看向上速度
		var airborne: bool = (not is_on_floor()) or velocity.y < 0.0
		if airborne:
			target_feet = maxf(target_feet, air_shorten_from_feet)
		if is_dashing:
			if airborne:
				target_feet = maxf(target_feet, dash_air_shorten_from_feet)
			else:
				# 地面衝刺若從腳縮會讓碰撞底離地 → 掉落／失去 is_on_floor
				target_head = maxf(target_head, dash_ground_shorten_from_head)

	# 離地縮短：立即到位；落地還原：短時間平滑，避免瞬間上彈頓挫
	var apply_feet: float = target_feet
	if target_feet < _col_apply_feet:
		if land_restore_duration <= 0.001:
			apply_feet = target_feet
		else:
			var restore_span: float = maxf(air_shorten_from_feet, dash_air_shorten_from_feet)
			var restore_speed: float = restore_span / land_restore_duration
			apply_feet = move_toward(_col_apply_feet, target_feet, restore_speed * delta)

	var apply_head: float = target_head
	var new_h: float = maxf(min_collision_height, _col_base_size.y - apply_feet - apply_head)
	var reduced: float = _col_base_size.y - new_h
	apply_feet = minf(apply_feet, reduced)
	apply_head = reduced - apply_feet

	# 還原時腳底會往下「長」→ 每幀上移對應量，讓碰撞底邊世界座標不變（平滑分散）
	var feet_delta: float = apply_feet - _col_apply_feet
	if feet_delta < 0.0:
		# Godot 2D：Y 向下為正；上移 = 減 Y。feet_delta 為負時 += 即上移。
		global_position.y += feet_delta
	_col_apply_feet = apply_feet

	# 矩形以 position 為中心：從腳縮 → 上移中心；從頭頂縮 → 下移中心
	var new_pos: Vector2 = _col_base_pos
	new_pos.y -= apply_feet * 0.5
	new_pos.y += apply_head * 0.5
	_apply_collision_fit(Vector2(_col_base_size.x, new_h), new_pos)

func _apply_collision_fit(size: Vector2, pos: Vector2) -> void:
	_col_rect.size = size
	body_collision.position = pos

func _try_start_dash() -> void:
	if GlobalState.is_paused:
		return
	if dash_cooldown_timer > 0:
		return
	if not Input.is_action_just_pressed("ui_dash"):
		return
	var dir = Input.get_axis("ui_left", "ui_right")
	if dir == 0.0:
		dir = current_facing
	dash_direction = sign(dir)
	if dash_direction == 0.0:
		dash_direction = 1.0
	current_facing = dash_direction
	dash_total_time = max(0.01, dash_duration)
	dash_timer = dash_total_time
	dash_start_speed = maxf(0.0, velocity.x * dash_direction)
	dash_invincibility_timer = max(0.0, dash_invincible_duration)
	if visual_manager:
		visual_manager.update_facing(dash_direction)
	camera_run = 1.0
	_refresh_dash_related_visuals()
	if dash_visual and dash_visual.has_method("on_dash_started"):
		dash_visual.on_dash_started()

func _finish_dash_natural() -> void:
	dash_timer = 0.0
	dash_total_time = 0.0
	dash_cooldown_timer = max(0.0, dash_cooldown)
	_refresh_dash_related_visuals()
	if visual_manager and visual_manager.has_method("on_dash_ended"):
		visual_manager.on_dash_ended()

func _cancel_dash(apply_cooldown: bool) -> void:
	var had_active_dash = dash_timer > 0
	dash_timer = 0.0
	dash_total_time = 0.0
	dash_invincibility_timer = 0.0
	if apply_cooldown and had_active_dash:
		dash_cooldown_timer = max(0.0, dash_cooldown)
	_refresh_dash_related_visuals()

func _refresh_dash_related_visuals() -> void:
	if is_in_h_mode:
		return
	if dash_animation_visual_mode == DashAnimationVisualMode.USE_DASH_VISUAL_FOR_DASH and dash_visual:
		var show_dash = dash_timer > 0
		if dash_visual:
			dash_visual.visible = show_dash
		if normal_visual:
			normal_visual.visible = not show_dash
	else:
		if dash_visual:
			dash_visual.visible = false
		if normal_visual:
			normal_visual.visible = true
