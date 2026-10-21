extends "res://GD/monster_01.gd"
## 守關怪（monster01 原型）。
## 未乳交：normal 骨盆外觀、不追不 H、只面向女主、可 TalkTrigger。
## 乳交「射精階段」完成後才覺醒：還原怪物外觀與 AI，並關閉對話。中途掙脫不算。

@export_group("Gatekeeper")
@export var normal_pelvis_texture: Texture2D
@export var awakened_flag_key: String = "gate_m01_awakened"
@export var talked_flag_key: String = "gate_m01_talked"
@export var dialogue_first_id: String = "gate_m01_first"
@export var dialogue_repeat_id: String = "gate_m01_repeat"
@export var dialogue_fallback_id: String = "gate_m01_fallback"
@export var paizuri_unlock_key: String = "paizuri_1"
@export var fixed_h_pose_tag: String = "TITS_FUCK_01"

var _pelvis_sprite: Sprite2D
var _original_pelvis_texture: Texture2D
var _awakened: bool = false
var _talk_busy: bool = false
var _talk_trigger: Area2D
var _consent_reached_climax: bool = false
var _consent_hc: Node = null


func _ready() -> void:
	h_pose_tags = [fixed_h_pose_tag]
	super._ready()
	_pelvis_sprite = get_node_or_null("Visaul/Pelvis/Sprite2D_Pelvis") as Sprite2D
	if _pelvis_sprite:
		_original_pelvis_texture = _pelvis_sprite.texture
	_talk_trigger = get_node_or_null("TalkTrigger") as Area2D
	if _talk_trigger:
		_talk_trigger.set("use_host_handler", true)
		_talk_trigger.set("dialogue_id", "")
	_awakened = GlobalState.has_dialogue_flag(awakened_flag_key)
	_apply_awakened_visual(_awakened)
	_set_talk_enabled(not _awakened)
	print("[GatekeeperM01] 就緒 awakened=", _awakened)


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
	print("[GatekeeperM01] 開始對話流程")
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
	print("[GatekeeperM01] 同意乳交 → ", fixed_h_pose_tag)
	player.start_h_event(self, fixed_h_pose_tag)


func _on_consent_stage_changed(stage: int) -> void:
	# 進入射精階段（stage 3）才算完成
	if stage >= 3:
		_consent_reached_climax = true
		print("[GatekeeperM01] 已進入射精階段")


func _on_consent_h_finished() -> void:
	_disconnect_consent_signals()
	if _awakened:
		return
	if not _consent_reached_climax:
		print("[GatekeeperM01] 中途掙脫／未射精 → 仍為守關狀態")
		return
	_awakened = true
	GlobalState.set_dialogue_flag(awakened_flag_key)
	_apply_awakened_visual(true)
	_set_talk_enabled(false)
	print("[GatekeeperM01] 射精完成 → 覺醒為一般怪物")


func _disconnect_consent_signals() -> void:
	if _consent_hc != null and is_instance_valid(_consent_hc):
		if _consent_hc.has_signal("h_sequence_stage_changed"):
			if _consent_hc.h_sequence_stage_changed.is_connected(_on_consent_stage_changed):
				_consent_hc.h_sequence_stage_changed.disconnect(_on_consent_stage_changed)
	_consent_hc = null


func _apply_awakened_visual(awake: bool) -> void:
	if _pelvis_sprite == null:
		return
	if awake:
		if _original_pelvis_texture:
			_pelvis_sprite.texture = _original_pelvis_texture
	elif normal_pelvis_texture:
		_pelvis_sprite.texture = normal_pelvis_texture


func _set_talk_enabled(enabled: bool) -> void:
	if _talk_trigger == null:
		return
	_talk_trigger.set("interaction_enabled", enabled)
	_talk_trigger.monitoring = enabled
	_talk_trigger.monitorable = false
	print("[GatekeeperM01] TalkTrigger=", enabled)
