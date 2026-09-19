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
| P0 基础 · M1 数据库基础 | T0.2 Schema→migrations → T0.3 pgTAP RLS 矩阵 → T0.4 约300条字典种子 | T0.2, T0.3, T0.4 | **T0.2 已完成并验证**（见下方"T0.2 完成记录"）。**T0.3（pgTAP RLS 矩阵）是下一个 ticket**。T0.6（App 壳子）只依赖 T0.1，可与 M1 并行 |
| P0 基础 · M1 并行 | App 壳子：TabView / Loadable / AppError / Clock / LocalDate / 设计 token | T0.6 | 未开始，可与 M1 并行推进 |
| P0 基础 · M2 登录 + 库存 | T0.5 Apple 登录 → T0.7 字典本地缓存搜索 → T0.8 库存列表 → T0.9 加库存/批量加 → T0.10 resolve-ingredient Edge Function → T0.11 单品详情/编辑 → T0.12 设置+引导 | T0.5, T0.7–T0.12 | 未开始，依赖 M1 完成（T0.5 依赖 T0.2；T0.7/T0.8 依赖 T0.6） |
| P0 基础 · M3 提醒 + Gate A | T0.13 过期提醒 DigestPlanner → T0.14 最小可观测性 → T0.15 自用验证 = Gate A | T0.13, T0.14, T0.15 | 未开始，依赖 M2 完成 |
| P1 核心闭环（=MVP） | M4 pilot 20 道 → M5 300 道审核完 → M6 Gate B | T1.1…T1.19 | 未开始。T1.11（100% 人工审核角色标注，≈7–8 小时）是最容易被低估的人力项。进入 P1 前会仿照 P0 这次一样再拆一版子里程碑 |
| 试用 2 周 | M7 Gate C | T1.19 | 未开始。用数据决定做 P2 还是 P3 |
| P2/P3/P4 | 视 Gate C 结果 | `docs/TICKETS.md` 对应 Epic | 目前只是 Epic 级别，进入前再拆细 ticket |

## 协作方式（沿用 `AGENTS.md` §0/§17，每个 ticket 都一样）

**2026-09-19 更新**：P0 阶段（T0.2 起）由 Claude 继续实现，取代此前"T0.1 之后交给其他协作者"的安排（同步见 `TODO.md`、`docs/PLAN.md` O-01）。

每个 ticket：我先复述理解 + 列不清楚的问题 → 出实现计划（文件、migration、接口、测试、风险）→ 你确认 → 我再写代码。PR 尽量控制在 ≤400 行。涉及 schema/RLS/认证/新依赖/会产生费用的调用，必须你亲自确认才能动手 —— 这是硬性门槛，不是默认流程可以跳过的。

## T0.1 完成记录（2026-09-19）

- 本地 Supabase 栈可启动（`supabase start`，含本地端口 54422 的冲突规避，见 `supabase/config.toml` 注释）
- App 在 iOS 26 模拟器（iPhone 17）构建 + 跑通单元测试，健康检查能真实连到本地 Supabase
- CI 三个 job（iOS / Supabase / Edge Functions）全绿
- 2026-09-19：按用户要求，把 `ios/FridgeChef/Debug.xcconfig` 和 `Release.xcconfig`（均为本地 gitignored 文件）从本地 Supabase 切到云端项目 `rthxwbwzplwhxfhfsjad`；本地 Supabase 的能力仍保留（`Debug.xcconfig.example` 还是本地模板），只是不再是日常默认。云端 `SUPABASE_ANON_KEY` 还是占位符，等你提供 publishable key 后才能真正连通（不能用已提供的 secret key，见 `TODO.md` A 组）。

## T0.2 完成记录（2026-09-19）

- `SCHEMA.sql` 的 P0 部分拆成 `supabase/migrations/` 下 8 个顺序文件（extensions → enums → households/profiles → 食材字典 → 库存 → usage_ledger → P0 业务函数 → 参考数据）；`supabase db reset` 在本地栈干净跑通。
- **代码审查后做的一次结构调整**：最初把 RLS + grants 单独拆成两个文件、放在最后执行，是照抄 `SCHEMA.sql` §9/§10 的章节顺序；审查发现这样会有一段"表已建但 RLS/grants 还没生效"的窗口期（如果 migration 中途失败会卡在不安全的状态），也不符合 `AGENTS.md` "新表 = migration+RLS+policy+grants+pgTAP 算一个整体"的约定。改成了每张表的 RLS/policy/grant 紧跟着 `create table` 写在同一个迁移文件里（`merge_ingredients` 的 revoke 本来就是这么写的，只是表没跟上），删掉了那两个单独文件，8 个文件里每一个跑完都是"当前存在的表全部处于安全状态"。重新 `supabase db reset` + 冒烟测试过一遍，行为不变。
- 范围决定（用户 2026-09-19 授权 Claude 自行判断，理由见文件内注释）：
  - `agent_jobs` 不在 T0.2 建（P0 没有消费者，`kind` 只允许 `recipe_lookup`/`receipt_parse`，都是 P2/P3），留给首次用到它的 ticket；`usage_ledger` 建了，因为 T0.10（P0）每次 LLM 调用要写它。
  - `cooked_log` 发现有硬依赖：它的 `recipe_id` 外键指向 `recipes` 表，而 `recipes` 是 T1.1 才建，所以 `cooked_log` 技术上无法在 T0.2 创建，随 T1.1 一起建。
  - §11 参考数据（分类+默认保质期）当成核心数据随 T0.2 migration 一起 apply，不走 `supabase/seed.sql`（那是给 dev fixture 用的）。
  - `merge_ingredients`（§8.4）在 T0.2 里是裁剪版（去掉了操作 `recipe_ingredients` 的那段，因为那张表还不存在）；T1.1 建好 `recipe_ingredients` 后要用 `create or replace function` 把那段补回去。
- 本地端到端冒烟测试通过（`docker exec` 进 `supabase_db_fridgechef` 手动跑的，不是正式 pgTAP）：新用户触发 `handle_new_user` 自动建 profile+household+owner 成员；新增食材自动生成中/英文别名；`suggest_expiry`/`search_ingredients` 返回值正确；库存新增/部分消耗正确记到 `inventory_events`（`added` / `consumed_partial`）；`anon` 角色访问任意 P0 表被拒绝（grants/RLS 生效）。完整 pgTAP RLS/权限矩阵是 T0.3 的范围，还没做。
- 本地 Supabase 栈这轮验证过程中被重新启动（之前是停的），目前还在跑；App 的 xcconfig 仍指向云端项目，不受影响。
