extends Control
## 簡易 GAME OVER：停留 display_duration 秒後轉往主選單（不存檔由 GlobalState.change_scene 參數控制）

@export var display_duration: float = 2.0
@export_file("*.tscn") var main_menu_scene: String = "uid://77jiqi61cvr6"

func _ready() -> void:
	HSystem.show_h_stats_ui = false
	GlobalState.prepare_for_main_menu()
	await get_tree().create_timer(maxf(display_duration, 0.0)).timeout
	var path: String = main_menu_scene
	if path == "":
		path = "uid://77jiqi61cvr6"
	await GlobalState.change_scene(path, 0.5, 0.0, Color.BLACK, false, false, false)
