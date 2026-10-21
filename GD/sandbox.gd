@tool
extends Node2D
## NMO3 沙盒關：短走廊，用來驗證系統還在。之後請另建正式關卡。

@export var base_layer: TileMapLayer
@export var prop_layer: TileMapLayer
## 走廊半長（格）
@export var corridor_half: int = 24
@export var floor_y: int = 4
@export var wall_height: int = 9
@export var void_height: int = 10

@export_tool_button("重建地圖（覆蓋現有圖塊）")
var rebuild_map_btn: Callable = _tool_rebuild_map

const SRC: int = 0
const BG_WALL: Vector2i = Vector2i(21, 10)
const BG_FLOOR: Vector2i = Vector2i(21, 11)
const REAL_FLOOR: Vector2i = Vector2i(21, 12)
const VOID_BLACK: Vector2i = Vector2i(24, 6)


func _ready() -> void:
	_resolve_layers()
	if base_layer and base_layer.get_used_cells().is_empty():
		_build_all()
		print("[Sandbox] 地圖為空，已自動生成")
	elif not Engine.is_editor_hint():
		print("[Sandbox] 使用場景內既有地圖")


func _tool_rebuild_map() -> void:
	_resolve_layers()
	_build_all()
	print("[Sandbox] 已重建地圖")


func _resolve_layers() -> void:
	if base_layer == null:
		base_layer = get_node_or_null("MAP/TileMapLayer_Base") as TileMapLayer
	if prop_layer == null:
		prop_layer = get_node_or_null("MAP/TileMapLayer_Object") as TileMapLayer


func _build_all() -> void:
	if base_layer == null:
		push_warning("[Sandbox] 找不到 TileMapLayer_Base")
		return
	base_layer.clear()
	var x0: int = -corridor_half
	var x1: int = corridor_half
	var bg_floor_y: int = floor_y - 1
	var y_top: int = bg_floor_y - wall_height - void_height
	var y_bot: int = floor_y + void_height
	for x in range(x0, x1):
		for y in range(y_top, bg_floor_y - wall_height + 1):
			base_layer.set_cell(Vector2i(x, y), SRC, VOID_BLACK)
		for y in range(bg_floor_y - wall_height + 1, bg_floor_y):
			base_layer.set_cell(Vector2i(x, y), SRC, BG_WALL)
		base_layer.set_cell(Vector2i(x, bg_floor_y), SRC, BG_FLOOR)
		base_layer.set_cell(Vector2i(x, floor_y), SRC, REAL_FLOOR)
		for y in range(floor_y + 1, y_bot + 1):
			base_layer.set_cell(Vector2i(x, y), SRC, VOID_BLACK)
	for y in range(y_top, y_bot + 1):
		base_layer.set_cell(Vector2i(x0 - 1, y), SRC, VOID_BLACK)
		base_layer.set_cell(Vector2i(x1, y), SRC, VOID_BLACK)
