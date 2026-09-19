# FridgeChef 手动 TODO 清单

来源：2026-09-19 批准的开发计划。按"何时需要"分组，勾选状态是根据目前掌握的信息标注的。

> **2026-09-19 更新**：改由 Claude 继续实现 P0 阶段（T0.2 起），取代此前"交给其他协作者"的决定。
> 按 `AGENTS.md` §0 流程逐 ticket 进行：先复述理解 + 列不清楚的问题 → 出实现计划 → 你确认 → 再写代码；
> 涉及 schema/RLS/认证/新依赖/会产生费用的调用，必须你亲自确认才能动手。本文件和 `docs/PLAN.md`/
> `docs/ROADMAP.md` 会随决策落地同步更新。

## A. 立即需要

- [x] 决定项目名称 — FridgeChef
- [ ] Bundle ID 正式值 —— Bundle ID 是 App 在 App Store / 系统里的唯一标识符（反向域名格式，如 `com.fridgechef.app`）。目前用的是占位符 `com.fridgechef.app`，**不阻塞开发**，可以先用着，正式上架前再改成你 Apple Developer 账号下的真实值
- [x] 创建 GitHub 仓库并链接、设为 public — https://github.com/rain-yyy/FridgeChef.git（已确认 public），T0.1 三个 commit + 后续文档 commit 已推送
- [ ] 注册 **Apple Developer Program**（付费）—— **不是立即需要**：用免费 Personal Team 就能在自己的真机上跑 App 做日常开发测试，不需要付费订阅。付费账号只在这两个场景才是硬需求：① **TestFlight** 分发给同学试用；② **Sign in with Apple**（Spike S3）能不能用免费账号做，到时候要再验证一次，不确定
- [x] Supabase 项目已创建并接入 — 项目 `FridgeChef`，ref `rthxwbwzplwhxfhfsjad`；`Debug.xcconfig`/`Release.xcconfig` 里的云端 URL + anon/publishable key 已由你填好（顺手修了一个坑：xcconfig 里 `//` 是注释符，你贴的 URL 里的 `//` 会把后面截断，已经加回 `$()` 转义，两个文件都改了，实际连接值没变）
- [x] 本机安装 Xcode 26 / Supabase CLI / Deno — 已验证（T0.1 的 build/test/CI 都跑通了）
- [x] 确认 P0 用哪家 LLM 供应商 — OpenRouter；具体模型名称你说后面再填
- [x] 一个人做还是有协作者 —— 已回答：T0.1 完成后交给其他协作者接手，Claude 之后只维护文档

## B. P0 阶段内需要（不阻塞开工，会卡在对应 ticket）

- [ ] 校对 `SCHEMA.sql §11` 里的默认保质期估计值（T0.4 依赖）
- [ ] 字典种子（约 300 条）人工通读校对一遍（T0.4，预计约半天）
- [ ] 逐条确认 `docs/PLAN.md` §2 里的 🟡 决策，尤其 D02（iOS 17+ 最低版本）、D32/D33（角色与匹配规则补充）、D71（仅 Apple 登录）、D73（本地通知汇总）、D75（TS/Deno 共用管线）、D76（LLM 分档策略）——默认全部采纳，不同意的请挑出来说

## C. P1 之前/期间需要

- [ ] 中餐三个来源站点（李锦记/美食天下/下厨房）的使用条款与 robots.txt 复核，写成 `docs/SOURCES.md`（T1.10 前置依赖）
- [ ] 确认能接受 100% 人工审核菜谱角色标注的时间投入（约 7–8 小时），或考虑找人分担
- [ ] Supabase 套餐何时从免费升级 —— 建议在试用开始前评估

## D. 后置（P2/P3/P4，暂不阻塞 MVP）

- [ ] Spoonacular API key 申请（P3 前）
- [ ] P3 检索/抓取供应商选定（取决于 Spike S2 结果）
- [ ] 商业模式决策：免费/订阅（P4 前再定）
- [ ] 律师/合规咨询预算安排（上架前）
- [ ] 同学试用名单与设备信息（M6 前补齐即可）
