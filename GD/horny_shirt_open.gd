extends Sprite2D
## 依 GlobalState.is_shirt_open 顯示／隱藏開襯衫 Sprite。
## 觸發與倒數由 HSystem（Horny 達上限）→ GlobalState 管理；本腳本只讀狀態調畫面。
## cloth_nodes_to_hide／nodes_to_show_when_open 因各姿勢路徑不同，仍在各節點個別設定。

@export_group("Horny Shirt Open")
## 已改由 GlobalState 讀 TRES/horny_shirt_open.tres；此欄保留僅為相容舊場景覆寫（可忽略）
@export var config: HornyShirtOpenConfig
## OPEN 時要隱藏的著衣 Sprite（如胸部 CLOTHED、軀幹 CLOTHED）
@export var cloth_nodes_to_hide: Array[NodePath] = []
## OPEN 時要顯示、非 OPEN 時隱藏的節點（如 Sprite2D_Torso_ShirtOpen）
@export var nodes_to_show_when_open: Array[NodePath] = []

var _cloth_visible_cache: Dictionary = {}
var _was_clothed: bool = true
var _was_open: bool = false


func _ready() -> void:
	modulate.a = 0.0
	visible = false
	_was_clothed = _is_clothed()
	_was_open = GlobalState.is_shirt_open
	_set_show_nodes_visible(false)
	if not GlobalState.shirt_open_state_changed.is_connected(_on_shirt_open_state_changed):
		GlobalState.shirt_open_state_changed.connect(_on_shirt_open_state_changed)
	_sync_visual_from_global()


func _exit_tree() -> void:
	if GlobalState.shirt_open_state_changed.is_connected(_on_shirt_open_state_changed):
		GlobalState.shirt_open_state_changed.disconnect(_on_shirt_open_state_changed)


func _process(_delta: float) -> void:
	var clothed: bool = _is_clothed()
	if clothed != _was_clothed:
		_was_clothed = clothed
		_sync_visual_from_global()
	# 狀態可能在無訊號路徑被 clear；保險同步
	if GlobalState.is_shirt_open != _was_open:
		_was_open = GlobalState.is_shirt_open
		_sync_visual_from_global()


## 供胸罩腳本查詢（與 GlobalState.is_shirt_open 一致）
func is_shirt_open_active() -> bool:
	return GlobalState.is_shirt_open


func _is_clothed() -> bool:
	return GlobalState.current_mode == GlobalState.AppearanceMode.CLOTHED


func _on_shirt_open_state_changed(_active: bool) -> void:
	_was_open = GlobalState.is_shirt_open
	_sync_visual_from_global()


func _sync_visual_from_global() -> void:
	# 脫衣：藏開衫與 Torso_ShirtOpen；全域仍可為 OPEN，換回著衣後會立刻顯示
	if not _is_clothed():
		visible = false
		modulate.a = 0.0
		_set_show_nodes_visible(false)
		_cloth_visible_cache.clear()
		return

	if GlobalState.is_shirt_open:
		_apply_shirt_open_visual()
	else:
		_apply_shirt_closed_visual()


func _apply_shirt_open_visual() -> void:
	visible = true
	modulate.a = 1.0
	_hide_cloth_nodes()
	_set_show_nodes_visible(true)
	_notify_sibling_bras()


func _apply_shirt_closed_visual() -> void:
	visible = false
	modulate.a = 0.0
	_set_show_nodes_visible(false)
	_restore_cloth_nodes()
	_notify_sibling_bras()


func _notify_sibling_bras() -> void:
	var p := get_parent()
	if p == null:
		return
	for c in p.get_children():
		if c != self and c.has_method("refresh_from_shirt_open"):
			c.refresh_from_shirt_open()


func _hide_cloth_nodes() -> void:
	for np in cloth_nodes_to_hide:
		var node := get_node_or_null(np)
		if node and node is CanvasItem:
			if not _cloth_visible_cache.has(np):
				_cloth_visible_cache[np] = node.visible
			node.visible = false


func _restore_cloth_nodes() -> void:
	if not _is_clothed():
		_cloth_visible_cache.clear()
		return
	for np in cloth_nodes_to_hide:
		var node := get_node_or_null(np)
		if node and node is CanvasItem:
			node.visible = true
	_cloth_visible_cache.clear()


func _set_show_nodes_visible(p_visible: bool) -> void:
	for np in nodes_to_show_when_open:
		var node := get_node_or_null(np)
		if node and node is CanvasItem:
			node.visible = p_visible
