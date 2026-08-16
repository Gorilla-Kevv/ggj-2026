# 风语者 · Wind Whisper

> 你是一株逃离实验室的风滚草，用风的力量穿越重重机关，追寻自由。

[![GitHub Stars](https://img.shields.io/github/stars/Gorilla-Kevv/ggj-2026?style=flat&logo=github)](https://github.com/Gorilla-Kevv/ggj-2026)
[![GitHub Forks](https://img.shields.io/github/forks/Gorilla-Kevv/ggj-2026?style=flat&logo=github)](https://github.com/Gorilla-Kevv/ggj-2026)
[![Last Commit](https://img.shields.io/github/last-commit/Gorilla-Kevv/ggj-2026?style=flat&logo=github)](https://github.com/Gorilla-Kevv/ggj-2026)
[![Godot](https://img.shields.io/badge/Godot-4.6-478cbf?logo=godot-engine&logoColor=white)](https://github.com/Gorilla-Kevv/ggj-2026)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078d4)](https://github.com/Gorilla-Kevv/ggj-2026)
[![Genre](https://img.shields.io/badge/Genre-2D%20Wind%20Puzzle%20Platformer-8e44ad)](https://github.com/Gorilla-Kevv/ggj-2026)

**椰社 2026 GGJ 参赛作品** —— 一款以「风」为核心的 2D 横版解谜闯关游戏。

---

## 游戏简介

《风语者》是一款风控解谜平台跳跃游戏。玩家操纵一株获得「风之精华」的风滚草，以**鼠标指针为风源**，通过按住 / 点按左键吹出不同强度的风，操控主角与场景中的可交互物体，穿越机关重重的实验室、通风管道、炽风峡谷，最终在飓风之眼中迎战最终兵器「捕风者」。

主角全程浮空漂行，可着陆于安全区，但在尖刺、敌人与深渊面前一击毙命。能量有限，每一步都需要策略。

---

## 核心玩法

### 风的方向逻辑

- 鼠标指针是**风源**，风从指针位置向外吹。
- 选中谁，谁就被吹。
- 半透明连线指示风向，线密度 / 流动速度表示风力强度。
- 按住左键风力随按住时长递增，短点左键则吹出短促微风用于精确微调。

### 目标切换

| 目标 | 说明 |
|------|------|
| 主角（默认） | 风滚草自身，最常用的吹送目标 |
| 可交互物体 | 箱子、风车、管道、风化岩柱等 |

选中物体有金色高亮描边，鼠标与目标间显示半透明白色虚线风向连线。

### 能量系统

- 能量上限 100 点，吹风持续消耗，停风自动回复。
- 能量耗尽会强制停风，必须规划吹风节奏，不能无脑狂吹。
- 第 3 关能量消耗加倍（同时回复加快），强化资源管理。

### 死亡与重生

- 触碰尖刺、敌人、落入深渊即死亡。
- 从最近激活的检查点重生，重生后能量回满。

---

## 操作方式

| 操作 | 效果 |
|------|------|
| `R` | 循环切换作用目标（主角 ⇄ 可交互物体） |
| 鼠标移动 | 预览风向（半透明连线） |
| 按住左键 | 持续吹风，方向 = 鼠标 → 目标 |
| 松开左键 | 停止吹风 |
| 短点左键 | 短促微风，用于精确微调位移 |
| `A` / `D` | 左 / 右移动 |
| `M` | 打开小地图 |
| `X` | 删除 / 移除目标 |

---

## 关卡一览

| 关卡 | 名称 | 场景 | 核心机制 |
|------|------|------|----------|
| 1 | 觉醒 · 玻璃罩 | 实验室测试区 | 基础操作教学、吹开障碍 |
| 2 | 逃亡 · 通风管道 | 通风系统 | 可移动管道、风车、巡逻研究员 |
| 3 | 荒原 · 炽风峡谷 | 灼热峡谷 | 岩浆、火舌、岩柱、追踪无人机、岩栖蝎 |
| 5 | 归宿 · 飓风之眼 | 暴风塔内部 | Boss 战：「捕风者」三重风态循环 |

> 关卡之间通过**大厅（Hub World）**串联，通关后可自由返回。

### Boss：「捕风者」Windcatcher

巨型机甲，通过吸气态 → 暴风态 → 平静态三重风态循环考验玩家对风力机制的综合运用。

---

## 敌人与机关

**敌人**：巡逻研究员、追踪无人机、岩栖蝎、Boss 捕风者。

**机关与环境**：可吹动箱子、风车连锁、可移动管道、上升气流、尖刺、深渊、检查点、章节门、出口传送门。

---

## 技术栈

| 项目 | 说明 |
|------|------|
| 引擎 | Godot 4.6（Forward Plus） |
| 语言 | GDScript |
| 平台 | Windows |
| 其他 | Jolt Physics、自定义粒子特效 |

---

## 运行与构建

### 在编辑器中运行

1. 安装 [Godot 4.6](https://godotengine.org/download)。
2. 用 Godot 打开本项目的 `project.godot`。
3. 按 `F5` 运行。

### 直接游玩

仓库根目录已包含导出的可执行文件 `风语者 Wind Whisper.exe`，双击即可运行。

### 重新导出

在 Godot 中打开项目 → 菜单「项目」→「导出」，导出预设已配置为 Windows Desktop（`export_presets.cfg`）。

---

## 项目结构

```
src/
├── actors/          # 主角与敌人
│   ├── player.gd        # 风滚草主角：低重力物理、状态、输入
│   └── enemies/         # 研究员 / 无人机 / 蝎子 / Boss / 碎石
├── autoload/        # 全局单例
│   ├── global.gd        # 能量、选中目标、检查点、关卡进度、存档
│   ├── audio_manager.gd # 音频管理
│   ├── settings.gd      # 设置
│   └── wind_trail_system.gd
├── systems/         # 核心系统
│   ├── wind_system.gd   # 风力：鼠标→风向→力
│   └── target_selector.gd # R 键目标切换
├── interactables/   # 可交互物体（箱子 / 风车 / 管道）
├── environment/     # 环境（尖刺 / 深渊 / 安全区 / 上升气流）
├── level/           # 关卡管理（检查点 / 章节门 / 出口）
├── ui/              # HUD / 风向线 / 小地图 / 设置菜单
└── scenes/          # 各关卡场景与 UI 场景
```

---

## 团队

**椰社 2026**

- 策划：见 `docs/策划.md`
- 程序：见 `docs/分工方案.md`
- 美术 / 音频：见 `assets/`

---

## 相关文档

- [游戏策划案](docs/策划.md)
- [分工方案](docs/分工方案.md)

---

## 许可证

本项目为 Game Jam 参赛作品，如需使用或二次开发请先联系团队。
