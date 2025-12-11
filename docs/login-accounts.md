# 登录账号清单

## 来源
- 数据脚本：`db/04_seed_data_course_selection.sql`（运行后重置用户、教师、学生及课程数据）。
- 默认数据库连接：`localhost:54321` / `course_selection_db`，用户 `system`（见 `.env`）。

## 预置账号
| 角色 | 用户名 | 初始密码 | 关联 ID | 说明 |
| --- | --- | --- | --- | --- |
| 管理员 | admin | admin123 | user_id=1 | 对应 TB_USER.ROLE=ADMIN |
| 教师 | t001 | teacher123 | user_id=2, tea_id=1 | TB_TEACHER.TEA_NO=T1001 |
| 教师 | t002 | teacher123 | user_id=3, tea_id=2 | TB_TEACHER.TEA_NO=T1002 |
| 学生 | s001 | student123 | user_id=4, stu_id=1 | TB_STUDENT.STU_NO=2024001 |
| 学生 | s002 | student123 | user_id=5, stu_id=2 | TB_STUDENT.STU_NO=2024002 |
| 学生 | s003 | student123 | user_id=6, stu_id=3 | TB_STUDENT.STU_NO=2024003 |

## 使用与维护
- `/api/login` 返回 `{ user_id, role, stu_id, tea_id }`，前端根据 role 跳转对应页面。
- 测试脚本 `tests/db_trigger_procedure_tests.sql` 会把 admin 密码改为 `admin999`；若需恢复初始密码，请重新执行 `db/04_seed_data_course_selection.sql`，或调用 `CALL PROC_SET_PASSWORD(<user_id>, '<new_pass>', ...);`。
- 生产环境请立刻修改默认密码，并根据需要停用不使用的账号（更新 `TB_USER.STATUS`）。
