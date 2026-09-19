# tests（pgTAP）

从 `SCHEMA_SMOKE_TEST.sql` 移植的断言：RLS、库存事件触发器、字典搜索、`suggest_expiry`、`match_recipes`、`merge_ingredients`、账号删除级联。**不要丢弃原夹具**，它们是匹配算法的可执行说明。从 T0.2/T0.3 开始填充。见 `docs/PLAN.md` §12.1、`docs/TICKETS.md` T0.2/T0.3。
