# NMO3 規範（集中管理）

之後開發以這份為準。短的硬性條列在 `.cursorrules` 與 `.cursor/rules/00-nmo3-core.mdc`（每次對話都會帶上）。想改原則：改這份＋那兩處保持一致，或跟 Agent 說「把某某寫進規範」。

怎麼自己改檔：見 `DOCS/怎麼改這些文件.md`。  
進度、12 張主圖封版、系統待做：見 `DOCS/開發進度掌控表.md`。  
劇情、美術方向、玩法取捨、銷售／系列銜接：見 `DOCS/系列中長期構想.md`（先讀再答）。

---

## 1. 這是什麼遊戲

2D 橫向捲軸、像素、動作融合 H。Godot 4.4。

H 是狀態，不是過場。被怪物碰到 → 進入 `grabbed` → 玩家選「撐久一點（越爽越危險）」或「左右連打掙脫（安全但不太爽）」→ 回到探索。

系列第三款空殼。不要把 NMO2 關卡整包搬回來。新系統（例如近戰）先獨立測試場景，通過再合進主流程。美術先量一個 H 姿勢工時。這款新畫主圖封在 12 張（見進度表），其餘沿用第二款＋差分。

---

## 2. 核心數值

| 系統 | 用途 |
|---|---|
| HP | 只負責死亡 |
| Horny | 掙脫難度、H 強度；滿值不可掙脫 |
| Semen | 來自 H；用在服裝外觀、H 解鎖、永久強化（低上限） |

H 分段：慢／中／快／射精。射精中不可掙脫。每段都要能調：抽插次數、HP 消耗、Horny 增加、Semen 獲得。

玩家狀態：move、jump、dash、grabbed、recover。

---

## 3. 技術規範

- 對話與程式註解：繁體中文。
- 所有可調參數：`@export` + `##` 行尾備註（顏色、傷害、晃動、路徑都算）。
- 模組化、好改；**沒要求就不重構、不搬目錄、不拆大檔。**
- 改功能時保留既有 print 與註解。
- 關卡間隙對照 `.cursor/rules/movement-limits.mdc`（1 格＝32px，遠度 ≈ 12 − 平台高）。目前參考：`jump_velocity ≈ -360`、`dash_speed 360`、`dash_duration 0.5`、重力 `784`。

建議結構（非必須）：PlayerController、StateMachine、HSystem、Progression。

---

## 4. 美術規格（手繪／換圖用，不是管線程式）

- 畫布建議 192×192，角色高約 144px。同一姿勢同一畫布、同一 pivot，不要各自裁切。
- 圖層／檔名：`{部件}_{狀態}`，必要時加左右。
- 部件：`Torso` `Pelvis` `Hip_L` `Hip_R` `Thigh_L` `Thigh_R` `Calf_L` `Calf_R` `Arm_L` `Arm_R` `Forearm_L` `Forearm_R` `Breast_L` `Breast_R` `Head` `HairFront` `HairBack` `Pussy` `Eye` `Mouth`
- 狀態：`Naked` `Clothed` `Bra` `ShirtOpen` `Lewd` `Iku` `Overlay`
- 範例：`Torso_Naked`、`Breast_L_Bra`、`Head_Eye_Half`
- 參考層名稱加前綴 `_`。左右肢體能 `flip_h` 就不要各畫一張。
- 正式圖放 `ART/`，場景在 `TSCN/` 只換貼圖、不重排已調過的 position／z_index。

已關閉：Godot MCP。美術管線保留，用法見 `DOCS/美術管線怎麼用.md`。

---

## 5. 刪除圖片或怪物（無痛順序）

1. 先列出要刪的檔名或節點名，給 Agent 搜全專案（`.tscn` `.gd` `.tres`）。
2. 從場景拿掉節點、清掉腳本／資源裡的路徑。
3. 確認搜尋沒有 `res://ART/...` 或舊場景路徑。
4. 最後才刪 png 與同名 `.import`。
5. 開 Godot 看 Output 有沒有 `Failed to load`。有就補修，不要忽略。

禁止：先在資料夾刪圖再進編輯器。那就是第二款紅字的原因。

---

## 6. 女主與 H

現況：`character_body_2d` 是地圖上的女主，也是 H 劇場宿主；`OL_H_Controller.gd` 管 H 節奏、物理、音效、FX。這是刻意的，不是意外堆疊。

預設：**先不要拆成獨立 H 場景、不要為了檔案變短而重構。** 省時間、少回歸。要新姿勢時優先加 `PoseConfig`／場景，少改 Controller 本體。

若以後真的改「女主只負責移動、H 另開演出場景」，必須當獨立任務、先測再合，且使用者明確點頭。
