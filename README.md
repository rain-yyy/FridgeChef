# FridgeChef

记录冰箱里有什么、什么时候过期，并推荐今晚能用现有食材（优先临期）做的菜。iOS 17+ · SwiftUI · Supabase。

面向 coding agent 的规则见 [`AGENTS.md`](./AGENTS.md) / [`CLAUDE.md`](./CLAUDE.md)；产品与架构设计见 [`docs/PLAN.md`](./docs/PLAN.md)；任务列表见 [`docs/TICKETS.md`](./docs/TICKETS.md)；数据模型草稿见 [`SCHEMA.sql`](./SCHEMA.sql)。

## 环境要求

- macOS 15.6+，Xcode 26（`xcode-select -p` 确认），已下载 iOS 26 Simulator 组件
- [Homebrew](https://brew.sh)：`brew install supabase/tap/supabase deno swiftlint xcodegen`
- Docker Desktop（本地 Supabase 依赖它跑容器）

## 本地起步

```bash
# 1. 本地 Supabase（需要 Docker Desktop 正在运行）
supabase start
supabase status   # 记下 API URL 与 anon key

# 2. iOS
cd ios/FridgeChef
cp Debug.xcconfig.example Debug.xcconfig     # 按 supabase status 的输出填 SUPABASE_URL / SUPABASE_ANON_KEY
xcodegen generate
open FridgeChef.xcodeproj                    # 选一个模拟器，Cmd+R
```

`FridgeChef.xcodeproj` 由 `project.yml` 通过 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成，**不进 Git**；改工程结构改 `project.yml`，然后重新 `xcodegen generate`。

`Debug.xcconfig` / `Release.xcconfig` 也不进 Git（含 key，即便 anon key 设计上是公开的，也不预置真实值）；从对应的 `.example` 复制后自己填。

## 仓库结构

见 `docs/PLAN.md` §4.6。当前阶段（T0.1）只有骨架，业务代码从 T0.2 起逐张表/逐 ticket 添加。

## 协作方式

每个 ticket 先由 agent 复述理解、列问题、出实现计划，人工确认后再写代码；涉及 schema/RLS/认证/新依赖/费用必须亲自确认。完整流程见 `AGENTS.md`。
