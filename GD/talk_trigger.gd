extends Area2D
## 人物對話觸發：玩家進入範圍後按 **shop_open**（Enter）開啟 DialogueBox。
## 在 Inspector 填 dialogue_id（對應 TRES/dialogue_table.tres 總表）。
## use_host_handler=true 時改呼叫父節點 on_talk_interact()（守關怪等自訂流程）。

@export_group("對話")
@export var dialogue_id: String = ""
## 改由父節點處理互動（需實作 on_talk_interact）
@export var use_host_handler: bool = false
## 關閉後不顯示提示、不可互動（乳交覺醒後關閉）
@export var interaction_enabled: bool = true

@export_group("提示字")
@export var prompt_text: String = "[ENTER]"
@export var prompt_offset: Vector2 = Vector2(0, -48)
@export var prompt_font_size: int = 10
@export var prompt_color: Color = Color(0.78, 0.42, 1.0, 1.0)
@export var prompt_outline_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0, 12, 1) var prompt_outline_size: int = 4
@export var prompt_z_index: int = 20

var _player_inside: bool = false
var _prompt: Label
var _prompt_was_visible: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	_setup_prompt()
	print("TalkTrigger 就緒 id=", dialogue_id, " host=", use_host_handler)


func _process(_delta: float) -> void:
	_update_prompt_visible()


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
	_prompt.visible = false
	_prompt_was_visible = false


func _can_interact() -> bool:
	if not interaction_enabled:
		return false
	if not _player_inside:
		return false
	if not use_host_handler and dialogue_id.is_empty():
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


func _update_prompt_visible() -> void:
	if _prompt == null:
		return
	var show: bool = _can_interact()
	if show == _prompt_was_visible:
		_prompt.visible = show
		return
	_prompt_was_visible = show
	_prompt.visible = show
	print("TalkTrigger 提示: ", "顯示" if show else "隱藏", " id=", dialogue_id)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_inside = true
		print("TalkTrigger 進入範圍 id=", dialogue_id)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_inside = false
		print("TalkTrigger 離開範圍 id=", dialogue_id)


func _input(event: InputEvent) -> void:
	if not _can_interact():
		return
	if event.is_action_pressed("shop_open"):
		if use_host_handler:
			var host: Node = get_parent()
			if host != null and host.has_method("on_talk_interact"):
				host.call("on_talk_interact")
				print("TalkTrigger 交由 host 處理: ", host.name)
			else:
				push_warning("TalkTrigger: use_host_handler 但父節點無 on_talk_interact")
		else:
			var ok: bool = DialogueBox.start(dialogue_id)
			print("TalkTrigger 開啟對話 id=", dialogue_id, " ok=", ok)
		get_viewport().set_input_as_handled()
