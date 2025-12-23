# KesPlus 高校选课系统审查与改进方案（按当前工程现状更新）

## 1. 现状概览（已具备的资产）

- 数据库脚本：`db/01_schema_course_selection.sql`~`db/05_randomize_student_names.sql`（表/触发器/过程/种子数据/随机化）。
- 数据库回归：`tests/db_trigger_procedure_tests.sql`（单事务内覆盖登录、触发器、过程、统计、冲突/候补等；脚本末尾 `ROLLBACK`）。
- 后端服务：`server/index.js`（Express API + 轻量 Bearer token 鉴权），`server/db.js`（连接池）。
- 前端页面：`web/index.html`（登录）、`web/student.html`（选/退课+课表+候补）、`web/teacher.html`、`web/admin.html`、`web/vue-dashboard.html`（统计大屏，支持 CSV 导出）。
- 配置与安全：
  - `server/.env` 不入库（被 `.gitignore` 忽略）；参考 `server/.env.example` 配置数据库与 `AUTH_SECRET`。
  - 受保护接口使用 `Authorization: Bearer <token>`，并对学生接口做“只能操作本人（stu_id 绑定 token）”校验。
- 交付占位：`deliverables/`、`report/`、`docs/` 已提供放置说明与报告占位稿。
- 备份：`backups/course_selection_db.sql`（数据库逻辑备份示例，可作为提交物之一；若要求必须用 KStudio 导出，请以实际导出的 SQL 替换/补充）。

## 2. 仍需补齐的交付物（P0，影响验收）

1) KesPlus 工程落地与导出  
- 目标：满足“基于 KesPlus 平台开发网站”的验收口径，可在平台内点菜单演示，并能导出项目包。  
- 动作：将现有功能在 KesPlus 中按页面/数据源/权限重建（至少 5 个页面，建议 8+），导出放入 `deliverables/kesplus_export/`。  
- 证明：菜单截图 + 关键页面截图 + 导出包目录结构截图（写入报告）。

2) 最终报告（PDF/Word）  
- 当前：已有 `report/高校选课管理系统设计报告.md`（占位稿）与 `项目报告模板.txt`（章节模板）。  
- 动作：补齐 ER 图、表结构说明、关键存储过程/触发器说明、KesPlus 截图、统计图表截图、测试记录与验收步骤，输出 PDF/Word 放入 `report/`。

## 3. 风险与建议（P1，建议在报告中说明或留作后续）

- token 机制完善：当前 token 为 HMAC 签名的无状态载荷，建议补充 `exp` 过期校验、刷新机制，或改用成熟 JWT 库；生产环境必须配置强 `AUTH_SECRET`，禁用默认值。
- 配置规范：文档与脚本中避免出现真实数据库密码；统一使用环境变量/`.env.example` 作为示例。
- 并发与一致性：选课过程需确保并发下不超卖（课程行锁/事务隔离/触发器配合）；报告中建议写明采用的锁策略与测试方法。
- 国际化与提示：前端中文界面建议将过程返回的英文消息做统一映射，保证演示一致性。

## 4. 建议的提交包结构（验收友好）

```
KesPlus-AuthFlow/
  deliverables/
    kesplus_export/              # KesPlus 导出工程（必交）
  backups/
    course_selection_db.sql      # 数据库逻辑备份（必交/或替换为 KStudio 导出）
  report/
    高校选课管理系统设计报告.pdf   # 最终报告（必交）
  db/                            # 表/触发器/过程/数据脚本
  server/                        # API 服务
  web/                           # 静态前端
  tests/                         # DB 回归测试
  docs/                          # 说明文档与账号清单
```

## 5. 快速验收建议（可写入报告“测试与验收”）

- 数据库初始化：按 `db/01 → 02 → 03 → 04` 顺序执行。
- DB 回归：执行 `tests/db_trigger_procedure_tests.sql`（确认输出步骤标签 L*/T*/P*/D*/S*/W*）。
- Web 演示：启动 `server/` 后访问 `http://localhost:3000/`，三角色完成主流程并截图。
- KesPlus 演示：在平台内完成同样的三角色主流程，并提供导出证明。

