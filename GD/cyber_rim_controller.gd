extends Node
## 賽博輪廓：
## A) SPRITE_EDGE：SubViewport 合成整隻角色／怪物 → 對輸出貼圖邊緣染色（Compatibility）。
##    色調：vp_host.modulate = body_tint；場景 CanvasModulate 經 shader MODULATE 生效。
## B) MASKED_LIGHTS：左右燈只打到角色 light_mask。

enum Mode {
	SPRITE_EDGE,
	MASKED_LIGHTS,
}

@export_group("開關")
@export var effect_enabled: bool = true
@export var mode: Mode = Mode.SPRITE_EDGE

@export_group("房間邊界（世界 X）")
@export var room_left_x: float = -768.0
@export var room_right_x: float = 768.0

@export_group("霓虹色")
@export var color_left: Color = Color(0.15, 1.0, 1.0, 1.0)
@export var color_right: Color = Color(1.0, 0.2, 0.95, 1.0)

@export_group("邊緣染色（Mode A）")
@export_range(0.5, 12.0, 0.1) var rim_px: float = 2.5
@export_range(0.0, 10.0, 0.1) var rim_strength: float = 4.5
@export_range(0.0, 5.0, 0.05) var wall_boost: float = 1.5
## 女主／怪物整體色調 #948fb3
@export var body_tint: Color = Color(0.580392, 0.560784, 0.701961, 1.0)
@export var apply_body_tint: bool = true ## 開關：乘上 body_tint
@export var apply_scene_canvas_modulate: bool = true ## 開關：乘上場景 CanvasModulate
@export var viewport_size: Vector2 = Vector2(320, 420)
@export var visuals_pos_in_viewport: Vector2 = Vector2(160, 300)
@export var enemy_viewport_size: Vector2 = Vector2(280, 360)
@export var enemy_visuals_pos_in_viewport: Vector2 = Vector2(140, 260)

@export_group("遮罩燈（Mode B）")
@export_range(0.0, 8.0, 0.05) var light_base_energy: float = 2.0
@export_range(0.5, 12.0, 0.1) var light_texture_scale: float = 2.8
@export var light_offset_l: Vector2 = Vector2(-40, -24)
@export var light_offset_r: Vector2 = Vector2(40, -24)
@export var light_texture: Texture2D
@export var cyber_light_bit: int = 2

@export_group("除錯")
@export var debug_prove_on: bool = false
@export var debug_log_every_sec: float = 2.0

@export_group("引用")
@export var player: Node2D
@export var enemies_root: Node2D
@export var light_a: PointLight2D
@export var light_b: PointLight2D

const SHADER_PATH := "res://cyber_rim.gdshader"
const DEFAULT_LIGHT_TEX := "res://TRES/radial_light_texture.tres"
const HOST_NAME := "CyberRimLightHost"
const VP_HOST_NAME := "CyberRimViewportHost"

var _shader: Shader
## body(Node) -> { host, vp, visuals, mat, is_player }
var _targets: Dictionary = {}
var _orig_light_masks: Dictionary = {}
var _host: Node2D
var _light_l: PointLight2D
var _light_r: PointLight2D
var _log_left: float = 0.0
var _nuke_frames_left: int = 3
var _active_mode: int = -1
var _h_hooked: bool = false


func _ready() -> void:
	_nuke_old_overlays()
	_unwrap_any_canvas_groups()
	_resolve_refs()
	_hook_h_signals()
	if effect_enabled:
		_apply_mode(true)
	set_process(true)
	print("[CyberRim] 就緒 mode=", _mode_name(), " enabled=", effect_enabled)


func _exit_tree() -> void:
	_teardown_all()


func _process(delta: float) -> void:
	if _nuke_frames_left > 0:
		_nuke_old_overlays()
		_nuke_frames_left -= 1

	if not effect_enabled:
		if _active_mode != -1:
			_teardown_all()
		return

	if player == null or not is_instance_valid(player):
		_resolve_refs()
		_hook_h_signals()

	if _active_mode != int(mode):
		_apply_mode(true)

	match mode:
		Mode.SPRITE_EDGE:
			_ensure_all_viewports()
			_push_all_uniforms()
		Mode.MASKED_LIGHTS:
			if _host == null or not is_instance_valid(_host):
				_build_masked_lights()
			_update_masked_lights()
			_ensure_target_light_masks()

	if debug_log_every_sec > 0.0:
		_log_left -= delta
		if _log_left <= 0.0:
			_log_left = debug_log_every_sec
			print("[CyberRim] ", _mode_name(), " targets=", _targets.size())


func set_room_bounds(left_x: float, right_x: float) -> void:
	room_left_x = left_x
	room_right_x = right_x
	print("[CyberRim] room bounds X=", left_x, " ~ ", right_x)


func refresh_targets() -> void:
	_resolve_refs()
	_hook_h_signals()
	if effect_enabled:
		_apply_mode(false)


func _mode_name() -> String:
	return "SPRITE_EDGE" if mode == Mode.SPRITE_EDGE else "MASKED_LIGHTS"


func _apply_mode(force_rebuild: bool) -> void:
	if force_rebuild or _active_mode != int(mode):
		_teardown_all()
	_active_mode = int(mode)
	match mode:
		Mode.SPRITE_EDGE:
			_ensure_shader()
			_ensure_all_viewports()
			_push_all_uniforms()
			print("[CyberRim] Mode A 整體輪廓 targets=", _targets.size(), "（視口內不壓暗）")
		Mode.MASKED_LIGHTS:
			_build_masked_lights()
			_ensure_target_light_masks()
			_update_masked_lights()
			print("[CyberRim] Mode B 遮罩燈")


func _teardown_all() -> void:
	_restore_all_viewports()
	_restore_light_masks()
	if _host and is_instance_valid(_host):
		_host.queue_free()
	_host = null
	_light_l = null
	_light_r = null
	_active_mode = -1


func _resolve_refs() -> void:
	if player == null or not is_instance_valid(player):
		player = null
		var parent := get_parent()
		if parent:
			player = parent.get_node_or_null("CharacterBody2D") as Node2D
		if player == null:
			player = get_node_or_null("../CharacterBody2D") as Node2D
		if player == null and get_tree():
			player = get_tree().get_first_node_in_group("Player") as Node2D
	if enemies_root == null or not is_instance_valid(enemies_root):
		enemies_root = null
		var p2 := get_parent()
		if p2:
			enemies_root = p2.get_node_or_null("Enemies") as Node2D


func _hook_h_signals() -> void:
	if _h_hooked or player == null:
		return
	var h := player.find_child("OL_H_Visual", true, false)
	if h == null:
		return
	if h.has_signal("h_mode_toggled") and not h.h_mode_toggled.is_connected(_on_h_mode_toggled):
		h.h_mode_toggled.connect(_on_h_mode_toggled)
	_h_hooked = true


func _on_h_mode_toggled(_active: bool) -> void:
	if mode == Mode.SPRITE_EDGE and effect_enabled:
		_push_all_uniforms()


func _wall_t_for(body: Node2D) -> float:
	var span: float = maxf(room_right_x - room_left_x, 1.0)
	var x: float = room_left_x + span * 0.5
	if body and is_instance_valid(body):
		x = body.global_position.x
	return clampf((x - room_left_x) / span, 0.0, 1.0)


func _flip_h_for(_visuals: Node2D) -> float:
	# 面向已畫進 SubViewport，左右色固定：左青右紅
	return 0.0


func _ensure_shader() -> void:
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	if _shader == null:
		push_error("[CyberRim] 找不到 ", SHADER_PATH)


func _make_rim_mat() -> ShaderMaterial:
	_ensure_shader()
	if _shader == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.resource_local_to_scene = true
	return m


func _push_all_uniforms() -> void:
	var scene_cm := _read_scene_canvas_modulate()
	for body in _targets.keys():
		if not is_instance_valid(body):
			continue
		var t: Dictionary = _targets[body]
		var m: ShaderMaterial = t.get("mat")
		var host: SubViewportContainer = t.get("host")
		if m == null:
			continue
		# 避免 Godot 再經 MODULATE 乘一次；色調全由 shader uniform 控制
		if host and is_instance_valid(host):
			host.modulate = Color.WHITE
			host.self_modulate = Color.WHITE
		m.set_shader_parameter("color_left", color_left)
		m.set_shader_parameter("color_right", color_right)
		m.set_shader_parameter("rim_px", rim_px)
		m.set_shader_parameter("rim_strength", rim_strength)
		m.set_shader_parameter("wall_boost", wall_boost)
		m.set_shader_parameter("wall_t", _wall_t_for(body as Node2D))
		m.set_shader_parameter("debug_prove_on", 1.0 if debug_prove_on else 0.0)
		m.set_shader_parameter("scene_modulate", scene_cm)
		m.set_shader_parameter("body_tint", body_tint)
		m.set_shader_parameter("use_scene_modulate", 1.0 if apply_scene_canvas_modulate else 0.0)
		m.set_shader_parameter("use_body_tint", 1.0 if apply_body_tint else 0.0)


func _read_scene_canvas_modulate() -> Color:
	if get_tree() == null or get_tree().current_scene == null:
		return Color.WHITE
	var cm := get_tree().current_scene.get_node_or_null("CanvasModulate") as CanvasModulate
	if cm:
		return cm.color
	return Color.WHITE


func _ensure_all_viewports() -> void:
	_resolve_refs()
	if player:
		var p_vis := _find_visuals_node(player)
		if p_vis:
			_ensure_body_viewport(player, p_vis, viewport_size, visuals_pos_in_viewport, true)
	if enemies_root:
		for enemy in enemies_root.get_children():
			if not is_instance_valid(enemy):
				continue
			# 略過非角色節點（例如殘留 host）
			if String(enemy.name) == VP_HOST_NAME:
				continue
			var e_vis := _find_visuals_node(enemy)
			if e_vis:
				_ensure_body_viewport(enemy, e_vis, enemy_viewport_size, enemy_visuals_pos_in_viewport, false)


func _find_visuals_node(body: Node) -> Node2D:
	if body == null:
		return null
	# 已在視口內
	var host := body.get_node_or_null(VP_HOST_NAME)
	if host:
		var v := host.find_child("Visuals", true, false) as Node2D
		if v == null:
			v = host.find_child("Visaul", true, false) as Node2D
		if v:
			return v
	var v2 := body.get_node_or_null("Visuals") as Node2D
	if v2:
		return v2
	v2 = body.get_node_or_null("Visaul") as Node2D
	if v2:
		return v2
	return body.find_child("Visuals", true, false) as Node2D


func _ensure_body_viewport(body: Node, visuals: Node2D, vp_size: Vector2, vis_pos: Vector2, is_player: bool) -> void:
	if body == null or visuals == null or not is_instance_valid(visuals):
		return
	_ensure_shader()

	var entry: Dictionary = _targets.get(body, {})
	var mat: ShaderMaterial = entry.get("mat")
	if mat == null:
		mat = _make_rim_mat()
		if mat == null:
			return

	var vp_host := body.get_node_or_null(VP_HOST_NAME) as SubViewportContainer
	if vp_host == null:
		vp_host = SubViewportContainer.new()
		vp_host.name = VP_HOST_NAME
		vp_host.stretch = true
		vp_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(vp_host)

	var vp := vp_host.get_node_or_null("SubViewport") as SubViewport
	if vp == null:
		vp = SubViewport.new()
		vp.name = "SubViewport"
		vp.transparent_bg = true
		vp.handle_input_locally = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp_host.add_child(vp)

	# 視口內不放場景 CanvasModulate（避免雙重壓暗）；body_tint 用 host.modulate
	var old_cm := vp.get_node_or_null("CanvasModulate")
	if old_cm:
		old_cm.queue_free()

	vp.size = Vector2i(int(vp_size.x), int(vp_size.y))
	vp_host.size = vp_size
	vp_host.position = -vis_pos
	vp_host.material = mat
	vp_host.modulate = Color.WHITE
	vp_host.self_modulate = Color.WHITE

	# 怪物：偵測 Area2D 留在身體上，不要進視口
	if not is_player and visuals.get_parent() != vp:
		_extract_gameplay_areas(visuals, body)

	if visuals.get_parent() != vp:
		var p := visuals.get_parent()
		if p:
			p.remove_child(visuals)
		vp.add_child(visuals)
		visuals.position = vis_pos
		visuals.rotation = 0.0
		visuals.owner = body
		if is_player and "parent" in visuals and body is CharacterBody2D:
			visuals.set("parent", body)
		print("[CyberRim] ", body.name, " 視覺 → SubViewport（不壓暗）")
	else:
		visuals.position = vis_pos

	_targets[body] = {
		"host": vp_host,
		"vp": vp,
		"visuals": visuals,
		"mat": mat,
		"is_player": is_player,
	}


func _extract_gameplay_areas(visuals: Node, body: Node) -> void:
	if visuals == null or body == null:
		return
	var to_move: Array[Node] = []
	for c in visuals.get_children():
		if c is Area2D or c is RayCast2D:
			to_move.append(c)
	for c in to_move:
		var gf: Transform2D
		var is_n2d := c is Node2D
		if is_n2d:
			gf = (c as Node2D).global_transform
		visuals.remove_child(c)
		body.add_child(c)
		if is_n2d:
			(c as Node2D).global_transform = gf
		print("[CyberRim] 保留偵測節點於身體: ", c.name)


func _restore_all_viewports() -> void:
	for body in _targets.keys():
		if not is_instance_valid(body):
			continue
		var t: Dictionary = _targets[body]
		var visuals: Node2D = t.get("visuals")
		var host: Node = t.get("host")
		if visuals and is_instance_valid(visuals) and visuals.get_parent() != body:
			var p := visuals.get_parent()
			if p:
				p.remove_child(visuals)
			body.add_child(visuals)
			visuals.position = Vector2.ZERO
		if host and is_instance_valid(host):
			host.queue_free()
	_targets.clear()
	# 掃殘留 host
	if player:
		var h := player.get_node_or_null(VP_HOST_NAME)
		if h:
			h.queue_free()
	if enemies_root:
		for enemy in enemies_root.get_children():
			var h2 := enemy.get_node_or_null(VP_HOST_NAME)
			if h2:
				h2.queue_free()


func _unwrap_any_canvas_groups() -> void:
	var roots: Array[Node] = []
	if player:
		roots.append(player)
	if enemies_root:
		roots.append(enemies_root)
	for r in roots:
		_unwrap_cg_recursive(r)


func _unwrap_cg_recursive(n: Node) -> void:
	if n == null:
		return
	for c in n.get_children():
		_unwrap_cg_recursive(c)
	if n is CanvasGroup and String(n.name).begins_with("CyberRim"):
		var cg := n as CanvasGroup
		var parent := cg.get_parent()
		if parent == null:
			return
		var idx := cg.get_index()
		for ch in cg.get_children().duplicate():
			cg.remove_child(ch)
			parent.add_child(ch)
			parent.move_child(ch, idx)
			idx += 1
		cg.queue_free()


# ---------- Mode B ----------

func _build_masked_lights() -> void:
	_resolve_refs()
	if player == null:
		return
	var old := player.get_node_or_null(HOST_NAME)
	if old:
		old.queue_free()
	_host = Node2D.new()
	_host.name = HOST_NAME
	player.add_child(_host)
	var tex: Texture2D = light_texture
	if tex == null:
		tex = load(DEFAULT_LIGHT_TEX) as Texture2D
	_light_l = _make_light("CyberRimLightL", color_left, light_offset_l, tex)
	_light_r = _make_light("CyberRimLightR", color_right, light_offset_r, tex)
	_host.add_child(_light_l)
	_host.add_child(_light_r)


func _make_light(light_name: String, col: Color, offset: Vector2, tex: Texture2D) -> PointLight2D:
	var L := PointLight2D.new()
	L.name = light_name
	L.color = col
	L.energy = light_base_energy
	L.texture = tex
	L.texture_scale = light_texture_scale
	L.position = offset
	L.range_item_cull_mask = cyber_light_bit
	return L


func _update_masked_lights() -> void:
	if _light_l == null or _light_r == null:
		return
	_light_l.color = color_left
	_light_r.color = color_right
	_light_l.position = light_offset_l
	_light_r.position = light_offset_r
	_light_l.texture_scale = light_texture_scale
	_light_r.texture_scale = light_texture_scale
	_light_l.range_item_cull_mask = cyber_light_bit
	_light_r.range_item_cull_mask = cyber_light_bit
	var t: float = _wall_t_for(player as Node2D) if player else 0.5
	if debug_prove_on:
		_light_l.energy = light_base_energy * (1.2 + wall_boost)
		_light_r.energy = light_base_energy * (1.2 + wall_boost)
	else:
		_light_l.energy = light_base_energy * (0.45 + (1.0 - t) * wall_boost)
		_light_r.energy = light_base_energy * (0.45 + t * wall_boost)


func _ensure_target_light_masks() -> void:
	_resolve_refs()
	if player:
		var vis := _find_visuals_node(player)
		if vis:
			_or_light_mask_recursive(vis)
	if enemies_root:
		for c in enemies_root.get_children():
			_or_light_mask_recursive(c)


func _or_light_mask_recursive(n: Node) -> void:
	if n == null:
		return
	if n is CanvasItem:
		var ci := n as CanvasItem
		if not _orig_light_masks.has(ci):
			_orig_light_masks[ci] = ci.light_mask
		ci.light_mask = int(_orig_light_masks[ci]) | cyber_light_bit
	for c in n.get_children():
		_or_light_mask_recursive(c)


func _restore_light_masks() -> void:
	for ci in _orig_light_masks.keys():
		if is_instance_valid(ci) and ci is CanvasItem:
			(ci as CanvasItem).light_mask = int(_orig_light_masks[ci])
	_orig_light_masks.clear()


func _nuke_old_overlays() -> void:
	for c in get_children():
		if _is_old_overlay(c):
			c.queue_free()
	var scene := get_tree().current_scene if get_tree() else null
	if scene:
		_nuke_recursive(scene)


func _nuke_recursive(n: Node) -> void:
	if n == null:
		return
	for c in n.get_children():
		_nuke_recursive(c)
	if n != self and _is_old_overlay(n):
		n.queue_free()


func _is_old_overlay(n: Node) -> bool:
	var nm := String(n.name)
	return nm == "CyberRimOverlay" \
		or nm == "CyberRimLocalHost" \
		or nm == "CyberRimRect" \
		or nm == "CyberRimBackBuffer"
