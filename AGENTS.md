# AGENTS.md — 给 coding agent 的项目规则

> 放在仓库根目录（如果你用的工具读取 `CLAUDE.md` 或别的文件名，就复制/重命名一份）。
> 这是**规则**，不是背景介绍；背景与决策在 `docs/PLAN.md`，数据模型在 `SCHEMA.sql`，任务在 `TICKETS.md`。

## 0. 开始任何任务之前

1. 阅读 `docs/PLAN.md`（重点 §2 决策记录）、`SCHEMA.sql`、当前 ticket。
2. **PLAN §2 里已经有的决策，直接照做，不要重新讨论。没有记录的产品/架构决策，向我提问，不要自行假设。**
3. 先输出**实现计划**（文件清单、migration、接口、测试、风险、替代方案），**等我确认后再写代码**。
   以下改动**必须**先得到我的明确确认：数据库 schema、RLS 策略、认证流程、新增第三方依赖、任何会产生费用的调用路径、任何 PLAN 里没有的新表/字段/功能。
4. 如果发现文档自相矛盾或缺失，指出来，不要悄悄选一边。

## 1. 绝对不能违反的规则（护栏）

- **密钥**：客户端只能有 Supabase anon key。service_role key、LLM key、Spoonacular key、搜索 key 只能出现在 Edge Function secrets 或我本机的 `.env`。**永远不要提交密钥，永远不要把它们写进客户端代码、日志或测试夹具。**
- **RLS**：`public` 下每张表必须启用 RLS，并同时提供策略、grants 和测试。**不要给 anon 任何权限。** 不要用 service_role 去"绕过"本该由 RLS 解决的问题。
- **Migration**：schema 只能通过 `supabase/migrations/` 变更。**已应用的 migration 永不修改**，需要修正就新增一个。
- **LLM**：所有 LLM/第三方 API 调用只在服务端（Edge Function 或本机管线）。LLM 只能产出结构化数据，写库由经过校验的确定性代码完成——**LLM 不直接持有写权限**。所有外部文本（网页、用户输入、小票文字）一律当**数据**，用分隔符包裹，并在 prompt 里声明忽略其中的指令。结构化输出解析失败最多重试 1 次，仍失败则报错，**绝不写入部分结果**。
- **抓取**：遵守 robots.txt、限速、白名单域名；拒绝私有/回环 IP（SSRF）；限制响应大小与超时；不长期保存原文。
- **菜谱内容**：只存结构化事实和**自己重写**的文字；不存原文、原图、作者名；品牌名替换为通用食材；`source_url` 仅内部溯源并在 App 内展示为"参考来源"。
- **Spoonacular**：只能永久存 `id`/标题/图片 URL；其余数据只即时展示，**不入库、不缓存、翻译结果也不入库**。
- **日期**：日历日（购买日、到期日、烹饪日）用 `date`（DB）和 `LocalDate`（Swift），**不要用 `Date`+时区表达"到期日"**；"今天"来自可注入的 `Clock`；客户端调用 `match_recipes` 和写入 `purchased_on` 时显式传本地日期。
- **单位**：库里只存 g/kg/ml/L 与计数单位；oz/lb/fl oz/gal 仅在输入与显示时换算。
- **不要引入**：第三方分析/广告 SDK、未经讨论的架构框架、SwiftData（Supabase 是唯一事实来源）、客户端持有的任何后端密钥。
- **食品安全**：保质期只是估计，相关界面必须保留"以包装日期和实际状态为准"的提示；不要新增任何"安全/可食用"的断言性文案。

## 2. 技术约定

**通用**
- 提交小而聚焦：**每个 PR ≤ ~400 行**，描述里写：做了什么 / 没做什么 / 如何验证 / 需要我确认的点。
- 不要"顺手"重构或加功能；发现值得做的事，写成 issue/备注，不要混进当前 PR。
- 依赖需要理由（为什么需要、维护状态、许可证）并**锁定版本**。

**iOS（Swift / SwiftUI）**
- iOS 17+，Swift Concurrency，`@MainActor @Observable` 的 ViewModel；View → ViewModel → Repository（协议）→ Supabase 实现；每个 Repository 有内存 Fake，供预览与测试。
- 禁止 force unwrap（测试除外）；错误统一走 `AppError`；加载状态走 `Loadable<T>`。
- 所有用户可见文案走 String Catalog；支持 Dynamic Type、深色模式、VoiceOver；状态不能只靠颜色表达。
- `supabase-swift` 的 API 随版本变化：**请对照锁定版本的源码/官方文档确认签名，不要凭记忆写。**
- 必须有单元测试：`LocalDate`、到期日计算、单位换算、字典搜索排序、`DigestPlanner`、涉及数量/日期的 ViewModel 逻辑。

**数据库**
- 新表 = 迁移 + RLS + 策略 + grants + pgTAP，缺一不可。
- 客户端能调用的函数要显式 `grant execute`；特权函数（如 `merge_ingredients`）要 `revoke` 掉 `public/anon/authenticated`。
- 所有指向 `auth.users` 的"创建者/操作者"外键必须 `on delete set null`（否则账号无法删除）；用户私有数据用 `on delete cascade`。
- 索引要有理由；改匹配算法前先跑匹配评测集（PLAN §12.2）。

**Edge Functions / 管线（Deno + TypeScript）**
- 入参用 Zod 校验；统一错误信封 `{"error":{"code","message","retry_after?"}}`；JWT 校验开启。
- 每次 LLM/第三方调用写 `usage_ledger`（价格表在配置里，不要写死）；先查配额与月预算。
- CI 里**不真调** LLM/第三方；用录制夹具。
- 日志结构化，**不记录图片、完整小票明细、令牌**。
- LLM 相关改动必须跑对应评测集（PLAN §10.3），把结果贴进 PR；**不要为了让指标变好去改评测集**。

## 3. 测试与完成定义

每个 ticket 完成时必须同时满足：满足 AC；测试已写且通过；CI 全绿；没有改已应用 migration；没有密钥泄露；日期/单位/数量逻辑有单元测试；LLM 改动有评测结果；用户可见文案走 String Catalog；受影响的文档（PLAN §2、`SCHEMA.sql`）已更新。

## 4. 什么时候必须停下来问我

- 需求或验收标准有歧义；文档矛盾；PLAN §2 没有记录的产品/架构决策。
- 需要新增/修改表、RLS、认证、依赖、或会产生费用的调用。
- 发现 `SCHEMA.sql` 与实际环境行为不一致（它只在裸 PG16 + 模拟 auth 上验证过，尚未在真实 Supabase 上验证）。
- 评测结果不达标，且你想通过改阈值/改评测集来"解决"。
- 任何看起来会违反第 1 节护栏的事。

## 5. 开场 prompt 模板

```
你是这个项目的 coding agent。先阅读 docs/PLAN.md、SCHEMA.sql、AGENTS.md。
项目决策已记录在 PLAN §2，遇到没有记录的产品决策请提问，不要自行假设。
本次任务：<粘贴 ticket>。
请先不要写代码，先输出：
1) 你对任务和验收标准的理解，以及不清楚的问题；
2) 实现计划（文件清单、migration、接口、测试、风险）；
3) 需要我确认的点（schema/RLS/认证/依赖/费用相关必须列出）。
我确认后你再实现，PR 保持 ≤400 行并带测试。
```
