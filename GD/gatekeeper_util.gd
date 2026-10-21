class_name GatekeeperUtil
extends Object
## 守關怪共用：對話 →（乳交解鎖則 Yes/No，否則 fallback）→ 是否同意乳交。

## 回傳 true = 玩家選「要」並應開始乳交 H。
static func await_gate_talk(
	talked_flag: String,
	first_id: String,
	repeat_id: String,
	fallback_id: String,
	paizuri_key: String
) -> bool:
	var dialogue_id: String = repeat_id if GlobalState.has_dialogue_flag(talked_flag) else first_id
	if not DialogueBox.start(dialogue_id):
		print("[GatekeeperUtil] 無法開啟對話 id=", dialogue_id)
		return false
	await DialogueBox.dialogue_finished
	GlobalState.set_dialogue_flag(talked_flag)

	if GlobalState.is_progression_item_owned(paizuri_key):
		# 要=0 / 不要=1；紫框游標
		var choice: int = await DialogueBox.prompt_choice("Yes", "No", "する", "しない")
		print("[GatekeeperUtil] 選項=", choice, " key=", paizuri_key)
		return choice == 0

	if not fallback_id.is_empty():
		if DialogueBox.start(fallback_id):
			await DialogueBox.dialogue_finished
	return false


## 面向最近的 Player（不移動）
static func face_nearest_player(monster: CharacterBody2D) -> void:
	if monster == null or not is_instance_valid(monster):
		return
	var tree := monster.get_tree()
	if tree == null:
		return
	var players: Array[Node] = tree.get_nodes_in_group("Player")
	if players.is_empty():
		return
	var player: Node2D = players[0] as Node2D
	if player == null:
		return
	var dir: int = 1 if player.global_position.x >= monster.global_position.x else -1
	if "direction" in monster:
		monster.direction = dir
	if monster.has_method("_update_sprite_direction"):
		monster.call("_update_sprite_direction")
