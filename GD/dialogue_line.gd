extends Resource
class_name DialogueLine
## 單句對話：講者名稱（EN／JA）、內文、是否顯示女主頭像、可選覆寫頭像。

@export_group("講者")
@export var speaker_en: String = ""
@export var speaker_ja: String = ""
## 勾選後對話框左側顯示女主頭像（未勾選且無 portrait 則留空位）
@export var show_heroine_portrait: bool = false
## 若指定則優先於女主預設頭像（NPC 等）
@export var portrait: Texture2D

@export_group("內文")
@export_multiline var text_en: String = ""
@export_multiline var text_ja: String = ""
