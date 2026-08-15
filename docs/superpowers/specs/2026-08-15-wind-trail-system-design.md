# 全局风迹线粒子系统 — 设计文档

> 日期：2026-08-15
> 状态：已确认，待实现

## 目标

构建两个互相配合的粒子系统：

1. **全局风迹线粒子系统（背景风场）**：一个跟随相机的大范围环境风场，读取玩家与可交互物体的速度/碰撞，产生「扰乱（turbulence）」与「轻微跟随（entrainment）」等真实物理反应。
2. **可交互物体风迹粒子跟踪系统**：自动扫描 `interactable` 组并为每个物体挂载拖尾粒子，风迹大小按物体体积（碰撞形状面积）自适应等比缩放。

复用现有 `windline_particles bg.tscn` / `windline_particles_player.tscn` 的粒子形态。玩家现有 `windline_particles_player` 拖尾保持不变。

## 非目标

- 不改玩家现有拖尾逻辑（`player.gd` 的 `_update_trail`）。
- 不做流体力学的真实风场求解（Navier-Stokes 等）；用吸引器 + 湍流噪声近似。
- 不为无物理体/无碰撞形状的可交互物体（如 `WindmillArm`，Node2D 静态臂）挂拖尾。

## 架构

一个 Autoload 管理器统一管理两个子系统，监听场景切换自动重建。

```
WindTrailSystem (Autoload, Node)
├── 系统1：背景风场 (GPUParticles2D, 跟随相机)
│   └── 每个活动物体的 GPUParticlesAttractor2D (作为风场子节点，每帧同步位置)
└── 系统2：每个可交互物体的风迹拖尾 (GPUParticles2D, 作为物体子节点)
```

- `src/autoload/wind_trail_system.gd` — 管理器（扫描/挂载/每帧更新）
- `src/scenes/wind_trail_field.tscn` — 背景风场模板
- `project.godot` — 注册 autoload `WindTrailSystem`

## 组件接口

管理器（`WindTrailSystem`，extends Node）导出参数：

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `base_turbulence` | `float` | `20.0` | 背景风场基础湍流噪声强度 |
| `max_turbulence` | `float` | `120.0` | 速度/碰撞驱动的湍流上限 |
| `collision_turbulence_spike` | `float` | `80.0` | 碰撞瞬间湍流增量 |
| `follow_attractor_radius_factor` | `float` | `6.0` | 吸引半径 = 物体线性尺寸 × 此系数 |
| `follow_attractor_max_strength` | `float` | `8.0` | 轻微跟随最大吸引强度 |
| `trail_speed_threshold` | `float` | `30.0` | 物体速度高于此值才发射拖尾 |
| `reference_volume` | `float` | `10000.0` | 体积归一化基准 |

## 数据流

**生命周期（`_process`）**
1. 检测 `current_scene` 变化 → `_rebuild()`：创建/定位背景风场；扫描 `player` + `interactable` 组；为每个可交互 `RigidBody2D` 挂拖尾、为每个活动物体挂吸引器。
2. 每帧：同步吸引器位置到物体、按速度调湍流、更新各拖尾发射状态。

**系统 1 — 背景风场**
- 风场 `GPUParticles2D` 每帧跟随相机（发射盒覆盖视野 + 边距），持续飘动。
- 轻微跟随：每个吸引器的 `strength` = `min(物体速度 / 阈值, 1) × follow_attractor_max_strength`；物体静止时强度趋近 0。
- 扰乱：`turbulence_noise_strength = base + speed_factor + 碰撞残余`；`speed_factor` 由所有物体速度之和映射到 `[0, max_turbulence]`；碰撞残余随时间衰减。
- 碰撞检测：可交互 `RigidBody2D` 开 `contact_monitor`，监听 `body_entered`；玩家监听现有 `player_bounced`。命中 → `collision_turbulence_spike` 脉冲 + 短暂提升风场 `amount`。

**系统 2 — 可交互物体拖尾**
- 对每个 `interactable` 组内的 `RigidBody2D`，作为其子节点实例化一个拖尾 `GPUParticles2D`（复用现有粒子形态）。
- 每帧读 `linear_velocity`：`speed < trail_speed_threshold` → 停止发射；否则发射，拖尾方向 = `-velocity`，发射量随速度缩放。
- 体积自适应：读物体第一个 `CollisionShape2D` 的形状面积（`CircleShape2D` / `RectangleShape2D` / `CapsuleShape2D`），线性尺寸 = `sqrt(area / reference_volume)`，等比缩放发射盒尺寸、粒子缩放、粒子数量、拖尾长度。无碰撞形状 → 用 `reference_volume` 默认值。

## 体积计算

| 形状 | 面积 |
|------|------|
| `CircleShape2D` | `PI × radius²` |
| `RectangleShape2D` | `size.x × size.y` |
| `CapsuleShape2D` | `PI × radius² + 2 × radius × height` |
| 其他/无 | `reference_volume`（默认） |

线性尺寸 `k = sqrt(area / reference_volume)`，各属性按 `k` 或 `k²` 缩放。

## 文件改动

1. 新增 `src/autoload/wind_trail_system.gd`
2. 新增 `src/scenes/wind_trail_field.tscn`
3. `project.godot` 注册 `WindTrailSystem` autoload

## 边界与错误处理

- 物体被销毁（`is_instance_valid` 失败）→ 移除其吸引器/拖尾记录。
- 场景切换 → 释放旧风场/旧吸引器/旧拖尾，重建。
- 无相机 → 风场停在原位（不崩溃）。
- 无玩家/无可交互物体 → 风场仍以基础湍流持续飘动。

## 测试

1. 运行任一关卡，确认背景风场跟随相机持续飘动。
2. 玩家快速移动经过背景粒子 → 粒子被轻微带走（跟随），湍流增强（扰乱）。
3. 玩家撞墙（触发 `player_bounced`）→ 风场湍流瞬时增强。
4. 选中一个箱子并吹动 → 箱子出现拖尾，方向与速度相反；速度归零后拖尾停止。
5. 对比不同体积物体（大水箱 vs 小钢管）→ 拖尾大小/数量明显不同（体积自适应）。
6. 切换关卡 → 旧物体拖尾/吸引器清理，新关自动挂载，无残留报错。
