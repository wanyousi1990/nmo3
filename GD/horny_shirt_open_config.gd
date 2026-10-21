extends Resource
class_name HornyShirtOpenConfig

## 共用開襯衫參數：GlobalState 讀取 duration；視覺節點不再負責倒數
## （cloth_nodes_to_hide 因各姿勢路徑不同，仍留在各節點的腳本 @export）

@export_group("Horny Shirt Open")
## 開襯衫狀態維持秒數
@export var duration_seconds: float = 30.0
