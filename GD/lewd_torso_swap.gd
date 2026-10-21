extends Node2D
## Lewd／Iku：LEWD 開啟時，將女主 Torso 貼圖換成 Lewd（一般抽插）或 Iku（射精階段）。
## 仍沿用既有 Naked／Clothed／ShirtOpen 顯示邏輯（本腳本只換 texture）。
## H_Pose_01／H_Pose_03 無 ShirtOpen：sprite_shirt_open 與對應貼圖可留空。

@export_group("Torso Sprite 節點")
@export var sprite_naked: Sprite2D
@export var sprite_clothed: Sprite2D
## H_Pose_01／03 無此節點，可留空
@export var sprite_shirt_open: Sprite2D

@export_group("Lewd 貼圖（一般抽插）")
@export var lewd_naked: Texture2D
@export var lewd_clothed: Texture2D
@export var lewd_shirt_open: Texture2D

@export_group("Iku 貼圖（射精階段）")
@export var iku_naked: Texture2D
@export var iku_clothed: Texture2D
@export var iku_shirt_open: Texture2D

## 射精階段判定：sequence_stage >= 此值時用 Iku（預設 3）
@export var iku_from_sequence_stage: int = 3

var _normal_naked: Texture2D
var _normal_clothed: Texture2D
var _normal_shirt_open: Texture2D
var _h_controller: Node
var _applied_key: String = ""


func _ready() -> void:
	_resolve_sprites()
	_cache_normal_textures()
	_h_controller = _find_h_controller()
	if not GlobalState.lewd_active_changed.is_connected(_on_lewd_active_changed):
		GlobalState.lewd_active_changed.connect(_on_lewd_active_changed)
	if _h_controller and _h_controller.has_signal("h_sequence_stage_changed"):
		if not _h_controller.h_sequence_stage_changed.is_connected(_on_sequence_stage_changed):
			_h_controller.h_sequence_stage_changed.connect(_on_sequence_stage_changed)
	if _h_controller and _h_controller.has_signal("h_mode_toggled"):
		if not _h_controller.h_mode_toggled.is_connected(_on_h_mode_toggled):
			_h_controller.h_mode_toggled.connect(_on_h_mode_toggled)
	_apply_textures(true)


func _exit_tree() -> void:
	if GlobalState.lewd_active_changed.is_connected(_on_lewd_active_changed):
		GlobalState.lewd_active_changed.disconnect(_on_lewd_active_changed)
	if _h_controller:
		if _h_controller.has_signal("h_sequence_stage_changed") and _h_controller.h_sequence_stage_changed.is_connected(_on_sequence_stage_changed):
			_h_controller.h_sequence_stage_changed.disconnect(_on_sequence_stage_changed)
		if _h_controller.has_signal("h_mode_toggled") and _h_controller.h_mode_toggled.is_connected(_on_h_mode_toggled):
			_h_controller.h_mode_toggled.disconnect(_on_h_mode_toggled)


func _process(_delta: float) -> void:
	# 保險：部分路徑可能未發訊號；僅在父姿勢可見時檢查
	if not is_visible_in_tree():
		return
	_apply_textures(false)


func _on_lewd_active_changed(_active: bool) -> void:
	_apply_textures(true)


func _on_sequence_stage_changed(_stage: int) -> void:
	_apply_textures(true)


func _on_h_mode_toggled(_active: bool) -> void:
	_apply_textures(true)


func _resolve_sprites() -> void:
	if sprite_naked == null:
		sprite_naked = get_node_or_null("Sprite2D_Torso_NAKED") as Sprite2D
	if sprite_clothed == null:
		sprite_clothed = get_node_or_null("Sprite2D_Torso_CLOTHED") as Sprite2D
	if sprite_shirt_open == null:
		sprite_shirt_open = get_node_or_null("Sprite2D_Torso_ShirtOpen") as Sprite2D


func _cache_normal_textures() -> void:
	if sprite_naked:
		_normal_naked = sprite_naked.texture
	if sprite_clothed:
		_normal_clothed = sprite_clothed.texture
	if sprite_shirt_open:
		_normal_shirt_open = sprite_shirt_open.texture


func _find_h_controller() -> Node:
	var n: Node = self
	while n:
		if n is OL_H_Controller:
			return n
		n = n.get_parent()
	return null


func _is_iku_phase() -> bool:
	if _h_controller == null:
		_h_controller = _find_h_controller()
	if _h_controller == null:
		return false
	if not bool(_h_controller.get("is_h_active")):
		return false
	var stage: int = int(_h_controller.get("sequence_stage"))
	return stage >= iku_from_sequence_stage


func _apply_textures(force: bool) -> void:
	var mode: String = "normal"
	if GlobalState.is_lewd_active:
		mode = "iku" if _is_iku_phase() else "lewd"
	if not force and mode == _applied_key:
		return
	_applied_key = mode
	match mode:
		"lewd":
			_set_sprite_tex(sprite_naked, lewd_naked if lewd_naked else _normal_naked)
			_set_sprite_tex(sprite_clothed, lewd_clothed if lewd_clothed else _normal_clothed)
			_set_sprite_tex(sprite_shirt_open, lewd_shirt_open if lewd_shirt_open else _normal_shirt_open)
		"iku":
			_set_sprite_tex(sprite_naked, iku_naked if iku_naked else (lewd_naked if lewd_naked else _normal_naked))
			_set_sprite_tex(sprite_clothed, iku_clothed if iku_clothed else (lewd_clothed if lewd_clothed else _normal_clothed))
			_set_sprite_tex(sprite_shirt_open, iku_shirt_open if iku_shirt_open else (lewd_shirt_open if lewd_shirt_open else _normal_shirt_open))
		_:
			_set_sprite_tex(sprite_naked, _normal_naked)
			_set_sprite_tex(sprite_clothed, _normal_clothed)
			_set_sprite_tex(sprite_shirt_open, _normal_shirt_open)


func _set_sprite_tex(spr: Sprite2D, tex: Texture2D) -> void:
	if spr == null:
		return
	if spr.texture != tex:
		spr.texture = tex
