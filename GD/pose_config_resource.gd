extends Resource
class_name PoseConfigResource

@export var pose_name: StringName = &"H_Pose_01" ## 姿勢節點名稱（須與場景子節點名稱一致，如 H_Pose_01）
@export var torso_dir: Vector2 = Vector2(40, -20) ## 衝擊時軀幹受力方向向量
@export var pelvis_dir: Vector2 = Vector2(30, -30) ## 衝擊時骨盆受力方向向量
@export var b_mult: float = 1.0 ## 胸部衝擊力道倍率
@export var h_mult: float = 1.0 ## 臀部衝擊力道倍率
@export var motion_type: String = "impact" ## 胸部動作類型：impact=衝擊彈簧 / press=乳交擠壓
@export var b_expand: float = 0.0 ## 胸部受衝擊時向兩側擠開的係數（負值=向內夾）
@export var b_rotation_factor: float = 1.0 ## 位移對胸部旋轉的影響係數（0 = 不旋轉）
@export var anim: String = "H_Pose_01_Loop" ## 此姿勢播放的 AnimationPlayer 動畫名稱
@export var impact_vec: Vector2 = Vector2(10, -40) ## 觸發衝擊時注入胸部／臀部的預設方向向量
@export var semen_range: Vector2i = Vector2i(3, 5) ## 射精階段隨機次數範圍（X=最少, Y=最多）

@export_group("Breast Press (乳交參數)")
@export var b_press_freq_stages: Array[float] = [6.0, 9.5, 13.0] ## 乳交頻率陣列：慢 / 中 / 快（Hz）
@export var b_press_depth: float = 0.09 ## 往下壓時胸部上下壓扁程度
@export var b_press_rebound: float = 0.07 ## 乳交回彈時水平膨脹程度
@export var b_press_y_follow: float = 5.0 ## 乳交壓縮時胸部向下位移量（像素）
@export var b_press_phase_shift: float = 0.4 ## 左右胸擠壓相位差（避免完全同步）
@export var b_press_smooth: float = 14.0 ## 乳交形變平滑速度（越大越快跟上）
@export var b_press_inward_px: float = 2.0 ## 乳交時左右胸往中線夾擊的位移（像素）
@export var b_press_inward_scale: float = 0.08 ## 乳交時水平壓縮比例
@export var b_press_vertical_stretch: float = 0.12 ## 乳交時垂直拉長比例
@export var b_press_contact_delay: float = 0.12 ## 每次衝擊後，延遲多久才開始乳交形變（秒）
@export var b_press_attack_ratio: float = 0.35 ## 一次乳交循環中「擠壓段」所佔比例（0~1）
@export var b_press_release_ratio: float = 0.65 ## 一次乳交循環中「回彈段」所佔比例（0~1）
