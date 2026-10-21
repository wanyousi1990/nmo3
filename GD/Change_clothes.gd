extends Area2D

## 這是可選設定：如果你想讓這個區域切換到「特定」模式
## 0: Toggle (循環), 1: Force Naked (強制裸體), 2: Force Clothed (強制著裝)
@export_enum("Toggle", "Force Naked", "Force Clothed") var change_type: int = 0

func _ready() -> void:
	# 連接碰撞信號
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# 檢查進入的是否為玩家
	if body.name == "Player" or body.is_in_group("Player"):
		_execute_change_request()

func _execute_change_request() -> void:
	## 1. 檢查全域開關是否允許切換
	#if not GlobalState.enable_cloth_keys:
		#print("全域設定已鎖定服裝切換")
		#return
	
	# 2. 直接發射全域信號，不搜尋任何節點
	# 讓感興趣的腳本（如 visual_manager）自行處理
	GlobalState.request_appearance_change.emit(change_type)
	
	print("已發射換裝訊號，類型: ", change_type)
