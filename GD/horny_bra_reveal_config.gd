extends Resource
class_name HornyBraRevealConfig

## 共用胸罩透出參數：所有掛 horny_bra_reveal.gd 的節點讀取同一份 .tres

@export_group("Horny Bra Reveal")
## Horny 超過此值開始透出胸罩
@export var threshold_a: float = 50.0
## 超過 threshold_a 時胸罩的透明度（0.0 = 不可見，1.0 = 完全可見）
@export_range(0.0, 1.0, 0.01) var alpha_a: float = 0.2
## Horny 超過此值更加透出胸罩
@export var threshold_b: float = 80.0
## 超過 threshold_b 時胸罩的透明度
@export_range(0.0, 1.0, 0.01) var alpha_b: float = 0.4
