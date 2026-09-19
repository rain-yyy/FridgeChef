# FridgeChef 手动 TODO 清单

来源：2026-09-19 批准的开发计划（原存于 Claude 的本地 plan 目录，现同步进仓库方便跟踪）。
按“何时需要”分组，勾选状态是我根据目前掌握的信息标注的，不确定的保持未勾选，请你核对。

## A. 立即需要（T0.1 已完成，以下是状态回顾）

- [x] 决定项目名称 — FridgeChef
- [ ] 决定 Bundle ID 正式值 / 仓库可见性 — 当前 Bundle ID 是占位符 `com.fridgechef.app`，等注册 Apple Developer 账号、确定 Team 后可能要改
- [x] 创建 GitHub 仓库并链接 — https://github.com/rain-yyy/FridgeChef.git，T0.1 三个 commit 已推送
- [ ] 注册并激活 **Apple Developer Program**（付费）—— 真机 Sign in with Apple（Spike S3）、TestFlight 都需要，目前还没做
- [x] 注册 Supabase 账号并创建项目 — 项目 `FridgeChef`，ref `rthxwbwzplwhxfhfsjad`，已提供 secret key
- [ ] 补充 Supabase **anon/publishable key**（`sb_publishable_...`，Dashboard → Settings → API）—— 目前只有 secret key，不能进 App。已把 `ios/FridgeChef/Debug.xcconfig` 和 `Release.xcconfig` 切到云端 URL，但 `SUPABASE_ANON_KEY` 还是占位符，等这个 key 填好之后 App 才能真正连上云端
- [x] 本机安装 Xcode 26 / Supabase CLI / Deno — 已验证（T0.1 的 build/test/CI 都跑通了）
- [x] 确认 P0 用哪家 LLM 供应商 — OpenRouter；具体模型名称你说后面再填
- [ ] 回答：一个人做还是有协作者？每周大概能投入多少小时？—— 还没答复，会影响排期是否要压缩范围

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
