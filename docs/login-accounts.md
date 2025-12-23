# 登录账号清单

## 来源
- 数据脚本：`db/04_seed_data_course_selection.sql`（运行后重置用户、教师、学生及课程数据）。
- 数据库连接参数：本地运行时从环境变量/`server/.env` 读取，参考 `server/.env.example`（请勿在仓库文档里写真实密码）。

## 预置账号
所有教师共用密码 `teacher123`，所有学生共用密码 `student123`（上线前请修改）。账号按专业/学院分层，方便分流测试。

| 角色 | 用户名 | 初始密码 | 关联 ID | 所属专业/学院 |
| --- | --- | --- | --- | --- |
| 管理员 | admin | admin123 | user_id=1 | 平台管理员 |
| 教师 | t001 | teacher123 | user_id=2, tea_id=1 | CS 学院 · 软件工程 |
| 教师 | t002 | teacher123 | user_id=3, tea_id=2 | CS 学院 · 信息安全 |
| 教师 | t003 | teacher123 | user_id=4, tea_id=3 | CS 学院 · 数据科学 |
| 教师 | t004 | teacher123 | user_id=5, tea_id=4 | EE 学院 · 通信工程 |
| 教师 | t005 | teacher123 | user_id=6, tea_id=5 | BUS 学院 · 金融科技 |

| 角色 | 用户名 | 初始密码 | 关联 ID | 所属专业 |
| --- | --- | --- | --- | --- |
| 学生 | s001 | student123 | user_id=7, stu_id=1 | 软件工程 |
| 学生 | s002 | student123 | user_id=8, stu_id=2 | 软件工程 |
| 学生 | s003 | student123 | user_id=9, stu_id=3 | 信息安全 |
| 学生 | s004 | student123 | user_id=10, stu_id=4 | 信息安全 |
| 学生 | s005 | student123 | user_id=11, stu_id=5 | 数据科学 |
| 学生 | s006 | student123 | user_id=12, stu_id=6 | 数据科学 |
| 学生 | s007 | student123 | user_id=13, stu_id=7 | 通信工程 |
| 学生 | s008 | student123 | user_id=14, stu_id=8 | 通信工程 |
| 学生 | s009 | student123 | user_id=15, stu_id=9 | 金融科技 |
| 学生 | s010 | student123 | user_id=16, stu_id=10 | 金融科技 |

## 专业与课程分布（示例数据）
- 软件工程：`C001 Database Systems`、`C003 Python Programming`（t001 授课）
- 信息安全：`C002 Operating Systems`、`C005 Network Security Practices`（t002 授课）
- 数据科学：`C004 Data Mining & Visualization`（t003 授课）
- 通信工程：`C006 Digital Signal Processing`、`C007 Wireless Communication Fundamentals`（t004 授课）
- 金融科技：`C008 FinTech Engineering`、`C009 Quantitative Risk Management`（t005 授课）

## 使用与维护
- `/api/login` 返回 `{ user_id, role, stu_id, tea_id }`，前端根据 role 跳转对应页面。
- 测试脚本 `tests/db_trigger_procedure_tests.sql` 会把 admin 密码改为 `admin999`；若需恢复初始密码，请重新执行 `db/04_seed_data_course_selection.sql`，或调用 `CALL PROC_SET_PASSWORD(<user_id>, '<new_pass>', ...);`。
- 生产环境请立刻修改默认密码，并根据需要停用不使用的账号（更新 `TB_USER.STATUS`）。
