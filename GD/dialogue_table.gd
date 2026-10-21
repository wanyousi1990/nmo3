extends Resource
class_name DialogueTable
## 對話總表：開頭依類型分類，以 id 查詢。

@export_group("劇情觸發（StoryTrigger／進區自動）")
@export var story_entries: Array[DialogueEntry] = []

@export_group("互動對話（TalkTrigger／按 ENTER）")
@export var talk_entries: Array[DialogueEntry] = []

## 依 id 取得對話（兩類都會查）；找不到回傳 null
func get_entry(dialogue_id: String) -> DialogueEntry:
	if dialogue_id.is_empty():
		return null
	for e in story_entries:
		if e != null and e.id == dialogue_id:
			return e
	for e in talk_entries:
		if e != null and e.id == dialogue_id:
			return e
	return null


## 除錯用：列出所有 id（劇情在前、互動在後）
func list_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e in story_entries:
		if e != null and not e.id.is_empty():
			out.append(e.id)
	for e in talk_entries:
		if e != null and not e.id.is_empty():
			out.append(e.id)
	return out
