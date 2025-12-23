# KesPlus 高校选课系统审查与改进方案

## 现状概览
- 代码资产：数据库脚本 `db/01_schema_course_selection.sql`~`db/04_seed_data_course_selection.sql`、存储过程/触发器测试脚本 `tests/db_trigger_procedure_tests.sql`、Express API (`server/index.js`, `server/db.js`) 与静态前端 `web/*.html`，账号清单 `docs/login-accounts.md`。
- 运行方式：本地 Node.js + Postgres/Kingbase 连接，前端直接 `fetch` `/api/*`，无构建工具；`server/.env` 内写死数据库连接参数。
- 作业要求：需交付“基于 KesPlus 的高校选课管理系统”及 KesPlus 导出、数据库逻辑备份、项目报告（见 `作业要求.txt`、`项目报告模板.txt`），当前仓库尚未体现 KesPlus 工程与备份产物。

## 问题列表（按优先级）
### P0 必须解决
- 未落地 KesPlus：`web/*.html` 是手写静态页，缺少 KesPlus 页面、数据源和导出文件，无法满足“基于 KesPlus”与导出提交要求。
- 交付缺口：无 KStudio/Kingbase 逻辑备份 SQL，报告仅有模板；无法直接用于验收。
- 鉴权与越权风险：`server/index.js` 的 `/api/*` 不校验登录态，`/api/courses/my` 与 `/api/select`/`/api/drop` 直接接受传入的 `stu_id`/`course_id`，任意调用者可操作他人选课记录。
- 硬编码学期：前端/后端默认 `2024-2025-1`，未读取 `TB_SYS_PARAM.CURRENT_TERM`，一旦参数调整即与数据库脱节。
- 凭据暴露与弱密码：`server/.env` 已入库，含数据库账号密码；`db/03_procedures_course_selection.sql` 采用未加盐的 `md5` 校验，默认密码（`system/123456`、`admin123` 等）未要求修改。
- 角色功能缺失：教师/管理员仅能看统计（`web/teacher.html`, `web/admin.html`），无学生/教师/课程 CRUD、代选/代退、参数管理等核心能力。
- 仓库膨胀与噪音：根目录存在 3.6GB 安装镜像 `KingbaseES_V009R001C010B0004_Win64_install.iso`、`server/node_modules/`、日志文件，均不应随仓库交付。

### P1 应尽快处理
- 测试缺失：`server/package.json` 的 `npm test` 为占位，只有部分 SQL 测试；缺少 API/前端集成用例和覆盖率。
- 教师端映射不全：`web/teacher.html` 仅对 `t001/t002` 做姓名映射，其余教师账号显示“未匹配”，影响演示可信度。
- 交互与文案：存储过程返回的英文提示（如 `selection ok`）直接呈现在中文界面；错误提示和加载状态缺少统一组件。
- 健壮性：`server/index.js` 启动时 `testConnection()` 未捕获异常，数据库不可用会直接使进程崩溃；`callProcedure` 动态拼接过程名缺少白名单保护（虽当前调用固定）。

## 改进方案（分领域）
1) 交付物与仓库治理  
   - 清理大文件和生成物（ISO、`node_modules/`、日志），确保 `.gitignore` 覆盖并从版本库移除；保留轻量脚本与文档。  
   - 添加 `.env.example`，移除真实 `server/.env`，强制在 README/AGENTS 中提示自备凭据。  
   - 生成并提交 KesPlus 项目导出、KStudio/Kingbase 逻辑备份 SQL，按 `项目报告模板.txt` 补齐正式报告。

2) 数据库安全与一致性  
   - 替换 `md5` 为带盐哈希（如 `crypt()`/PBKDF2），新增密码复杂度与过期校验，保留 `PASSWORD_UPDATED_AT` 供审计。  
   - 强化角色约束：用户为 TEACHER/STUDENT 时强制一对一映射，禁止同一 USER_ID 同时挂多角色；必要时增加 CHECK 约束或视图校验。  
   - 统一学期与时间窗口：所有过程默认使用 `TB_SYS_PARAM.CURRENT_TERM`，仅在显式传参时覆盖；选课/退课窗口从参数表读取。  
   - 优化过程返回值：标准化返回码/消息（中英文一致），避免前端直接暴露 SQL 错误。

3) 后端 API 加固与功能补全  
   - 引入登录鉴权（JWT/Session）与角色授权中间件，`stu_id/tea_id/user_id` 由令牌绑定，禁止客户端自由传入；为 `/api/*` 统一 401/403 处理。  
   - 补充管理员 CRUD 与教师视图 API：学生/教师/课程管理、代选/代退、系统参数维护、教师授课列表等，调用现有过程或新增视图。  
   - 学期与配置从数据库读取：封装 `/api/config/term` 读取 `CURRENT_TERM`，移除硬编码；可选增加缓存。  
   - 增加基础监控与日志：结构化请求日志，捕获启动时数据库异常并友好退出。

4) KesPlus 前端落地  
   - 按 `docs/archive/前端页面设计执行方案_KesPlus.txt`/`docs/login-role-plan.md` 重建 KesPlus 页面，封装数据源调用现有存储过程（FN_LOGIN、PROC/FN_SELECT_COURSE、PROC/FN_DROP_COURSE、PROC_STAT_COURSE_SELECT 等）。  
   - 落实角色菜单与权限控制，学生/教师/管理员各自的查询、CRUD、选退课、统计与导出能力；前端默认学期绑定 `CURRENT_TERM`。  
   - 统一提示与异常处理，覆盖所有过程返回码；补全教师姓名映射或改为后端返回。

5) 测试与验收  
   - 扩充数据库用例：密码失败/弱口令、禁用用户/教师/学生、课程停开、容量占满并发、退课超时、跨学期重复等。  
   - 建立 API 层自动化（Jest + Supertest）覆盖登录、选/退课、统计、鉴权；前端可用 Playwright 覆盖三角色主路径。  
   - 整理手工验收清单：三角色全链路、异常路径、KesPlus 导出与备份验证。

6) 交付与运维文档  
   - 更新根 README/AGENTS，说明数据库初始化、KesPlus 导入、环境变量、常见故障排查。  
   - 记录运行/测试命令、备份恢复步骤、日志位置，形成提交包目录结构（前端导出、DB 备份、报告、源码）。

## 近期里程碑建议
- D1-D2：仓库清理 + 环境变量治理 + 密码哈希改造（开发库）；补充 CURRENT_TERM 读取。  
- D3-D5：完成 KesPlus 页面与数据源、后端鉴权与新增 API；补充 SQL/API 测试。  
- D6：全角色联调与截图，生成 KesPlus 导出、DB 备份与报告，完成提交包。 
