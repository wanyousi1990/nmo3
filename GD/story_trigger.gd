extends Area2D
## 劇情對話觸發：玩家進入區域（或到點）自動播放 DialogueBox。
## once=true 時寫入 GlobalState.dialogue_flags，之後不再觸發。

signal story_started(dialogue_id: String)

@export_group("對話")
@export var dialogue_id: String = ""
## 是否只播一次（寫入存檔旗標）
@export var once: bool = true
## 存檔旗標鍵；空白且 once 時自動用 "dlg_" + dialogue_id
@export var flag_key: String = ""
## 若非空：必須已有此旗標才會觸發（例如先播完另一段劇情）
@export var require_flag_key: String = ""
## 進入後延遲幾秒再播（避開剛換場／落地）
@export_range(0.0, 5.0, 0.05) var start_delay: float = 0.0
## once=false 時：離開觸發區再進入是否可再播。
## false＝本次進場只播一次（換場景回來才再播）；true＝同場景內走出再進也可再播
@export var retrigger_on_reenter: bool = true

var _player_inside: bool = false
var _triggered_this_stay: bool = false
var _pending: bool = false
var _retry_scheduled: bool = false ## 進場／轉場時條件不符，稍後重試中


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	print("StoryTrigger 就緒 id=", dialogue_id, " once=", once, " retrigger=", retrigger_on_reenter, " flag=", _resolved_flag_key())
	# 出生就重疊時 Godot 不會發 body_entered → 等物理同步後主動檢查
	call_deferred("_detect_initial_overlap")


func _detect_initial_overlap() -> void:
	await get_tree().physics_frame
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _resolved_flag_key() -> String:
	if not flag_key.is_empty():
		return flag_key
	if once and not dialogue_id.is_empty():
		return "dlg_" + dialogue_id
	return ""


func _already_seen() -> bool:
	if not once:
		return false
	var key: String = _resolved_flag_key()
	if key.is_empty():
		return false
	return GlobalState.has_dialogue_flag(key)


func _can_start() -> bool:
	if dialogue_id.is_empty():
		return false
	if not require_flag_key.is_empty() and not GlobalState.has_dialogue_flag(require_flag_key):
		return false
	if _already_seen():
		return false
	if DialogueBox.is_dialogue_open:
		return false
	if ProgressionShop.is_shop_open:
		return false
	if GlobalState.is_paused or GlobalState.changing_scene:
		return false
	if HSystem.is_h_mode_active():
		return false
	return true


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return
	_player_inside = true
	if retrigger_on_reenter:
		_triggered_this_stay = false
	print("StoryTrigger 進入範圍 id=", dialogue_id)
	_try_start()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_inside = false
		# 僅在允許「走出再進再播」時清掉；否則保留，直到本場景節點銷毀
		if retrigger_on_reenter:
			_triggered_this_stay = false
		print("StoryTrigger 離開範圍 id=", dialogue_id)


func _try_start() -> void:
	if not _player_inside:
		return
	if _triggered_this_stay:
		return
	if not _can_start():
		print("StoryTrigger 略過（條件不符）id=", dialogue_id, " seen=", _already_seen(), " changing=", GlobalState.changing_scene)
		# 轉場／對話進行中被擋：人還在範圍內就排程重試（否則要走出再進來才會觸發）
		_schedule_retry_when_ready()
		return
	if _pending:
		return
	_pending = true
	_triggered_this_stay = true
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	_pending = false
	if not _player_inside:
		_triggered_this_stay = false
		return
	if not _can_start():
		_triggered_this_stay = false
		_schedule_retry_when_ready()
		return
	var key: String = _resolved_flag_key() if once else ""
	var ok: bool = DialogueBox.start(dialogue_id, key)
	print("StoryTrigger 自動對話 id=", dialogue_id, " flag=", key, " ok=", ok)
	if ok:
		story_started.emit(dialogue_id)
	else:
		_triggered_this_stay = false
		_schedule_retry_when_ready()


## 等轉場結束等暫時條件解除後再試一次（玩家仍需待在範圍內）
func _schedule_retry_when_ready() -> void:
	if _retry_scheduled:
		return
	if not _player_inside or _already_seen():
		return
	_retry_scheduled = true
	print("StoryTrigger 排程重試 id=", dialogue_id)
	while _player_inside and not _already_seen() and not _triggered_this_stay:
		await get_tree().process_frame
		if _can_start() and not _pending:
			_retry_scheduled = false
			_try_start()
			return
	_retry_scheduled = false
