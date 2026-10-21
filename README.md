# Nightmare Office 3

從 NMO2 抽出的系統空殼。關卡、教學、結局都拿掉了，只留可跑的系統 + 一條沙盒走廊。

## 還在的東西

- 玩家（跑／跳／衝刺）、H、HP／Horny／Semen、商店、對話框、存檔、門、怪物與 H 姿勢
- 美術管線（Krita 匯出 → 組裝進 Godot）
- Cursor MCP 規則

## 刻意拿掉的

- NMO2 的 level_00～03、舊 scene、教學怪、結局輪播、Gallery
- 標題仍暫時沿用 NMO2 主選單圖（之後換新女主圖）

## 開專案

1. Godot 4.4.1 → Import → 這個資料夾的 `project.godot`
2. 主選單 New Game 會進 `TSCN/sandbox.tscn`
3. 若地圖是空的，選 Sandbox 根節點按「重建地圖」

## 你還要做

- 新女主美術（頭變大）+ 用美術管線裝進姿勢
- 近戰系統（獨立測試場景先做）
- 正式關卡（不要再整包搬 NMO2 地圖）
- 對話表換成這款劇情
- GitHub 開一個新 repo 把這個資料夾 push 上去（與 NMO2 分開）
