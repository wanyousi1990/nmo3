extends "res://GD/female_monster.gd"
## 守關怪（female_monster 原型）。
## 未乳交：normal 手臂／軀幹、不追不 H、只面向女主、可 TalkTrigger。
## 乳交「射精階段」完成後才覺醒。中途掙脫不算。

@export_group("Gatekeeper")
@export var normal_arm_l_texture: Texture2D
@export var normal_arm_r_texture: Texture2D
@export var normal_torso_texture: Texture2D
@export var awakened_flag_key: String = "gate_fm_awakened"
@export var talked_flag_key: String = "gate_fm_talked"
@export var dialogue_first_id: String = "gate_fm_first"
@export var dialogue_repeat_id: String = "gate_fm_repeat"
@export var dialogue_fallback_id: String = "gate_fm_fallback"
@export var paizuri_unlock_key: String = "paizuri_2"
@export var fixed_h_pose_tag: String = "TITS_FUCK_02"

var _sprite_arm_l: Sprite2D
var _sprite_arm_r: Sprite2D
var _sprite_torso: Sprite2D
var _orig_arm_l: Texture2D
var _orig_arm_r: Texture2D
var _orig_torso: Texture2D
var _awakened: bool = false
var _talk_busy: bool = false
var _talk_trigger: Area2D
var _consent_reached_climax: bool = false
var _consent_hc: Node = null


func _ready() -> void:
	h_pose_tags = [fixed_h_pose_tag]
	super._ready()
	_sprite_arm_l = get_node_or_null("Visaul/Pelvis/Torso/Arm_L/Sprite2D_Arm_L") as Sprite2D
	_sprite_arm_r = get_node_or_null("Visaul/Pelvis/Arm_R/Sprite2D_Arm_R") as Sprite2D
	_sprite_torso = get_node_or_null("Visaul/Pelvis/Torso/Sprite2D_Torso") as Sprite2D
	if _sprite_arm_l:
		_orig_arm_l = _sprite_arm_l.texture
	if _sprite_arm_r:
		_orig_arm_r = _sprite_arm_r.texture
	if _sprite_torso:
		_orig_torso = _sprite_torso.texture
	_talk_trigger = get_node_or_null("TalkTrigger") as Area2D
	if _talk_trigger:
		_talk_trigger.set("use_host_handler", true)
		_talk_trigger.set("dialogue_id", "")
	_awakened = GlobalState.has_dialogue_flag(awakened_flag_key)
	_apply_awakened_visual(_awakened)
	_set_talk_enabled(not _awakened)
	print("[GatekeeperFM] 就緒 awakened=", _awakened)


func _handle_patrol(_delta: float) -> void:
	if _awakened:
		super._handle_patrol(_delta)
		return
	velocity.x = move_toward(velocity.x, 0.0, acceleration * _delta)
	GatekeeperUtil.face_nearest_player(self)


func _switch_to_start_chase(player: Node2D) -> void:
	if not _awakened:
		return
	super._switch_to_start_chase(player)


func _on_chase_entered(body: Node2D) -> void:
	if not _awakened:
		return
	super._on_chase_entered(body)


func _on_detection_body_entered(body: Node2D) -> void:
	if not _awakened:
		return
	super._on_detection_body_entered(body)


func _trigger_player_h(player: CharacterBody2D) -> void:
	if not _awakened:
		return
	super._trigger_player_h(player)


func _pick_h_pose_tag() -> String:
	return fixed_h_pose_tag


func on_talk_interact() -> void:
	if _awakened or _talk_busy:
		return
	_talk_busy = true
	print("[GatekeeperFM] 開始對話流程")
	var accept: bool = await GatekeeperUtil.await_gate_talk(
		talked_flag_key,
		dialogue_first_id,
		dialogue_repeat_id,
		dialogue_fallback_id,
		paizuri_unlock_key
	)
	if accept:
		_start_consent_h()
	_talk_busy = false


func _start_consent_h() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var players: Array[Node] = tree.get_nodes_in_group("Player")
	if players.is_empty():
		return
	var player: CharacterBody2D = players[0] as CharacterBody2D
	if player == null:
		return
	current_state = State.HIDDEN
	visible = false
	anim_phase = 0.0
	_consent_reached_climax = false
	_consent_hc = player.get("h_controller")
	if _consent_hc != null:
		if _consent_hc.has_signal("h_sequence_stage_changed"):
			if not _consent_hc.h_sequence_stage_changed.is_connected(_on_consent_stage_changed):
				_consent_hc.h_sequence_stage_changed.connect(_on_consent_stage_changed)
		if _consent_hc.has_signal("h_mode_finished"):
			if not _consent_hc.h_mode_finished.is_connected(_on_consent_h_finished):
				_consent_hc.h_mode_finished.connect(_on_consent_h_finished, CONNECT_ONE_SHOT)
	print("[GatekeeperFM] 同意乳交 → ", fixed_h_pose_tag)
	player.start_h_event(self, fixed_h_pose_tag)


func _on_consent_stage_changed(stage: int) -> void:
	if stage >= 3:
		_consent_reached_climax = true
		print("[GatekeeperFM] 已進入射精階段")


func _on_consent_h_finished() -> void:
	_disconnect_consent_signals()
	if _awakened:
		return
	if not _consent_reached_climax:
		print("[GatekeeperFM] 中途掙脫／未射精 → 仍為守關狀態")
		return
	_awakened = true
	GlobalState.set_dialogue_flag(awakened_flag_key)
	_apply_awakened_visual(true)
	_set_talk_enabled(false)
	print("[GatekeeperFM] 射精完成 → 覺醒為一般怪物")


func _disconnect_consent_signals() -> void:
	if _consent_hc != null and is_instance_valid(_consent_hc):
		if _consent_hc.has_signal("h_sequence_stage_changed"):
			if _consent_hc.h_sequence_stage_changed.is_connected(_on_consent_stage_changed):
				_consent_hc.h_sequence_stage_changed.disconnect(_on_consent_stage_changed)
	_consent_hc = null


func _apply_awakened_visual(awake: bool) -> void:
	if awake:
		if _sprite_arm_l and _orig_arm_l:
			_sprite_arm_l.texture = _orig_arm_l
		if _sprite_arm_r and _orig_arm_r:
			_sprite_arm_r.texture = _orig_arm_r
		if _sprite_torso and _orig_torso:
			_sprite_torso.texture = _orig_torso
	else:
		if _sprite_arm_l and normal_arm_l_texture:
			_sprite_arm_l.texture = normal_arm_l_texture
		if _sprite_arm_r and normal_arm_r_texture:
			_sprite_arm_r.texture = normal_arm_r_texture
		if _sprite_torso and normal_torso_texture:
			_sprite_torso.texture = normal_torso_texture


func _set_talk_enabled(enabled: bool) -> void:
	if _talk_trigger == null:
		return
	_talk_trigger.set("interaction_enabled", enabled)
	_talk_trigger.monitoring = enabled
	_talk_trigger.monitorable = false
	print("[GatekeeperFM] TalkTrigger=", enabled)
