# FridgeChef 开发路线图

来源：2026-09-19 批准的开发计划（原存于 Claude 的本地 plan 目录，现同步进仓库方便跟踪）。
不重新设计架构 —— `docs/PLAN.md` §2 的决策记录是权威来源，这份文件只是把 `docs/TICKETS.md` 排成时间线，并记录执行过程中核对到的几处技术细节。

## 核对到的更新（执行 T0.1 时已落地，此处存档）

1. **Xcode 工具链**：Apple 已把 App Store 上传的最低 SDK 要求定为 Xcode 26 + iOS 26 SDK（2026-04-28 起强制），但这只影响编译用的 SDK，不影响 App 的最低部署版本 —— `Deployment Target` 仍是 iOS 17（不违反 D02）。`supabase-swift` 也已把工具链门槛提到 Swift 6.2 / Xcode 26。T0.1 已按此落地：Xcode 26 + Swift 6.2 工具链，`IPHONEOS_DEPLOYMENT_TARGET=17.0`，`supabase-swift` 锁定精确版本 `2.55.2`。
2. **文档路径**：原始四份文档在 `docu/` 下，与 `AGENTS.md`/`PLAN.md` 自己描述的路径不一致。T0.1 已落地：`AGENTS.md` 留在仓库根目录，`PLAN.md`/`TICKETS.md` 移到 `docs/`；`SCHEMA.sql`/`SCHEMA_SMOKE_TEST.sql` 保留在根目录（因为 `SCHEMA_SMOKE_TEST.sql` 用了相对路径 `\i SCHEMA.sql`，且根目录 `CLAUDE.md` 已经文档化了这个从根目录跑的命令）。

## 里程碑路线图

| 阶段 | 里程碑 | 关键 ticket | 状态 / 备注 |
|---|---|---|---|
| Day 0 | M0：仓库、环境、5 个 Spike | T0.1 + Spike S1–S5 | **T0.1 已完成并验证**（本地 Supabase 可启动、App 在模拟器跑通健康检查、CI 全绿，见下方"已完成"记录）。Spike S1–S5 尚未开始 |
| P0 基础 | M1 Schema 上线 → M2 登录+库存 → M3 Gate A | T0.2…T0.15（详见 `docs/TICKETS.md`） | 未开始。**T0.2（Schema v1 迁移）是下一个 ticket**，涉及 schema/RLS，按 `AGENTS.md` §0 需要先出计划、你确认后再写代码 |
| P1 核心闭环（=MVP） | M4 pilot 20 道 → M5 300 道审核完 → M6 Gate B | T1.1…T1.19 | 未开始。T1.11（100% 人工审核角色标注，≈7–8 小时）是最容易被低估的人力项 |
| 试用 2 周 | M7 Gate C | T1.19 | 未开始。用数据决定做 P2 还是 P3 |
| P2/P3/P4 | 视 Gate C 结果 | `docs/TICKETS.md` 对应 Epic | 目前只是 Epic 级别，进入前再拆细 ticket |

## 协作方式（沿用 `AGENTS.md` §0/§17，每个 ticket 都一样）

每个 ticket：我先复述理解 + 列不清楚的问题 → 出实现计划（文件、migration、接口、测试、风险）→ 你确认 → 我再写代码。PR 尽量控制在 ≤400 行。涉及 schema/RLS/认证/新依赖/会产生费用的调用，必须你亲自确认才能动手 —— 这是硬性门槛，不是默认流程可以跳过的。

## T0.1 完成记录（2026-09-19）

- 本地 Supabase 栈可启动（`supabase start`，含本地端口 54422 的冲突规避，见 `supabase/config.toml` 注释）
- App 在 iOS 26 模拟器（iPhone 17）构建 + 跑通单元测试，健康检查能真实连到本地 Supabase
- CI 三个 job（iOS / Supabase / Edge Functions）全绿
- 2026-09-19：按用户要求，把 `ios/FridgeChef/Debug.xcconfig` 和 `Release.xcconfig`（均为本地 gitignored 文件）从本地 Supabase 切到云端项目 `rthxwbwzplwhxfhfsjad`；本地 Supabase 的能力仍保留（`Debug.xcconfig.example` 还是本地模板），只是不再是日常默认。云端 `SUPABASE_ANON_KEY` 还是占位符，等你提供 publishable key 后才能真正连通（不能用已提供的 secret key，见 `TODO.md` A 组）。
