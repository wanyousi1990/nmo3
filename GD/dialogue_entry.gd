extends Resource
class_name DialogueEntry
## 一段完整對話（由多句 DialogueLine 組成），以 id 供觸發器／劇情呼叫。
## 類型由 DialogueTable 的 story_entries／talk_entries 分類，不在此再設 kind。

@export var id: String = ""
@export var lines: Array[DialogueLine] = []
